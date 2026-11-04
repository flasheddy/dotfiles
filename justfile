# Verification entry point for the dotfiles repository.
# Canonical commands come from AGENTS.md §2.4 (hook template syntax) and §4
# (standard verification checklist) — this file invents nothing.
#
# `check` is the FULL gate and is what the global pre-push hook dispatches to.
# Partial checks must use other recipe names.
#
# Concurrency: a justfile cannot set its own worker count (`set jobs` is not a
# just setting — verified on just 1.58), so `check-fast` is a thin wrapper that
# re-execs `just --jobs 3 _check-fast`. `check` stays sequential.

set shell := ["fish", "-c"]


# AGENTS.md hygiene gate (AGENTS.md §1.4). Fail-closed.
# Usage: just check-agents [file]
#
# Seven rules, each rejecting a concrete regression:
#   table     no Markdown table outside fenced code blocks — tables are not
#             Prettier-stable, and ~/.config/helix/languages.toml auto-formats
#             markdown with prettier on save, so a padded table rewrites the
#             file and produces a whole-block diff
#   prettier  the file must be Prettier-idempotent, so an editor save is a no-op
#   budget    floor (~/.AGENTS.md) + this file must stay under 32768 B, the
#             Codex AGENTS_MD_MAX_BYTES cap for the combined AGENTS.md chain
#             (agents load AGENTS.md at every hierarchy level)
#   h1        exactly one level-1 heading
#   dupe      no duplicated bullet line (>= 40 chars) — drift signal
#   fence     balanced ``` code fences
#   floor     a floor-contract marker must match the live ~/.AGENTS.md sha256
check-agents file="AGENTS.md":
	#!/usr/bin/env python3
	import hashlib
	import os
	import re
	import subprocess
	import sys

	PATH = "{{file}}"
	TOTAL_MAX = 32768
	TOTAL_WARN = TOTAL_MAX * 9 // 10
	FLOOR = os.path.expanduser("~/.AGENTS.md")

	violations = []


	def add(rule, msg):
	    violations.append((rule, msg))


	def sha256(path):
	    with open(path, "rb") as fh:
	        return hashlib.sha256(fh.read()).hexdigest()


	try:
	    with open(PATH, "rb") as fh:
	        raw = fh.read()
	except OSError as exc:
	    print("check-agents: file: cannot read " + PATH + ": " + str(exc), file=sys.stderr)
	    sys.exit(1)

	text = raw.decode("utf-8", "replace")
	lines = text.splitlines()

	# Table detection must ignore fenced code blocks, and fence balance decides
	# whether the scan is trustworthy at all.
	in_fence = False
	fences = 0
	h1 = []
	table_sep = re.compile(r"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$")
	for n, line in enumerate(lines, 1):
	    if line.lstrip().startswith("```"):
	        fences += 1
	        in_fence = not in_fence
	        continue
	    if not in_fence and re.match(r"^#\s", line):
	        h1.append(line)
	    if not in_fence and table_sep.match(line):
	        add("table", "Markdown table at line " + str(n) + " (use a list; tables are not Prettier-stable)")
	if fences % 2:
	    add("fence", "unbalanced code fences (" + str(fences) + " ``` markers)")

	# Level-1 headings are only meaningful outside fenced code: a `#` line in a
	# shell block is a comment, not a heading. Counting it made every file with
	# a commented command fail, so the scan shares the fence state above.
	if len(h1) != 1:
	    add("h1", "expected exactly one level-1 heading, found " + str(len(h1)))

	seen = {}
	for line in lines:
	    m = re.match(r"^\s*(?:[-*]|\d+\.)\s+(\S.*)$", line)
	    if not m:
	        continue
	    body = m.group(1).strip()
	    if len(body) >= 40:
	        seen[body] = seen.get(body, 0) + 1
	for body in seen:
	    if seen[body] > 1:
	        add("dupe", "duplicated bullet " + str(seen[body]) + "x: " + body[:60])

	total = len(raw)
	if os.path.exists(FLOOR):
	    total += os.path.getsize(FLOOR)
	if total > TOTAL_MAX:
	    add("budget", str(total) + " B combined with the floor exceeds " + str(TOTAL_MAX) + " B; move enumerable detail to packages/manifest.md and keep only traps here")
	elif total > TOTAL_WARN:
	    print("check-agents: budget: warning: " + str(total) + " B combined with the floor (cap " + str(TOTAL_MAX) + ")", file=sys.stderr)

	marker = re.search(r"floor-contract: sha256:([0-9a-f]{64})", text)
	if marker and os.path.exists(FLOOR):
	    if marker.group(1) != sha256(FLOOR):
	        add("floor", "floor-contract marker is stale; run floor-stamp")

	try:
	    proc = subprocess.run(["prettier", "--parser", "markdown", PATH], capture_output=True)
	except FileNotFoundError:
	    add("tool", "prettier not found; refusing to pass without the formatter check")
	else:
	    if proc.returncode != 0:
	        add("prettier", "prettier failed: " + proc.stderr.decode("utf-8", "replace").strip()[:160])
	    elif proc.stdout != raw:
	        delta = len(proc.stdout) - len(raw)
	        if delta == 0:
	            where = "same size, different bytes"
	        else:
	            where = ("+" if delta > 0 else "") + str(delta) + " B"
	        add("prettier", "not Prettier-idempotent (" + where + "); run prettier --write")

	if violations:
	    for rule, msg in violations:
	        print("check-agents: " + rule + ": " + PATH + ": " + msg, file=sys.stderr)
	    print("check-agents: " + str(len(violations)) + " violation(s) in " + PATH, file=sys.stderr)
	    sys.exit(1)

	print("check-agents: " + PATH + " ok (" + str(len(raw)) + " B, +" + str(total - len(raw)) + " B floor = " + str(total) + " B)")

