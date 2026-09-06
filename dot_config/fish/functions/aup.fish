function aup --description 'Update system packages and developer toolchains'
    argparse 't/toolchains' 'no-sys' 's/sys-only' 'f/force' 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "aup — update system packages and developer toolchains"
        echo
        echo "usage: aup [options]"
        echo
        echo "  (no options)      update system packages AND all toolchains"
        echo "  -t, --toolchains  toolchains only, skip the system update"
        echo "      --no-sys      alias for --toolchains"
        echo "  -s, --sys-only    system packages only (cachy-update)"
        echo "  -f, --force       ignore the success cache, re-run all stages"
        echo "  -h, --help        show this help"
        echo
        echo "Each stage runs in isolation: one failure never aborts the rest."
        echo "Stages that succeeded within the last 2 hours are skipped"
        echo "automatically (cache: ~/.cache/aup; bypass with --force)."
        echo "A summary of OK / SKIP / FAIL stages is printed at the end."
        echo "Exit status is 1 if any stage failed, 0 otherwise."
        return 0
    end

    if set -q argv[1]
        echo "aup: unexpected argument: $argv" >&2
        echo "Try 'aup --help'." >&2
        return 2
    end

    set -l want_sys 1
    set -l want_tools 1
    if set -q _flag_toolchains; or set -q _flag_no_sys
        set want_sys 0
    end
    if set -q _flag_sys_only
        set want_sys 1
        set want_tools 0
    end

    # Success cache (XDG): markers enable the 2h auto-skip.
    # If the cache dir cannot be created, caching is disabled silently
    # and every stage simply runs.
    set -l cache_base $HOME/.cache
    set -q XDG_CACHE_HOME; and set cache_base $XDG_CACHE_HOME
    if mkdir -p $cache_base/aup 2>/dev/null
        set -g __aup_cache_dir $cache_base/aup
    end
    if set -q _flag_force
        set -g __aup_force 1
    end

    # Result collectors (global so the stage runner can append; erased at end)
    set -g __aup_passed
    set -g __aup_failed
    set -g __aup_skipped

    if test $want_sys -eq 1
        __aup_run system cachy-update
    else
        set -a __aup_skipped "system (disabled)"
    end

    if test $want_tools -eq 1
        __aup_run rustup rustup update
        __aup_run cargo cargo install-update -a
        __aup_run uv-self uv self update
        __aup_run uv-tools uv tool upgrade --all
        __aup_run bun-self bun upgrade
        __aup_run bun-globals __aup_bun_globals
        __aup_run go gup update
        __aup_run ghcup ghcup upgrade
        __aup_run tldr tldr --update
    else
        set -a __aup_skipped "toolchains (disabled)"
    end

    echo
    echo (set_color --bold)"== aup summary =="(set_color normal)
    for label in $__aup_passed
        printf '  %s %s\n' (set_color green)OK(set_color normal) $label
    end
    for label in $__aup_skipped
        printf '  %s %s\n' (set_color yellow)SKIP(set_color normal) $label
    end
    for label in $__aup_failed
        printf '  %s %s\n' (set_color red)FAIL(set_color normal) $label
    end

    set -l rc 0
    if set -q __aup_failed[1]
        set rc 1
        echo
        echo (set_color red)"aup: failed stages: $__aup_failed"(set_color normal) >&2
    end

    set -e __aup_passed __aup_failed __aup_skipped __aup_cache_dir __aup_force
    return $rc
end

function __aup_run --description 'internal: run one aup stage in isolation'
    set -l label $argv[1]
    set -l cmd $argv[2..]

    if not type -q $cmd[1]
        set -ga __aup_skipped "$label ($cmd[1] not installed)"
        return 0
    end

    # Auto-skip: succeeded within the last 2h (bypass with --force).
    # Uses the fish builtin `path mtime --relative` (integer seconds).
    if set -q __aup_cache_dir[1]; and not set -q __aup_force[1]
        set -l marker $__aup_cache_dir[1]/$label.ok
        if test -f $marker
            set -l age (path mtime --relative $marker 2>/dev/null)
            if test -n "$age"; and test $age -lt 7200 2>/dev/null
                set -ga __aup_skipped "$label (recently completed)"
                return 0
            end
        end
    end

    echo
    echo (set_color blue)":: $label: $cmd"(set_color normal)
    if $cmd
        set -ga __aup_passed $label
        # Mark success for the auto-skip cache (never on failure)
        if set -q __aup_cache_dir[1]
            touch $__aup_cache_dir[1]/$label.ok 2>/dev/null
            or true
        end
    else
        set -ga __aup_failed "$label (exit $status)"
    end
end

function __aup_bun_globals --description 'internal: update bun global packages'
    # `bun update --global` operates on ~/.bun/install/global directly;
    # no cd needed (flag confirmed via `bun update --help`)
    bun update --global --latest
end
