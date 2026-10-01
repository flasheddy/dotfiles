# Verification entry point for the dotfiles repository.
# Canonical commands come from AGENTS.md §2.4.2 (hook template syntax) and §4
# (standard verification checklist) — this file invents nothing.
#
# `check` is the FULL gate and is what the global pre-push hook dispatches to.
# Partial checks must use other recipe names.
#
# Concurrency: a justfile cannot set its own worker count (`set jobs` is not a
# just setting — verified on just 1.58), so `check-fast` is a thin wrapper that
# re-execs `just --jobs 3 _check-fast`. `check` stays sequential.

set shell := ["fish", "-c"]

# Invariant gate: memory-family extensions stay disabled, the offline docs root
# is populated, and slash-command recipes resolve.

# Config gate: pinned extensions, offline docs root, slash-command paths.
check-config:
	#!/usr/bin/env python3
	"""Config gate for the goose configuration (AGENTS.md invariants). Fail-closed.

	Red on: memory/chatrecall/tom/scheduler not disabled (ephemeral-session invariant);
	GOOSE_DOCS_ROOT unset, non-absolute, or not a populated local docs tree (offline
	invariant); GOOSE_RECIPE_GITHUB_REPO set (remote recipe fetch); a slash_command
	recipe_path that does not resolve.
	"""
	import os
	import sys

	import yaml

	CONFIG = os.path.join("{{justfile_directory()}}", "dot_config", "goose", "config.yaml")
	PINNED = ["memory", "chatrecall", "tom", "scheduler"]
	DOCS_MARKER = "goose-docs-map.md"


	def main():
	    with open(CONFIG) as fh:
	        cfg = yaml.safe_load(fh) or {}
	    bad = []

	    exts = cfg.get("extensions") or {}
	    bad += [f"extension {k!r} must stay disabled" for k in PINNED
	            if (exts.get(k) or {}).get("enabled") is not False]

	    root = cfg.get("GOOSE_DOCS_ROOT")
	    if not (isinstance(root, str) and root.startswith("/")):
	        bad.append("GOOSE_DOCS_ROOT must be set to an absolute local path (offline docs invariant)")
	    elif not os.path.isfile(os.path.join(root, DOCS_MARKER)):
	        bad.append(f"GOOSE_DOCS_ROOT is not a populated docs tree "
	                   f"(missing {DOCS_MARKER}): {root}")

	    if cfg.get("GOOSE_RECIPE_GITHUB_REPO"):
	        bad.append("GOOSE_RECIPE_GITHUB_REPO must stay unset (remote recipe fetch)")

	    cmds = cfg.get("slash_commands") or []
	    for cmd in cmds:
	        path = os.path.expanduser(str(cmd.get("recipe_path") or ""))
	        if not os.path.isfile(path):
	            bad.append(f"slash command {cmd.get('command')!r} recipe is missing: {path}")

	    for msg in bad:
	        print(f"config-gate: {msg}", file=sys.stderr)
	    if bad:
	        return 1
	    print(f"config-gate: memory family disabled; docs root OK ({root}); "
	          f"{len(cmds)} slash command path(s) resolve")
	    return 0


	sys.exit(main())

# Recipe gate: structural validation of goose recipes.
# Usage: just check-commands [accept|reject] [root]

