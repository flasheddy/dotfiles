function g-architect --description 'Goose session — Prompt Architect (zero-write prompt compiler)'
    env GOOSE_PROVIDER=custom_deepseek GOOSE_MODEL=deepseek-v4-pro GOOSE_MOIM_MESSAGE_FILE=$HOME/.agents/architect-zero-write.md goose session $argv
    # Strict variant (operator approves every tool call; uncomment to enable):
    # env GOOSE_PROVIDER=custom_deepseek GOOSE_MODEL=deepseek-v4-pro GOOSE_MODE=approve goose session $argv
end
