function g-audit --description 'Goose session — Kimi (audit/review role)'
    env GOOSE_PROVIDER=moonshot GOOSE_MODEL=kimi-k3 GOOSE_MOIM_MESSAGE_FILE=$HOME/.agents/audit-reviewer.md goose session $argv
end
