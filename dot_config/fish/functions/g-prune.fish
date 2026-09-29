function g-prune --description 'Delete non-chezmoi goose sessions (preserve chezmoi working dirs)'
    set -l deleted 0
    for line in (goose session list)
        # Only session rows: "<id> - <name> - <date> - <path>". Skips the
        # "Available sessions:" header and any blank lines.
        if not string match -q -r '^\d{8}_\d+ - ' "$line"
            continue
        end
        set -l fields (string split ' - ' "$line")
        set -l id $fields[1]
        set -l path $fields[-1]
        if not string match -q '*chezmoi*' "$path"
            echo "Removing session $id ($path)"
            goose session remove --session-id "$id"
            set deleted (math $deleted + 1)
        end
    end
    echo "g-prune: removed $deleted session(s)."
end
