function handoff-extract --description 'Extract the fish code block from the latest Goose session handoff'
    argparse 'n/no-copy' 's/session=' 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "handoff-extract — extract the ```fish code block from a Goose session handoff"
        echo
        echo "usage: handoff-extract [options]"
        echo "  (no options)        newest handoff → print + copy to clipboard"
        echo "  -n, --no-copy       print only; leave the clipboard untouched"
        echo "  -s, --session <id>  target an explicit session id (default: newest)"
        echo "  -h, --help          this help"
        echo
        echo "Only the NEWEST handoff is read, and only its LAST ```fish fence is"
        echo "taken — earlier handoffs and earlier blocks are never reused."
        echo "No handoff/block → nothing copied, reminder on stderr, exit 1."
        return 0
    end

    set -l db (__goose_db)
    or return 1

    if not command -v sqlite3 >/dev/null 2>&1
        echo "handoff-extract: sqlite3 not found." >&2
        return 1
    end

    set -l session_id ""
    if set -q _flag_session[1]
        set session_id $_flag_session[1]
    else
        set session_id (sqlite3 -readonly $db "SELECT id FROM sessions ORDER BY updated_at DESC LIMIT 1;")
    end
    if test -z "$session_id"
        echo "handoff-extract: no sessions found — no session handoff available." >&2
        echo "handoff-extract: finish a Goose turn, run 'handoff-copy', then retry." >&2
        return 1
    end
    set -l sid_esc (string replace -a "'" "''" "$session_id")

    # Newest assistant text block of that session == the handoff body
    # (mirrors handoff-copy.fish; `string collect -a` prevents array shattering).
    set -l text (sqlite3 -readonly $db "SELECT json_extract(value, '\$.text') FROM messages, json_each(messages.content_json) WHERE session_id = '$sid_esc' AND role = 'assistant' AND json_extract(value, '\$.type') = 'text' AND length(json_extract(value, '\$.text')) > 0 ORDER BY messages.id DESC LIMIT 1;" | string collect -a)
    if test -z "$text"
        echo "handoff-extract: no assistant handoff text in session $session_id." >&2
        echo "handoff-extract: nothing copied — no session handoff available." >&2
        return 1
    end

    # Greedy .* anchors on the ABSOLUTE LAST ```fish fence (skips earlier blocks).
    set -l block (string match -rg '(?s).*```fish[^\n]*\n(.*?)\n[ \t]*```' "$text" | string collect -a)
    if test -z "$block"
        echo "handoff-extract: no ```fish code block in the latest handoff (session $session_id)." >&2
        echo "handoff-extract: nothing copied — ask Goose for the exact fish commands, then retry." >&2
        return 1
    end

    printf '%s\n' "$block"

    if not set -q _flag_no_copy
        if command -v wl-copy >/dev/null 2>&1
            printf '%s\n' "$block" | wl-copy
            echo "handoff-extract: fish block copied to clipboard (session $session_id)." >&2
        else
            echo "handoff-extract: wl-copy not found; printed to stdout only." >&2
        end
    end

    return 0
end
