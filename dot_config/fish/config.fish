# CachyOS shell defaults (guarded: path exists only on CachyOS)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

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
# Guard bat pager on interactive shell
if status is-interactive
    set -gx BAT_PAGING auto
else
    set -gx BAT_PAGING never
end
set -gx BAT_THEME "Catppuccin Mocha"
set -gx GOOSE_CLI_THEME dark
set -gx GOOSE_CLI_DARK_THEME "Catppuccin Mocha"
set -gx GOOSE_SHELL /usr/bin/fish

# Editor (hx is the strict default)
set -gx EDITOR hx
set -gx VISUAL hx
set -gx SUDO_EDITOR /usr/bin/helix

# Input method (fcitx5)
set -gx GTK_IM_MODULE fcitx
set -gx QT_IM_MODULE fcitx
set -gx XMODIFIERS @im=fcitx
set -gx IMMODULE fcitx

# Toolchain and user binary paths (portable: $HOME expands per machine;
# ~/.cargo/bin is handled by conf.d/rustup.fish)
fish_add_path $HOME/.local/bin $HOME/.bun/bin $HOME/go/bin

if status is-interactive
    # Interactive command-line abbreviations
    # Chezmoi
    # native cd: `chezmoi cd` wraps a subshell in a chezmoi process that pkill cleanup kills, taking the terminal with it
    abbr --add --global cm 'cd ~/.local/share/chezmoi'
    abbr --add --global cma 'chezmoi apply'
    abbr --add --global cmd 'chezmoi diff'
    abbr --add --global cms 'chezmoi status'
    # Copy chezmoi diff and git diff to clipboard with labels
    abbr --add --global ddc '{ echo "=== chezmoi diff ==="; chezmoi diff; echo; echo "=== git diff ==="; chezmoi git -- diff; } | wl-copy'

    # Goose session management
    abbr --add --global gsl 'goose session list'
    abbr --add --global gsw 'rm -f ~/.local/share/goose/sessions/sessions.db*'

    # Python tooling
    abbr --add --global uvs 'uv sync'
    abbr --add --global uvr 'uv run'

    # Copy raw git diff to clipboard
    abbr --add --global gdc 'git --no-pager diff | wl-copy'

    # Add convenient abbreviations for terminal document readers
    abbr --add --global jl jless
    abbr --add --global tsv 'csvlens -t'

    # Prompt
    type -q starship; and starship init fish | source

    # Smarter cd
    type -q zoxide; and zoxide init fish | source

    # LS_COLORS generator
    type -q vivid; and set -gx LS_COLORS (vivid generate catppuccin-mocha)
end
