function recon-gate --description '15-minute recon gate: hard-lock session when the timer expires'
    argparse 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo "usage: recon-gate [start|cancel|done|stop]"
        echo "  start  — start the 15-minute timer (default)"
        echo "  cancel — cancel the timer (abort)"
        echo "  done   — clear the timer (task complete)"
        echo "  stop   — stop the timer"
        return 0
    end

    set -l pid_file "$XDG_RUNTIME_DIR/recon-gate.pid"
    if not test -d "$XDG_RUNTIME_DIR"
        set pid_file "/tmp/recon-gate.$UID.pid"
    end

    set -l action $argv[1]
    if test -z "$action"
        set action start
    end

    switch $action
        case start
            if test -f $pid_file; and kill -0 (cat $pid_file) 2>/dev/null
                echo "recon-gate: timer already running (pid "(cat $pid_file)")." >&2
                return 1
            end
            set -l duration 900 # 15 minutes
            fish -c "sleep $duration; loginctl lock-session" >/dev/null 2>&1 &
            disown $last_pid
            echo $last_pid > $pid_file
            echo "recon-gate: 15-minute timer started (pid $last_pid)."
            return 0

        case cancel done stop
            if test -f $pid_file
                set -l pid (cat $pid_file)
                if kill -0 $pid 2>/dev/null
                    kill $pid 2>/dev/null
                end
                rm -f $pid_file
                switch $action
                    case cancel
                        echo "recon-gate: timer cancelled."
                    case done
                        echo "recon-gate: timer cleared — recon complete."
                    case stop
                        echo "recon-gate: timer stopped."
                end
            else
                echo "recon-gate: no active timer." >&2
                return 1
            end
            return 0

        case '*'
            echo "recon-gate: unknown command '$action'. usage: recon-gate [start|cancel|done|stop]" >&2
            return 1
    end
end
