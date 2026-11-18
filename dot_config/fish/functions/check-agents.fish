function check-agents --description 'Check token/byte budget for AGENTS.md (global floor + local)'
    set -l cap 24576 # 24 KB
    set -l files $argv

    if test (count $files) -eq 0
        set -l global_floor $HOME/.AGENTS.md
        set -l local_rules ./AGENTS.md
        if test -f $global_floor
            set -a files $global_floor
        end
        if test -f $local_rules; and test (realpath $local_rules) != (realpath $global_floor 2>/dev/null)
            set -a files $local_rules
        end
    end

    if test (count $files) -eq 0
        echo "check-agents: no AGENTS.md files found to inspect" >&2
        return 1
    end

    set -l total 0
    set -l parts

    for f in $files
        if not test -f $f
            echo "check-agents: cannot read $f" >&2
            return 1
        end
        set -l bytes (wc -c < $f | string trim)
        set total (math $total + $bytes)
        set -a parts "$f ($bytes B)"
    end

    set -l pct (math -s1 "($total / $cap) * 100")
    set -l summary (string join ' + ' $parts)

    if test $total -gt $cap
        echo "check-agents: FAIL: $summary = $total B exceeds $cap B cap ($pct%)" >&2
        return 1
    else
        echo "check-agents: ok: $summary = $total B / $cap B ($pct% of 24 KB cap)"
        return 0
    end
end
