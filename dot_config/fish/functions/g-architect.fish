function g-architect --description 'Goose session — Prompt Architect (zero-write prompt compiler)'
    # Guarantee an "architect-" name prefix so envelope-copy can find these sessions.
    set -l args
    set -l i 1
    set -l named 0
    while test $i -le (count $argv)
        set -l a $argv[$i]
        if test "$a" = -n; or test "$a" = --name
            set -l name $argv[(math $i + 1)]
            set -a args "$a" "architect-$name"
            set named 1
            set i (math $i + 2)
        else
            set -a args "$a"
            set i (math $i + 1)
        end
    end
    if test $named -eq 0
        set -a args -n "architect-"(date +%Y%m%d_%H%M%S)
    end
    env GOOSE_PROVIDER=custom_deepseek GOOSE_MODEL=deepseek-v4-pro GOOSE_MOIM_MESSAGE_FILE=$HOME/.agents/architect-zero-write.md goose session $args
    # Strict variant (operator approves every tool call; uncomment to enable):
    # env GOOSE_PROVIDER=custom_deepseek GOOSE_MODEL=deepseek-v4-pro GOOSE_MODE=approve GOOSE_MOIM_MESSAGE_FILE=$HOME/.agents/architect-zero-write.md goose session $args
end
