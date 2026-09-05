source /usr/share/cachyos-fish-config/cachyos-config.fish

# Override greeting
function fish_greeting
    # smth smth
end

function fish_user_key_bindings
    # Set Vim Mode
    set -g fish_key_bindings fish_vi_key_bindings
    # Bind Alt+C to act like Right Arrow
    bind -M insert \ec forward-char
    bind -M default \ec forward-char
end

# Environment variables
set -gx BAT_THEME "Catppuccin Mocha"
set -gx GOOSE_CLI_THEME dark
set -gx GOOSE_CLI_DARK_THEME "Catppuccin Mocha"

# Input method (fcitx5)
set -gx GTK_IM_MODULE fcitx
set -gx QT_IM_MODULE fcitx
set -gx XMODIFIERS @im=fcitx
set -gx IMMODULE fcitx

# Haskell toolchain paths
set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set -gx GHCUP_INSTALL_BASE_PREFIX $HOME
fish_add_path $HOME/.cabal/bin $HOME/.ghcup/bin

# Toolchain and user binary paths (portable: $HOME expands per machine;
# ~/.cargo/bin is handled by conf.d/rustup.fish)
fish_add_path $HOME/.local/bin $HOME/.bun/bin $HOME/go/bin

if status is-interactive
    # Interactive command-line abbreviations
    abbr --add --global hx helix
    abbr --add --global cm 'chezmoi cd'
    abbr --add --global cma 'chezmoi apply'
    abbr --add --global cms 'chezmoi status'

    # Prompt
    starship init fish | source

    # Smarter cd
    zoxide init fish | source

    # LS_COLORS generator
    set -gx LS_COLORS (vivid generate catppuccin-mocha)
end