# Recipe gate: structural validation of goose recipe files.
check-commands expect="accept" root="":
	#!/usr/bin/env python3
	"""Structural gate for goose recipe files (AGENTS.md §2.4/§4).

	Modes
	  accept (default)  every recipe under ROOT must validate
	  reject            the tree must FAIL, and every rule id declared in a fixture
	                    header (`# expect-fail: <id> [...]`) must actually be emitted

	Recipe parameters are repo-authored literals, not untrusted input; they are
	interpolated into this script by just.
	"""
	import glob
	import os
	import re
	import shutil
	import subprocess
	import sys

	import yaml

	REPO = "{{justfile_directory()}}"
	EXPECT = "{{expect}}"
	ROOT_ARG = "{{root}}"

	REPO_REAL = os.path.realpath(REPO)
	RECIPES_DIR = os.path.join(REPO, "dot_config", "goose", "recipes")
	TARGET = os.path.realpath(ROOT_ARG or RECIPES_DIR)

	PINNED_EXTENSIONS = {"memory", "chatrecall", "tom", "scheduler"}   # mirrors check-config
	FETCHER_CMDS = {
	    "uvx", "uv", "npx", "npm", "pnpm", "yarn", "bunx", "bun",
	    "pip", "pip3", "pipx", "docker", "podman", "gh", "git",
	    "curl", "wget", "ssh", "scp", "rsync", "conda", "mamba",
	}
	LOCAL_CMD_ALLOWLIST = set()
	ENV_KEY_ALLOWLIST = set()
	HTTP_HOST_ALLOWLIST = set()
	VALID_EXT_TYPES = {"builtin", "platform", "stdio", "streamable_http"}

	TUI_BINS = r"\b(less|more|nano|vim|nvim|helix|hx|btop|htop|lazygit|jless)\b"
	NET_TOOLS = r"\b(curl|wget|ssh|scp|rsync)\b"
	POSIX_SHELL = r"&&|\bexport\s+[A-Za-z_]+=|\$\("
	PATH_PARAM = re.compile(r"(_dir|_path|_root|_file)$")
	GUARD = "guard-dir"


	def fail(msg):
	    print(f"check-commands: {msg}", file=sys.stderr)
	    return 1


	def violations(path, data, referenced):
	    rel = os.path.relpath(path, REPO_REAL)
	    out = []

	    def add(rule, msg):
	        out.append((rule, rel, msg))

	    for key in ("title", "description"):
	        if not (isinstance(data.get(key), str) and data[key].strip()):
	            add("metadata", f"missing or non-string `{key}`")
	    if not any(isinstance(data.get(k), str) and data[k].strip()
	               for k in ("prompt", "instructions")):
	        add("metadata", "neither `prompt` nor `instructions` is a non-empty string")
	    if not isinstance(data.get("version", "1.0.0"), str):
	        add("metadata", "`version` must be a string")

	    exts = data.get("extensions") or []
	    if not isinstance(exts, list):
	        add("schema-extension-type", "`extensions` must be a list")
	        exts = []
	    for ext in exts:
	        if not isinstance(ext, dict):
	            add("schema-extension-type", "extension entry is not a mapping")
	            continue
	        etype, name = ext.get("type"), ext.get("name")
	        if etype not in VALID_EXT_TYPES:
	            add("schema-extension-type", f"invalid extension type {etype!r}")
	        if name in PINNED_EXTENSIONS:
	            add("pinned-extension", f"extension {name!r} is invariant-pinned to disabled")
	        if etype == "stdio":
	            cmd = str(ext.get("cmd") or "")
	            base = os.path.basename(cmd)
	            if base in FETCHER_CMDS:
	                add("offline-fetcher", f"stdio cmd {base!r} installs from a package registry")
	            elif not (cmd.startswith("/") or cmd in LOCAL_CMD_ALLOWLIST):
	                add("offline-fetcher", f"stdio cmd {cmd!r} is not an absolute allowlisted binary")
	            for arg in (ext.get("args") or []):
	                s = str(arg)
	                if "@latest" in s or re.search(r"@\^|@\*|://|^git\+", s):
	                    add("offline-args", f"arg {s!r} is unpinned or URL-shaped")
	        if etype == "streamable_http":
	            host = re.sub(r"^https?://([^/]+).*$", r"\1",
	                          str(ext.get("uri") or ext.get("url") or ""))
	            if host not in HTTP_HOST_ALLOWLIST:
	                add("network-http",
	                    f"streamable_http host {host!r} is not allowlisted (offline invariant)")
	        if etype in ("stdio", "streamable_http"):
	            tools = ext.get("available_tools")
	            if not (isinstance(tools, list) and tools):
	                add("least-privilege",
	                    f"{etype} extension {name!r} must declare non-empty available_tools")
	        for key in (ext.get("env_keys") or []):
	            if key not in ENV_KEY_ALLOWLIST:
	                add("env-keys", f"env_keys entry {key!r} is not allowlisted")

	    params = data.get("parameters") or []
	    if not isinstance(params, list):
	        add("metadata", "`parameters` must be a list")
	        params = []
	    guarded = GUARD in yaml.safe_dump(data.get("retry") or {})
	    for param in params:
	        if not isinstance(param, dict):
	            continue
	        key = str(param.get("key") or "")
	        if PATH_PARAM.search(key) and not guarded:
	            add("param-guard",
	                f"path-like parameter {key!r} has no `just {GUARD}` check in retry.checks")
	        if param.get("input_type") == "file" and "default" in param:
	            add("param-guard", f"file parameter {key!r} must not carry a default")

	    subs = data.get("sub_recipes") or []
	    if not isinstance(subs, list):
	        add("subrecipe-path", "`sub_recipes` must be a list")
	        subs = []
	    for sub in subs:
	        if not isinstance(sub, dict):
	            add("subrecipe-path", "subrecipe entry is not a mapping")
	            continue
	        raw = str(sub.get("path") or "")
	        if not raw:
	            add("subrecipe-path", f"subrecipe {sub.get('name')!r} has no path")
	            continue
	        if os.path.isabs(raw):
	            add("subrecipe-path", f"absolute subrecipe path {raw!r}")
	            continue
	        resolved = os.path.realpath(os.path.join(os.path.dirname(path), raw))
	        if not (resolved == TARGET or resolved.startswith(TARGET + os.sep)):
	            add("subrecipe-path",
	                f"subrecipe path {raw!r} escapes {os.path.relpath(TARGET, REPO_REAL)}")
	        elif not os.path.isfile(resolved):
	            add("subrecipe-path", f"subrecipe path {raw!r} does not exist")
	    if subs and os.path.realpath(path) in referenced:
	        add("no-nested-subrecipes", "a subrecipe file must not declare its own sub_recipes")

	    prose = [str(data.get(k) or "") for k in ("title", "description", "activities")]
	    shell = [str(data.get("prompt") or ""), str(data.get("instructions") or "")]
	    shell += [str(s.get("values") or "") for s in subs if isinstance(s, dict)]
	    shell += [str(e.get("cmd") or "") + " " + " ".join(map(str, e.get("args") or []))
	              for e in exts if isinstance(e, dict)]
	    shell += [str(c.get("command") or "")
	              for c in ((data.get("retry") or {}).get("checks") or [])
	              if isinstance(c, dict)]
	    for blob in shell + prose:
	        if re.search(POSIX_SHELL, blob):
	            add("shell-posix", "POSIX shell syntax (&&, export VAR=, $()) is forbidden")
	            break
	    for blob in shell:
	        if re.search(TUI_BINS, blob):
	            add("shell-tui", "forbidden interactive TUI binary referenced")
	        if re.search(NET_TOOLS, blob):
	            add("shell-network", "forbidden network binary referenced")
	        if "GOOSE_RECIPE_GITHUB_REPO" in blob:
	            add("shell-network", "GOOSE_RECIPE_GITHUB_REPO implies a network fetch")
	    return out


	def main():
	    if EXPECT not in ("accept", "reject"):
	        return fail(f"unknown mode {EXPECT!r} (expected accept|reject)")
	    if not (TARGET == REPO_REAL or TARGET.startswith(REPO_REAL + os.sep)):
	        return fail("root must live inside the repository")
	    if shutil.which("goose") is None:
	        return fail("goose not found (declared in toolchains/local-bin.txt); failing closed")

	    files = sorted(glob.glob(os.path.join(TARGET, "**", "*.yaml"), recursive=True))
	    if not files:
	        return fail(f"no recipe files under {os.path.relpath(TARGET, REPO_REAL)}")

	    data = {}
	    for name in files:
	        with open(name) as fh:
	            raw = fh.read()
	        try:
	            loaded = yaml.safe_load(raw) or {}
	        except yaml.YAMLError as exc:
	            print(f"check-commands: {os.path.relpath(name, REPO_REAL)}: invalid YAML: {exc}",
	                  file=sys.stderr)
	            return 1
	        data[name] = loaded

	    referenced = set()
	    for name, doc in data.items():
	        if not isinstance(doc, dict):
	            continue
	        for sub in (doc.get("sub_recipes") or []):
	            if isinstance(sub, dict) and str(sub.get("path") or ""):
	                referenced.add(os.path.realpath(
	                    os.path.join(os.path.dirname(name), str(sub["path"]))))

	    problems, declared = [], set()
	    for name in files:
	        doc = data[name]
	        if not isinstance(doc, dict):
	            problems.append(("metadata", os.path.relpath(name, REPO_REAL),
	                             "recipe file must be a mapping"))
	            doc = {}
	        problems += violations(name, doc, referenced)
	        with open(name) as fh:
	            for line in fh.read().splitlines()[:20]:
	                stripped = line.lstrip()
	                if stripped.startswith("# expect-fail:"):
	                    declared.update(stripped.split(":", 1)[1].split())
	        proc = subprocess.run(["goose", "recipe", "validate", name],
	                              capture_output=True, text=True)
	        if proc.returncode != 0:
	            problems.append(("goose-schema", os.path.relpath(name, REPO_REAL),
	                             "goose rejected the recipe"))

	    seen = {rule for rule, _, _ in problems}

	    if EXPECT == "accept":
	        if problems:
	            for rule, rel, msg in problems:
	                print(f"FAIL [{rule}] {rel}: {msg}", file=sys.stderr)
	            return fail(f"{len(problems)} violation(s)")
	        print(f"check-commands: {len(files)} recipe(s) valid")
	        return 0

	    missing = declared - seen
	    if not problems:
	        return fail("reject mode: tree produced no violations at all")
	    if missing:
	        for rule in sorted(missing):
	            print(f"MISSING [{rule}]: declared by a fixture but never emitted", file=sys.stderr)
	        return fail("reject mode: expected violations were not exercised")
	    print(f"check-commands-redteam: {len(files)} fixture(s) rejected; rules exercised: "
	          f"{', '.join(sorted(seen))}")
	    return 0


	if __name__ == "__main__":
	    sys.exit(main())

