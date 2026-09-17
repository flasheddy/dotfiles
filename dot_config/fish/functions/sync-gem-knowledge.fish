function sync-gem-knowledge --description "Sync .AGENTS.md and manifest.md from chezmoi source into ~/workspace/gem-knowledge"
    argparse 'n/dry-run' 'f/force' -- $argv
    or return 1

    set -l target_dir "$HOME/workspace/gem-knowledge"
    set -l chezmoi_src "$HOME/.local/share/chezmoi"

    if test (realpath .) != (realpath $target_dir)
        echo "error: must be run from $target_dir (cwd is (pwd))" >&2
        return 1
    end

    set -l srcs "$chezmoi_src/dot_AGENTS.md" "$chezmoi_src/packages/manifest.md"
    set -l dsts ".AGENTS.md" "manifest.md"
    set -l failed 0
    set -l changed 0

    for i in (seq (count $srcs))
        set -l src $srcs[$i]
        set -l dst $dsts[$i]

        if not test -f $src
            echo "error: missing source $src" >&2
            set failed 1
            continue
        end

        if test -L $dst
            echo "error: $dst is a symlink; remove it or use the symlink workflow" >&2
            set failed 1
            continue
        end

        if test -f $dst; and cmp -s -- $src $dst
            echo "ok: $dst (already current)"
            continue
        end

        if test -f $dst
            echo "--- diff: $dst ---"
            diff -u -- $dst $src
            echo "--- end diff ---"
        else
            echo "new: $dst"
        end

        if set -q _flag_dry_run
            echo "dry-run: would update $dst"
            set changed 1
            continue
        end

        if not set -q _flag_force
            read -l -P "overwrite $dst? [y/N] " ans
            if test "$ans" != y
                echo "skip: $dst (declined)"
                continue
            end
        end

        cp -- $src $dst; or begin
            echo "error: failed to copy $src -> $dst" >&2
            set failed 1
            continue
        end
        echo "updated: $dst"
        set changed 1
    end

    if test $failed -eq 1
        return 1
    end
    if test $changed -eq 0
        echo "all files current"
    end
end
