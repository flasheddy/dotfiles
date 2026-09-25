function g-search --description 'Search Goose session history by keyword'
    if test (count $argv) -eq 0
        echo "usage: g-search <keyword>" >&2
        return 1
    end

    # Locate the Goose sessions database (read-only).
    set -l db (__goose_db)
    or return 1
    if not command -v sqlite3 >/dev/null 2>&1
        echo "g-search: sqlite3 not found." >&2
        return 1
    end

    # Escape single quotes for safe SQLite interpolation.
    set -l kw (string replace -a "'" "''" -- $argv[1])

    set -l results (sqlite3 -readonly $db "
        SELECT s.id, m.timestamp, s.working_dir, m.role,
               substr(replace(replace(m.content_json, char(10), ' '), char(13), ' '), 1, 140)
        FROM messages m
        JOIN sessions s ON s.id = m.session_id
        WHERE m.content_json LIKE '%' || '$kw' || '%'
        UNION ALL
        SELECT s.id, s.updated_at, s.working_dir, '(metadata)',
               substr(replace(replace(s.name || ' :: ' || ifnull(s.description, ''), char(10), ' '), char(13), ' '), 1, 140)
        FROM sessions s
        WHERE s.name LIKE '%' || '$kw' || '%'
           OR s.description LIKE '%' || '$kw' || '%'
           OR s.working_dir LIKE '%' || '$kw' || '%'
        ORDER BY 2 DESC
        LIMIT 15
    ")

    if test (count $results) -eq 0
        echo "g-search: no matches for '$argv[1]'." >&2
        return 0
    end

    for row in $results
        set -l f (string split -m 4 '|' "$row")
        printf '%s  %s  %s  %s  %s\n' \
            (set_color --bold cyan)$f[1](set_color normal) \
            (set_color blue)$f[2](set_color normal) \
            (set_color magenta)$f[3](set_color normal) \
            (set_color green)$f[4](set_color normal) \
            $f[5]
    end
    return 0
end
