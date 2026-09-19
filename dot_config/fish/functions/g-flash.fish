function g-flash --description 'Goose session — DeepSeek Flash (fast role)'
    env GOOSE_PROVIDER=custom_deepseek GOOSE_MODEL=deepseek-flash GOOSE_THINKING_EFFORT=medium goose session $argv
end
