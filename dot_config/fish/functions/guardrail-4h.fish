function guardrail-4h --description '4-hour guardrail: hard-lock session when the timer expires'
    argparse 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo "usage: guardrail-4h [start|cancel|done|stop]"
        echo "  start  — start the 4-hour timer (default)"
        echo "  cancel — cancel the timer (abort)"
        echo "  done   — clear the timer (task complete)"
        echo "  stop   — stop the timer"
        return 0
    end

    set -l pid_file "$XDG_RUNTIME_DIR/guardrail-4h.pid"
    if not test -d "$XDG_RUNTIME_DIR"
        set pid_file "/tmp/guardrail-4h.$UID.pid"
    end

    set -l action $argv[1]
    if test -z "$action"
        set action start
    end

    switch $action
        case start
            if test -f $pid_file; and kill -0 (cat $pid_file) 2>/dev/null
                echo "guardrail-4h: timer already running (pid "(cat $pid_file)")." >&2
                return 1
            end
            set -l duration 14400 # 4 hours
            fish -c "sleep $duration; loginctl lock-session" >/dev/null 2>&1 &
            disown $last_pid
            echo $last_pid > $pid_file
            echo "guardrail-4h: 4-hour timer started (pid $last_pid)."
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
                        echo "guardrail-4h: timer cancelled."
                    case done
                        echo "guardrail-4h: timer cleared — task complete."
                    case stop
                        echo "guardrail-4h: timer stopped."
                end
            else
                echo "guardrail-4h: no active timer." >&2
                return 1
            end
            return 0

        case '*'
            echo "guardrail-4h: unknown command '$action'. usage: guardrail-4h [start|cancel|done|stop]" >&2
            return 1
    end
end
