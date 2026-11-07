set shell := ["fish", "-c"]
export RUST_LOG := "warn"

# AGENTS.md hygiene gate (AGENTS.md §1.4). Fail-closed.
# Usage: just check-agents [file]
#
# Seven rules, each rejecting a concrete regression:
#   table     no Markdown table outside fenced code blocks — tables are not
#             formatter-stable, and ~/.config/helix/languages.toml auto-formats
#             markdown with bun fmt on save, so a padded table rewrites the
#             file and produces a whole-block diff
#   formatter the file must be bun fmt-idempotent, so an editor save is a no-op
#   budget    combined agent rules must stay under 32768 B, the Codex
#             AGENTS_MD_MAX_BYTES cap for the agent context chain
#   h1        exactly one level-1 heading
#   dupe      no duplicated bullet line (>= 40 chars) — drift signal
#   fence     balanced ``` code fences
#   floor     a floor-contract marker must match the live ~/.AGENTS.md sha256

# AGENTS.md hygiene gate (fail-closed rule validation).
check-agents file="":
    #!/usr/bin/env python3
    import hashlib
    import os
    import re
    import subprocess
    import sys

    TOTAL_MAX = 32768
    FLOOR = os.path.expanduser("~/.AGENTS.md")

    arg = "{{ file }}".strip()
    FILES = [arg] if arg else [f for f in ["dot_AGENTS.md", "AGENTS.md"] if os.path.exists(f)]

    violations = []
    total = 0


    for path in FILES:
        try:
            with open(path, "rb") as fh:
                raw = fh.read()
        except OSError as exc:
            print("check-agents: cannot read " + path + ": " + str(exc), file=sys.stderr)
            sys.exit(1)

        total += len(raw)
        text = raw.decode("utf-8", "replace")
        lines = text.splitlines()

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
                violations.append(("table", path, "Markdown table at line " + str(n) + " (use a list; tables are not bun fmt)"))
        if fences % 2:
            violations.append(("fence", path, "unbalanced code fences (" + str(fences) + " ``` markers)"))

        if len(h1) != 1:
            violations.append(("h1", path, "expected exactly one level-1 heading, found " + str(len(h1))))

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
                violations.append(("dupe", path, "duplicated bullet " + str(seen[body]) + "x: " + body[:60]))

        marker = re.search(r"floor-contract: sha256:([0-9a-f]{64})", text)
        if marker and os.path.exists(FLOOR):
            with open(FLOOR, "rb") as fh:
                actual = hashlib.sha256(fh.read()).hexdigest()
            if marker.group(1) != actual:
                violations.append(("floor", path, "floor-contract marker is stale; run floor-stamp"))

        try:
            proc = subprocess.run(["bun", "fmt", "--stdin-filepath", path], input=raw, capture_output=True)
        except FileNotFoundError:
            violations.append(("tool", path, "bun not found; refusing to pass without the formatter check"))
        else:
            if proc.returncode != 0:
                violations.append(("formatter", path, "bun fmt failed: " + proc.stderr.decode("utf-8", "replace").strip()[:160]))
            elif proc.stdout != raw:
                delta = len(proc.stdout) - len(raw)
                if delta == 0:
                    where = "same size, different bytes"
                else:
                    where = ("+" if delta > 0 else "") + str(delta) + " B"
                violations.append(("formatter", path, "not bun fmt-idempotent (" + where + "); run bun fmt"))

    if total > TOTAL_MAX:
        violations.append(("budget", "rules", str(total) + " B exceeds " + str(TOTAL_MAX) + " B cap"))

    if violations:
        for rule, path, msg in violations:
            print("check-agents: " + rule + ": " + path + ": " + msg, file=sys.stderr)
        print("check-agents: " + str(len(violations)) + " violation(s)", file=sys.stderr)
        sys.exit(1)

    print("check-agents: rules ok (" + str(total) + " B / " + str(TOTAL_MAX) + " B)")

# Auto-format supported files (Fish functions, git hooks, TOML, Markdown, justfile).
fmt:
    #!/usr/bin/env fish
    if command -v fish_indent >/dev/null
        for f in (git ls-files "dot_config/fish/functions/*.fish")
            test -f $f; and fish_indent -w $f
        end
    end
    if command -v shfmt >/dev/null
        for h in dot_config/git/hooks/*
            test -f $h; and shfmt -w -i 2 -ci $h
        end
    end
    if command -v taplo >/dev/null
        set -l tomls
        for t in (git ls-files "*.toml")
            test -f $t; and set -a tomls $t
        end
        test -n "$tomls"; and taplo format --config dot_taplo.toml $tomls
    end
    if command -v bun >/dev/null
        set -l mds
        for m in AGENTS.md dot_AGENTS.md README.md agentic_workflow.md
            test -f $m; and set -a mds $m
        end
        test -n "$mds"; and bun fmt $mds
    end
    just --fmt
    echo "fmt: formatted fish functions, git hooks, toml, markdown, and justfile"

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
        test -f $h; or continue
        if not bash -n $h
            echo "FAIL: $h (hook syntax)" >&2
            set failed 1
        end
        if command -v shellcheck >/dev/null; and not shellcheck $h
            echo "FAIL: $h (shellcheck)" >&2
            set failed 1
        end
        if command -v shfmt >/dev/null; and not shfmt -d -i 2 -ci $h
            echo "FAIL: $h (shfmt; run 'just fmt')" >&2
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
        test -n "$tomls"; and begin taplo format --config dot_taplo.toml --check $tomls; or set failed 1; end
    end
    if command -v typos >/dev/null
        set -l typos_args
        test -f dot_typos.toml; and set typos_args --config dot_typos.toml
        typos $typos_args; or set failed 1
    end
    if not just --fmt --check >/dev/null 2>&1
        echo "FAIL: justfile is not formatted; run 'just --fmt' or 'just fmt'" >&2
        set failed 1
    end
    git diff --check; or set failed 1
    if test $failed -ne 0
        echo "VERIFY FAILED: lint" >&2
        exit 1
    end
    echo "lint: templates, git hooks, fish, toml, typos, whitespace"

# Drift gate: verify deployed state matches chezmoi source state.
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

# Secret scan (gitleaks, fail-closed rg fallback).
secrets:
    #!/usr/bin/env fish
    if command -v gitleaks >/dev/null
        gitleaks dir . --no-banner --redact --log-level warn; or begin
            echo "secrets: gitleaks detected secret material in the working tree." >&2
            exit 1
        end
        echo "secrets: no secret material detected"
        exit 0
    end

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
    echo "secrets: no secret material detected"

# Internal parallel aggregator. Invoke `check-fast`, not this.
[parallel]
_check-fast: check-agents lint secrets drift

# Parallel fast gate, pinned to 3 workers for reproducible interleaving.
check-fast:
    #!/usr/bin/env fish
    exec just --justfile "{{ justfile() }}" --jobs 3 _check-fast

# Full gate (contract entry point for the global pre-push hook).
check: check-agents lint secrets drift
