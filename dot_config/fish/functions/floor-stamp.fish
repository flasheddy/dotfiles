function floor-stamp --description 'Refresh the floor-contract marker in ./AGENTS.md against the live global floor'
    # Layer C helper. Rewrites ONLY the marker line; the operator still has to
    # have re-affirmed the repository's inheritance against the floor first —
    # this is a mechanical refresh, not a substitute for reading the diff.
    set -l floor $HOME/.AGENTS.md
    set -l file AGENTS.md

    if not test -f $floor
        echo "floor-stamp: no global floor at $floor" >&2
        return 1
    end
    if not test -f $file
        echo "floor-stamp: no AGENTS.md in "(pwd) >&2
        return 1
    end

    set -l hex (sha256sum $floor | string split ' ')[1]

    if not rg -q 'floor-contract:' $file
        echo "floor-stamp: no floor-contract marker in "(pwd)"/AGENTS.md" >&2
        echo "floor-stamp: opt in by adding this line after the title:" >&2
        echo "  <!-- floor-contract: sha256:$hex -->" >&2
        return 1
    end

    set -l marker "<!-- floor-contract: sha256:$hex -->"
    set -l content (cat $file | string collect)
    # `string collect` keeps the result a single string; plain command
    # substitution would split it on newlines and make the comparison below
    # always fail (and repeated runs would rewrite the file needlessly).
    set -l updated (string replace -r '<!--\s*floor-contract:\s*sha256:[0-9a-fA-F]{64}\s*-->' $marker $content | string collect)

    if test "$updated" = "$content"
        echo "floor-stamp: already current ("(string sub -l 12 $hex)")"
        return 0
    end

    if test -z "$updated"
        echo "floor-stamp: refusing to write an empty file" >&2
        return 1
    end

    printf '%s\n' $updated > $file
    echo "floor-stamp: refreshed "(pwd)"/AGENTS.md -> "(string sub -l 12 $hex)
end
