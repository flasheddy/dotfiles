function prompt-gate --description 'Reject prompts carrying ungrounded disk specifics'
    set -l txt
    if test (count $argv) -gt 0
        set txt (string join ' ' $argv)
    else if isatty stdin
        echo "usage: prompt-gate '<text>'  or  <cmd> | prompt-gate" >&2
        return 64
    else
        read -z txt
    end
    if test -z "$txt"
        echo "prompt-gate: empty input" >&2
        return 64
    end

    set -l hit 0
    if string match -qr '(pacman|paru|yay|\baur\b|[a-z0-9]+-bin\b)' "$txt"
        echo "REJECT: package/toolchain name present" >&2
        set hit 1
    end
    if string match -qr '(dot_config/|run_onchange_|\.tmpl\b|private_dot_|/etc/(keyd|udev|systemd)|(^|[ /])(system|archive|toolchains)/)' "$txt"
        echo "REJECT: concrete disk path present" >&2
        set hit 1
    end
    if string match -qr '(diff --git|@@ -[0-9]|index [0-9a-f]{7,}|```)' "$txt"
        echo "REJECT: diff/envelope content present" >&2
        set hit 1
    end

    if test $hit -ne 0
        echo "STOP CHECKPOINT 0: strip ungrounded specifics; resubmit as OBJECTIVE/BACKGROUND/REQUIREMENTS." >&2
        return 1
    end
    echo "prompt-gate: PASS (high-level brief only)"
    return 0
end
