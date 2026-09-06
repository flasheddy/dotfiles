# Rust toolchain env (guarded: file absent until rustup is installed)
if test -f "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end
