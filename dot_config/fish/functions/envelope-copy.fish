function envelope-copy --description 'Extract latest 4-backtick execution envelope from Goose session to Wayland clipboard'
    # Locate the Goose sessions database (read-only).
    set -l db (fd -t f -e db sessions.db ~/.local/share/goose/ 2>/dev/null | head -n 1)
    if test -z "$db"
        echo "envelope-copy: Goose database not found." >&2
        return 1
    end

    # Require tooling.
    if not command -v sqlite3 >/dev/null 2>&1
        echo "envelope-copy: sqlite3 not found." >&2
        return 1
    end
    if not command -v wl-copy >/dev/null 2>&1
        echo "envelope-copy: wl-copy not found." >&2
        return 1
    end

    # Latest architect session, preferring the current working directory.
    set -l pwd_esc (string replace -a "'" "''" "$PWD")
    set -l session_id ""
    set session_id (sqlite3 -readonly $db "SELECT id FROM sessions WHERE name LIKE 'architect-%' AND working_dir = '$pwd_esc' ORDER BY updated_at DESC LIMIT 1;")
    if test -z "$session_id"
        set session_id (sqlite3 -readonly $db "SELECT id FROM sessions WHERE name LIKE 'architect-%' ORDER BY updated_at DESC LIMIT 1;")
    end
    if test -z "$session_id"
        echo "envelope-copy: no g-architect session found." >&2
        return 1
    end

    # Latest assistant text block (mirrors handoff-copy.fish), kept as one string.
    set -l text (sqlite3 -readonly $db "SELECT json_extract(value, '\$.text') FROM messages, json_each(messages.content_json) WHERE session_id = '$session_id' AND role = 'assistant' AND json_extract(value, '\$.type') = 'text' AND length(json_extract(value, '\$.text')) > 0 ORDER BY messages.id DESC LIMIT 1;" | string collect -a)
    if test -z "$text"
        echo "envelope-copy: no assistant text found in latest session." >&2
        return 1
    end

    # Extract the first 4-backtick fenced block, if present.
    set -l envelope (string match -rg '(?s)````[^\n]*\n(.+?)\n````' "$text")
    if test (count $envelope) -gt 0
        printf '%s\n' $envelope | wl-copy
        echo "envelope-copy: 4-backtick envelope copied to clipboard."
    else
        printf '%s\n' "$text" | wl-copy
        echo "envelope-copy: No 4-backtick envelope found; copied full assistant response." >&2
    end
end