# Gate self-test: RED fixtures must be rejected, GREEN fixtures accepted.
check-commands-redteam:
	#!/usr/bin/env fish
	just --justfile "{{justfile()}}" check-commands reject tests/recipes/red
	or exit 1
	just --justfile "{{justfile()}}" check-commands accept tests/recipes/green
	or exit 1

# Static/structural lint: hook templates, git hooks, tool cards, whitespace.
lint:
	#!/usr/bin/env fish
	set -l failed 0
	for f in run_onchange_*.sh.tmpl
		if not chezmoi execute-template < $f | bash -n
			echo "FAIL: $f (template syntax)" >&2
			set failed 1
		end
	end
	for h in dot_config/git/hooks/*
		if not bash -n $h
			echo "FAIL: $h (hook syntax)" >&2
			set failed 1
		end
	end
	toolcard --validate; or set failed 1
	git diff --check; or set failed 1
	if test $failed -ne 0
		echo "VERIFY FAILED: lint" >&2
		exit 1
	end
	echo "lint: hook templates, git hooks, tool cards, whitespace"

# Advisory drift report. Never fails on drift content: `chezmoi diff`'s exit code
# is not a reliable drift predicate (verified 0 on a clean tree; dirty case
# unverified). Fails closed only when chezmoi itself is unavailable.

# Drift report (advisory; never fails on drift content).
drift:
	#!/usr/bin/env fish
	if not command -v chezmoi >/dev/null
		echo "drift: chezmoi not found" >&2
		exit 1
	end
	echo "--- chezmoi status ---"
	chezmoi status
	echo "--- chezmoi diff (first 200 lines) ---"
	env PAGER=cat chezmoi diff | head -n 200
	echo "(drift is advisory: it never fails this recipe)"
	exit 0

# Secret scan: mirrors the pre-commit gate's tooling (gitleaks, with a fail-closed
# rg fallback) over the working tree. Never a silent downgrade. Baseline verified
# clean read-only before this stage was added.

# Secret scan (gitleaks, fail-closed rg fallback).
secrets:
	#!/usr/bin/env fish
	if command -v gitleaks >/dev/null
		if not gitleaks dir . --no-banner --redact --log-level warn
			echo "secrets: gitleaks detected secret material in the working tree." >&2
			exit 1
		end
	else
		if git ls-files -z | xargs -0 -r rg -l -- '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
			echo "secrets: private-key material found in tracked files." >&2
			exit 1
		end
		if git ls-files -z | xargs -0 -r rg -l -i -E '(password|passwd|secret|api[-_]?key|access[-_]?key|client[-_]?secret|auth[-_]?token)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'
			echo "secrets: credential-shaped string found in tracked files." >&2
			exit 1
		end
		if git ls-files | rg -i '(^|/)(id_(rsa|ed25519|ecdsa|dsa)|[^/]*\.(pem|key|ppk|p12|pfx))$'
			echo "secrets: private-key filename tracked." >&2
			exit 1
		end
	end
	echo "secrets: no secret material detected"

# Internal parallel aggregator. Invoke `check-fast`, not this.
[parallel]
_check-fast: check-config check-commands check-commands-redteam lint secrets drift

# Parallel fast gate, pinned to 3 workers for reproducible interleaving.
check-fast:
	#!/usr/bin/env fish
	exec just --justfile "{{justfile()}}" --jobs 3 _check-fast

# Full gate: the contract entry point dispatched by the global pre-push hook.
# Body-less by design; the work lives in its prerequisites.

# Full gate (contract entry point for the global pre-push hook).
check: check-config check-commands check-commands-redteam lint secrets
