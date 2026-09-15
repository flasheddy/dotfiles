function audit-copy --description "Extract latest Goose session transcript to Wayland clipboard"
    set -l db (fd -t f -e db sessions.db ~/.local/share/goose/ 2>/dev/null | head -n 1)
    if test -z "$db"
        echo "Goose database not found." >&2
        return 1
    end

    sqlite3 -readonly $db "
        SELECT id || ' | ' || role || ': ' || content_json
        FROM messages
        WHERE session_id = (SELECT id FROM sessions ORDER BY updated_at DESC LIMIT 1)
        ORDER BY id ASC;
    " | wl-copy

    echo "Latest session transcript copied to clipboard."
end
