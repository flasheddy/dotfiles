set shell := ["fish", "-c"]
export RUST_LOG := "warn"
export JUST_ROOT := justfile_directory()

alias c := check
alias cf := check-fast
alias cs := check-source
alias f := fmt

# Default recipe: runs the in-repo pre-apply verification gate.
[group("gate")]
default: check-source

# Full gate (contract entry point for the global pre-push hook).
[group("gate")]
check: preflight
    #!/usr/bin/env fish
    cd $JUST_ROOT
    exec just --justfile "{{ justfile() }}" --jobs 1 _gate

# Fast gate: same stages as `check`, pinned to 3 workers.
[group("gate")]
check-fast: preflight
    #!/usr/bin/env fish
    cd $JUST_ROOT
    exec just --justfile "{{ justfile() }}" --jobs 3 _gate

# Source gate: verify hooks, templates, lint, docs, and secrets without requiring live deployment.
[group("gate")]
check-source: preflight
    #!/usr/bin/env fish
    cd $JUST_ROOT
    exec just --justfile "{{ justfile() }}" --jobs 4 lint templates docs secrets

# Fail-closed preflight: every tool and contract file the gate needs must exist.
[group("toolchain")]
preflight:
    #!/usr/bin/env fish
    cd $JUST_ROOT
    set -l missing
    for tool in just fish fish_indent bun chezmoi taplo shfmt shellcheck typos gitleaks bash git rg mktemp
        command -v $tool >/dev/null; or set -a missing $tool
    end
    for f in AGENTS.md dot_AGENTS.md justfile
        test -f $f; or set -a missing $f
    end
    if test (count $missing) -gt 0
        echo "preflight: missing required tools/files: $missing" >&2
        exit 1
    end
    echo "preflight: required tools and files present"

