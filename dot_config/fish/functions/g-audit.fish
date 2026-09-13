function g-audit --description 'Goose session — Kimi (audit/review role)'
    env GOOSE_PROVIDER=moonshot GOOSE_MODEL=kimi-k3 goose session $argv
end
