function g-draft --description 'Goose session — DeepSeek Pro (drafting role)'
    env GOOSE_PROVIDER=custom_deepseek GOOSE_MODEL=deepseek-v4-pro goose session $argv
end
