function g-audit --description 'Goose session — Kimi Phase A (plan review, default) / DeepSeek Phase B (diff verify, -b)'
    set -l provider moonshot
    set -l model kimi-k3
    set -l extra

    for a in $argv
        switch "$a"
            case -b --phase-b
                set provider custom_deepseek
                set model deepseek-flash
            case '*'
                set -a extra "$a"
        end
    end

    env GOOSE_PROVIDER=$provider GOOSE_MODEL=$model GOOSE_MOIM_MESSAGE_FILE=$HOME/.agents/audit-reviewer.md goose session --no-profile --with-builtin developer,tom $extra
end
