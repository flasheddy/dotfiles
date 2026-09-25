function handoff-copy --description "Copy a Goose session handoff summary to the Wayland clipboard"
    # Locate the Goose sessions database (read-only).
    set -l db (__goose_db)
    or return 1

    # Require tooling.
    if not command -v sqlite3 >/dev/null 2>&1
        echo "handoff-copy: sqlite3 not found." >&2
        return 1
    end
    if not command -v wl-copy >/dev/null 2>&1
        echo "handoff-copy: wl-copy not found." >&2
        return 1
    end

    # Latest session and its working directory.
    set -l session_id (sqlite3 -readonly $db "SELECT id FROM sessions ORDER BY updated_at DESC LIMIT 1;")
    if test -z "$session_id"
        echo "handoff-copy: no sessions found in database." >&2
        return 1
    end
    set -l work_dir (sqlite3 -readonly $db "SELECT working_dir FROM sessions WHERE id = '$session_id';")
    if test -z "$work_dir"
        set work_dir $PWD
    end

    # Git context: single-line values are safe in variables; the multiline
    # status output is streamed directly into the clipboard pipeline below.
    set -l branch '(not a git repository)'
    set -l commit '(not a git repository)'
    set -l in_git no
    if git -C $work_dir rev-parse --is-inside-work-tree >/dev/null 2>&1
        set in_git yes
        set branch (git -C $work_dir branch --show-current 2>/dev/null)
        set commit (git -C $work_dir rev-parse --short HEAD 2>/dev/null)
        if test -z "$branch"
            set branch '(detached HEAD)'
        end
        if test -z "$commit"
            set commit '(unknown)'
        end
    end

    # Latest plan path: docs/plans first (newest by mtime), then repo-wide fallback.
    set -l plan_path '(none)'
    if test -d "$work_dir/docs/plans"
        set -l plans (fd -t f -e md "$work_dir/docs/plans" 2>/dev/null)
        if test (count $plans) -gt 0
            set plan_path (ls -t $plans 2>/dev/null | head -n 1)
        end
    end
    if test "$plan_path" = '(none)'
        set -l plans (fd -t f -e md -i 'plan' $work_dir 2>/dev/null)
        if test (count $plans) -gt 0
            set plan_path (ls -t $plans 2>/dev/null | head -n 1)
        end
    end

    # Assemble markdown handoff buffer and copy to clipboard.
    begin
        echo '## Goose Session Handoff'
        echo ''
        echo "**Session:** `$session_id`"
        echo "**Working directory:** `$work_dir`"
        echo ''
        echo '### Git Context'
        echo "**Branch:** `$branch`"
        echo "**Commit:** `$commit`"
        echo '**Status:**'
        echo '```'
        if test "$in_git" = yes
            set -l status_lines (env GIT_OPTIONAL_LOCKS=0 git -C $work_dir status --short 2>/dev/null)
            if test (count $status_lines) -eq 0
                echo '(clean)'
            else
                env GIT_OPTIONAL_LOCKS=0 git -C $work_dir status --short
            end
        else
            echo '(not a git repository)'
        end
        echo '```'
        echo ''
        echo "**Latest plan path:** `$plan_path`"
        echo ''
        echo '### Assistant Context'
        echo '```'
        sqlite3 -readonly $db "SELECT json_extract(value, '\$.text') FROM messages, json_each(messages.content_json) WHERE session_id = '$session_id' AND role = 'assistant' AND json_extract(value, '\$.type') = 'text' AND length(json_extract(value, '\$.text')) > 0 ORDER BY messages.id DESC LIMIT 1;"
        echo '```'
    end | wl-copy

    echo "handoff-copy: handoff summary copied to clipboard." >&2
end