# Gate self-test: every rule must reject its fixture, and the real file must pass.
# A gate only ever observed passing is untested.
# Auto-format supported files (Fish functions, TOML configs, Markdown).
fmt:
	#!/usr/bin/env fish
	if command -v fish_indent >/dev/null
		for f in (git ls-files "dot_config/fish/functions/*.fish")
			test -f $f; and fish_indent -w $f
		end
	end
	if command -v taplo >/dev/null
		set -l tomls
		for t in (git ls-files "*.toml")
			test -f $t; and set -a tomls $t
		end
		test -n "$tomls"; and taplo format $tomls
	end
	if command -v prettier >/dev/null
		prettier --write AGENTS.md dot_AGENTS.md README.md
	end
	echo "fmt: formatted fish functions, toml, and markdown files"

# Static/structural lint: hook templates, git hooks, fish syntax, TOML, typos, whitespace.
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
	for f in (git ls-files "*.fish")
		test -f $f; or continue
		if not fish -n $f
			echo "FAIL: $f (fish syntax)" >&2
			set failed 1
		end
	end
	if command -v taplo >/dev/null
		set -l tomls
		for t in (git ls-files "*.toml")
			test -f $t; and set -a tomls $t
		end
		if test -n "$tomls"
			taplo format --check $tomls; or set failed 1
		end
	end
	if command -v typos >/dev/null
		typos; or set failed 1
	end
	git diff --check; or set failed 1
	if test $failed -ne 0
		echo "VERIFY FAILED: lint" >&2
		exit 1
	end
	echo "lint: templates, git hooks, fish, toml, typos, whitespace"

# Why `status` and not `diff`: `chezmoi diff` exits 0 even with real drift
# present (verified 2026-10-11: 41-line diff, exit 0); non-zero means error.
# Drift gate (HARD): any externally-modified or unapplied managed file fails the
# build; pending `run_` scripts are warned about, not failed on.
# No exclusions: the status report is evaluated verbatim. The former permission.yaml
# filter is gone — that target is deliberately unmanaged (see .chezmoiignore), so
# re-adding a filter here would silently mute a real gate.
drift:
	#!/usr/bin/env fish
	if not command -v chezmoi >/dev/null
		echo "drift: chezmoi not found" >&2
		exit 1
	end
	set -l status_out (env PAGER=cat chezmoi status 2>&1)
	set -l st $status
	if test $st -ne 0
		echo "drift: 'chezmoi status' failed" >&2
		echo "$status_out" >&2
		exit 1
	end
	set -l failed 0
	for line in $status_out
		test -z "$line"; and continue
		set -l c1 (string sub -s 1 -l 1 -- "$line")
		set -l c2 (string sub -s 2 -l 1 -- "$line")
		if string match -qr '[MDA]' -- "$c1"; or string match -qr '[MDA]' -- "$c2"
			echo "drift: $line" >&2
			set failed 1
		else if test "$c2" = R
			echo "drift (warn): pending script run - $line" >&2
		end
	end
	if test $failed -eq 1
		echo "drift: deployed state diverges from the chezmoi source; reconcile before pushing." >&2
		exit 1
	end
	echo "drift: clean (no unapplied or externally-modified managed files)"
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
_check-fast: check-agents lint secrets drift

# Parallel fast gate, pinned to 3 workers for reproducible interleaving.
check-fast:
	#!/usr/bin/env fish
	exec just --justfile "{{justfile()}}" --jobs 3 _check-fast

# Full gate: the contract entry point dispatched by the global pre-push hook.
# Body-less by design; the work lives in its prerequisites.

# Full gate (contract entry point for the global pre-push hook).
check: check-agents lint secrets drift
