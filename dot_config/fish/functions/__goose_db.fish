function __goose_db --description 'Internal helper: locate Goose sessions database'
    set -l db (fd -t f -e db sessions.db ~/.local/share/goose/ 2>/dev/null | head -n 1)
    if test -z "$db"; or test ! -s "$db"
        echo "__goose_db: Goose database not found." >&2
        return 1
    end
    echo $db
    return 0
end
