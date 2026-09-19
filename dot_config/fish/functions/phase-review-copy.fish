function phase-review-copy --description 'Pack current phase production changes for DeepSeek architectural audit'
    # Comparison base (default: main).
    set -l base_ref main
    if test -n "$argv[1]"
        set base_ref $argv[1]
    end

    # Must run inside a git work tree.
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "phase-review-copy: not inside a git repository." >&2
        return 1
    end

    # Merge base between the requested ref and HEAD.
    set -l merge_base (git merge-base $base_ref HEAD 2>/dev/null)
    if test -z "$merge_base"
        echo "phase-review-copy: cannot resolve merge base between '$base_ref' and HEAD." >&2
        return 1
    end

    # Production files added/modified since the merge base (tests/fixtures excluded).
    set -l files (git diff --name-only "$merge_base"..HEAD -- \
        'src/**.py' \
        'packages/**.py' \
        'backend/src/**.py' \
        'contracts/v1/tools/*.py' \
        'src/**.rs' \
        'crates/**.rs' \
        'src/**.ts' \
        'src/**.tsx' \
        ':!*test*' \
        ':!*fixture*')

    # Drop deleted files (git diff lists them, but they have no content to pack).
    set -l packed
    for f in $files
        test -f "$f"; and set -a packed $f
    end

    set -l file_count (count $packed)
    if test $file_count -eq 0
        echo "phase-review-copy: no production files changed in $base_ref..HEAD." >&2
        return 1
    end

    # Clipboard backend: wl-copy (Wayland/COSMIC) preferred, xclip fallback.
    set -l clip_cmd
    set -l clip_args
    if command -v wl-copy >/dev/null 2>&1
        set clip_cmd wl-copy
    else if command -v xclip >/dev/null 2>&1
        set clip_cmd xclip
        set clip_args -selection clipboard
    else
        echo "phase-review-copy: no clipboard tool found (need wl-copy or xclip)." >&2
        return 1
    end

    # Stream formatted content into the clipboard.
    begin
        for f in $packed
            echo "=== FILE: $f ==="
            cat "$f"
            echo ""
        end
    end | $clip_cmd $clip_args

    # Line count (sum per-file; avoids the trailing-newline merge undercount).
    set -l total_lines 0
    for f in $packed
        set total_lines (math $total_lines + (wc -l < "$f"))
    end

    echo "phase-review-copy: packed $file_count files ($total_lines lines) from $base_ref..HEAD." >&2
end
