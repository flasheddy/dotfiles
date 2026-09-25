function goose_clean --description 'Pre-flight workspace hygiene check before starting Goose session'
    # 1. Git repository cleanliness check
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l dirty (git status --porcelain 2>/dev/null)
        if test -n "$dirty"
            echo (set_color yellow)"goose_clean: workspace has uncommitted changes — commit or stash before launching Goose."(set_color normal) >&2
            git status --porcelain >&2
            return 1
        end
    end

    # 2. Prune stale goose debug logs and sockets (quiet)
    set -l stale_files /tmp/goose-debug-*.log /tmp/goose-*.sock
    if test (count $stale_files) -gt 0
        rm -f $stale_files 2>/dev/null
    end

    # 3. Clean status
    echo (set_color green)"goose_clean: workspace clean — ready for Goose."(set_color normal)
    return 0
end