# Auto-format tracked files (fish, git hooks, TOML, agent docs, justfile).
[group("toolchain")]
fmt: preflight
    #!/usr/bin/env fish
    cd $JUST_ROOT
    set -l fish_files (git ls-files "*.fish")
    test -n "$fish_files"; and fish_indent -w $fish_files
    for h in dot_config/git/hooks/*
        test -f $h; and shfmt -w -i 2 -ci $h
    end
    set -l tomls
    for t in (git ls-files "*.toml")
        test -f $t; and set -a tomls $t
    end
    test -n "$tomls"; and taplo format --config dot_taplo.toml $tomls
    bun fmt AGENTS.md dot_AGENTS.md
    just --fmt
    echo "fmt: formatted fish, git hooks, toml, agent docs, and justfile"

# Static/structural lint: hooks, fish, TOML, typos, formatting, whitespace.
[group("verify")]
lint:
    #!/usr/bin/env fish
    cd $JUST_ROOT
    set -l failed 0
    for h in dot_config/git/hooks/*
        test -f $h; or continue
        if not bash -n $h
            echo "FAIL: $h (hook syntax)" >&2
            set failed 1
        end
        if not shellcheck $h
            echo "FAIL: $h (shellcheck)" >&2
            set failed 1
        end
        if not shfmt -d -i 2 -ci $h
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
    set -l fish_files (git ls-files "*.fish")
    test -n "$fish_files"; and begin
        fish_indent --check $fish_files; or begin
            echo "FAIL: tracked fish files are not fish_indent-clean; run 'just fmt'" >&2
            set failed 1
        end
    end
    set -l tomls
    for t in (git ls-files "*.toml")
        test -f $t; and set -a tomls $t
    end
    test -n "$tomls"; and begin
        taplo format --config dot_taplo.toml --check $tomls; or set failed 1
    end
    set -l typos_args
    test -f dot_typos.toml; and set typos_args --config dot_typos.toml
    typos $typos_args; or set failed 1
    if not bun fmt --check AGENTS.md dot_AGENTS.md >/dev/null
        echo "FAIL: agent docs are not bun fmt-clean; run 'just fmt'" >&2
        set failed 1
    end
    git grep -q -I -E '[[:blank:]]+$'
    set -l ws_status $status
    if test $ws_status -eq 0
        git grep -n -I -E '[[:blank:]]+$' >&2
        echo "FAIL: tracked files contain trailing whitespace" >&2
        set failed 1
    else if test $ws_status -gt 1
        echo "FAIL: trailing-whitespace scan failed" >&2
        set failed 1
    end
    git grep -q -I -E '^(<{7}|={7}|>{7})( |$)'
    set -l conflict_status $status
    if test $conflict_status -eq 0
        git grep -n -I -E '^(<{7}|={7}|>{7})( |$)' >&2
        echo "FAIL: conflict markers in tracked files" >&2
        set failed 1
    else if test $conflict_status -gt 1
        echo "FAIL: conflict-marker scan failed" >&2
        set failed 1
    end
    if not just --fmt --check >/dev/null 2>&1
        echo "FAIL: justfile is not formatted; run 'just --fmt' or 'just fmt'" >&2
        set failed 1
    end
    if test $failed -ne 0
        echo "VERIFY FAILED: lint" >&2
        exit 1
    end
    echo "lint: hooks, fish, toml, typos, formatting, whitespace"

# Render hook templates and lint the generated shell (syntax, shfmt, shellcheck).
[group("verify")]
templates:
    #!/usr/bin/env fish
    cd $JUST_ROOT
    set -l failed 0
    set -l render_dir (mktemp -d)
    if test -z "$render_dir"
        echo "FAIL: cannot create temp dir for template rendering" >&2
        exit 1
    end
    for f in run_onchange_*.sh.tmpl
        set -l rendered $render_dir/(string replace -r '\.tmpl$' '' -- (path basename $f))
        if not chezmoi execute-template < $f > $rendered
            echo "FAIL: $f (template render)" >&2
            set failed 1
            continue
        end
        if not bash -n $rendered
            echo "FAIL: $f (rendered syntax)" >&2
            set failed 1
        end
        if not shfmt -d -i 2 -ci $rendered >&2
            echo "FAIL: $f (rendered shfmt; reformat the template source)" >&2
            set failed 1
        end
        if not shellcheck $rendered
            echo "FAIL: $f (rendered shellcheck)" >&2
            set failed 1
        end
    end
    rm -rf $render_dir
    if test $failed -ne 0
        echo "VERIFY FAILED: templates" >&2
        exit 1
    end
    echo "templates: rendered shell syntax, shfmt, shellcheck"

# Documentation contract: cited .md paths exist and cited headings resolve.
[group("verify")]
docs:
    #!/usr/bin/env fish
    cd $JUST_ROOT
    if not test -f AGENTS.md
        echo "docs: AGENTS.md not found" >&2
        exit 1
    end
    set -l failed 0
    set -l prev ""
    set -l chain 0
    for token in (rg -o --no-filename '`[^`]+`' AGENTS.md | string replace -a '`' '')
        if string match -qr '^#{2,6}[[:space:]]' -- "$token"
            if test -n "$prev"; and test $chain -lt 2
                if not rg -q -x -F -- "$token" "$prev"
                    echo "docs-drift: AGENTS.md: heading \"$token\" not found in $prev" >&2
                    set failed 1
                end
                set chain (math $chain + 1)
            end
            continue
        end
        switch $token
            case '*\**' '*<*' '*>*'
                set prev ""
                set chain 0
            case '*.md'
                set -l resolved (string replace -r '^~' $HOME -- $token)
                if test -e "$resolved"
                    set prev "$resolved"
                    set chain 0
                else
                    echo "docs-drift: AGENTS.md: cited path does not exist: $token" >&2
                    set failed 1
                    set prev ""
                    set chain 0
                end
            case '*'
                set prev ""
                set chain 0
        end
    end
    if test $failed -ne 0
        echo "VERIFY FAILED: docs" >&2
        exit 1
    end
    echo "docs: AGENTS.md citations resolve"

# Secret scan: gitleaks over the working tree (fail-closed).
[group("verify")]
secrets:
    #!/usr/bin/env fish
    cd $JUST_ROOT
    gitleaks dir . --no-banner --redact --log-level warn; or begin
        echo "secrets: gitleaks detected secret material in the working tree." >&2
        exit 1
    end
    echo "secrets: no secret material detected"

# Drift gate: verify deployed state matches chezmoi source state.
[group("verify")]
drift:
    #!/usr/bin/env fish
    cd $JUST_ROOT
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

# Staged commit gate: whitespace, conflict markers, secrets, and docs drift.
[group("deploy")]
precommit: preflight docs
    #!/usr/bin/env fish
    cd $JUST_ROOT
    if git diff --cached --quiet
        echo "precommit: nothing staged"
        exit 0
    end
    if not git diff --cached --check
        echo "precommit: staged whitespace or conflict markers" >&2
        exit 1
    end
    gitleaks git --staged --no-banner --redact --log-level warn; or begin
        echo "precommit: gitleaks detected staged secret material" >&2
        exit 1
    end
    echo "precommit: staged checks clean"

# Prove the gate rejects broken fixtures in an isolated temporary repository.
[group("deploy")]
selftest: preflight
    #!/usr/bin/env fish
    cd $JUST_ROOT
    exec fish selftest.fish

# Internal gate aggregator. Invoke `check` or `check-fast`, not this.
[parallel]
_gate: lint templates docs secrets drift
