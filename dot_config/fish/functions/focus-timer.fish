function focus-timer --description 'Focus timer: hard-locks the session (loginctl lock-session) on expiry'
    argparse 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo "usage: focus-timer [minutes|cancel|done|stop]"
        echo "  minutes  — start a timer for N minutes (default 240)"
        echo "  cancel   — cancel the running timer (abort)"
        echo "  done     — clear the running timer (task complete)"
        echo "  stop     — stop the running timer"
        return 0
    end

    set -l pid_file "$XDG_RUNTIME_DIR/focus-timer.pid"
    if not test -d "$XDG_RUNTIME_DIR"
        set pid_file "/tmp/focus-timer.$UID.pid"
    end

    set -l action $argv[1]
    set -l minutes $argv[2]

    # A bare number (or no argument) means "start".
    if string match -q -r '^[0-9]+$' "$action"
        set minutes $action
        set action start
    else if test -z "$action"
        set action start
    end

    switch "$action"
        case start
            if test -f $pid_file; and kill -0 (cat $pid_file) 2>/dev/null
                echo "focus-timer: timer already running (pid "(cat $pid_file)")." >&2
                return 1
            end
            if test -z "$minutes"
                set minutes 240
            end
            if not string match -q -r '^[0-9]+$' "$minutes"
                echo "focus-timer: duration must be a positive integer of minutes (got '$minutes')." >&2
                return 1
            end
            set -l seconds (math "$minutes * 60")
            fish -c "sleep $seconds; loginctl lock-session" >/dev/null 2>&1 &
            disown $last_pid
            echo $last_pid > $pid_file
            echo "focus-timer: $minutes-minute timer started (pid $last_pid)."
            return 0

        case cancel done stop
            if test -f $pid_file
                set -l pid (cat $pid_file)
                if kill -0 $pid 2>/dev/null
                    kill $pid 2>/dev/null
                end
                rm -f $pid_file
                switch "$action"
                    case cancel
                        echo "focus-timer: timer cancelled."
                    case done
                        echo "focus-timer: timer cleared."
                    case stop
                        echo "focus-timer: timer stopped."
                end
            else
                echo "focus-timer: no active timer." >&2
                return 1
            end
            return 0

        case '*'
            echo "focus-timer: unknown command '$action'. usage: focus-timer [minutes|cancel|done|stop]" >&2
            return 1
    end
end
