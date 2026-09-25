function g-draft --description 'Goose session — DeepSeek Pro (drafting role)'
    env GOOSE_PROVIDER=custom_deepseek GOOSE_MODEL=deepseek-v4-pro GOOSE_MOIM_MESSAGE_FILE=$HOME/.agents/draft-executor.md goose session $argv
end
