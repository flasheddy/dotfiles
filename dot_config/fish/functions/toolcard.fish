function toolcard --description 'Query the local tool cards (~/.local/share/toolcards)'
    set -l dir $HOME/.local/share/toolcards
    set -l mode query
    set -l name

    for a in $argv
        switch $a
            case --list -l
                set mode list
            case --validate -V
                set mode validate
            case '-*'
                echo "toolcard: unknown option: $a" >&2
                return 2
            case '*'
                set name $a
        end
    end

    if not test -d $dir
        echo "toolcard: no card directory at $dir" >&2
        return 1
    end

    set -l cards $dir/*.md
    if not test -f $cards[1]
        echo "toolcard: no cards in $dir" >&2
        return 1
    end

    switch $mode
        case list
            for c in $cards
                echo (string replace -r '\.md$' '' (path basename $c))
            end
            return 0

        case validate
            set -l bad 0
            for c in $cards
                set -l base (string replace -r '\.md$' '' (path basename $c))
                set -l tool (rg -o -r '$1' --no-filename '^tool:\s*(\S+)' $c 2>/dev/null | head -n1)
                set -l bin (rg -o -r '$1' --no-filename '^binary:\s*(\S+)' $c 2>/dev/null | head -n1)
                set -l auth (rg -o -r '$1' --no-filename '^authoritative:\s*(.+)$' $c 2>/dev/null | head -n1)

                if test "$tool" != "$base"
                    echo "toolcard: $c: 'tool: $tool' does not match filename '$base'" >&2
                    set bad 1
                end
                if test -z "$bin"
                    echo "toolcard: $c: missing 'binary:'" >&2
                    set bad 1
                else if not test -x "$bin"
                    echo "toolcard: $c: binary '$bin' missing or not executable" >&2
                    set bad 1
                end
                if test -z "$auth"
                    echo "toolcard: $c: missing 'authoritative:'" >&2
                    set bad 1
                end
            end
            if test $bad -eq 0
                echo "toolcard: "(count $cards)" cards valid"
            end
            return $bad

        case query
            if test -z "$name"
                echo "usage: toolcard <tool> | --list | --validate" >&2
                return 2
            end
            set -l file $dir/$name.md
            if not test -f $file
                echo "toolcard: no card for '$name' — fall back to man/--help and do not invent" >&2
                set -l names
                for c in $cards
                    set -a names (string replace -r '\.md$' '' (path basename $c))
                end
                echo "toolcard: available: "(string join ', ' $names) >&2
                return 1
            end
            cat $file
            return 0
    end
end
