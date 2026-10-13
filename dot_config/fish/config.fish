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

    # fzf: Ctrl-R history, Ctrl-T file picker.
    # Sourced HERE on purpose: fish_vi_key_bindings resets bindings, and this
    # hook is the last thing fish runs, so binds placed here survive.
    type -q fzf; and fzf --fish | source

    # Bind Alt+C to act like Right Arrow.
    # Deliberately AFTER the fzf source above, so it overrides fzf's Alt-C fuzzy-cd.
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

# fzf: match BAT_THEME (hexes taken from ~/.config/bat/themes/Catppuccin Mocha.tmTheme)
set -gx FZF_DEFAULT_OPTS "--height=60% --layout=reverse --border --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
set -gx GOOSE_CLI_THEME dark
set -gx GOOSE_CLI_DARK_THEME "Catppuccin Mocha"
set -gx GOOSE_SHELL /usr/bin/fish

# Fish UI theme: Catppuccin Mocha (dark) syntax highlighting + pager, matching
# bat/starship/fzf/eza/vivid. Values taken verbatim from fish's built-in
# themes/catppuccin-mocha.theme [dark] section (fish >= 4.3):
#     status get-file themes/catppuccin-mocha.theme
# Bare hex, no '#': that is fish's own canonical form (see the generated
# conf.d/fish_frozen_theme.fish) — an unquoted #hex would be parsed as a comment
# and silently leave the variable empty.
# Global scope, and config.fish is sourced after conf.d, so this tracked file
# wins over any machine-generated conf.d/fish_frozen_theme.fish that running
# `fish_config` may write.
set -g fish_color_normal cdd6f4
set -g fish_color_command 89b4fa
set -g fish_color_param f2cdcd
set -g fish_color_keyword cba6f7
set -g fish_color_quote a6e3a1
set -g fish_color_redirection f5c2e7
set -g fish_color_end fab387
set -g fish_color_comment 7f849c
set -g fish_color_error f38ba8
set -g fish_color_gray 6c7086
set -g fish_color_selection --background=313244
set -g fish_color_search_match --background=313244
set -g fish_color_option a6e3a1
set -g fish_color_operator f5c2e7
set -g fish_color_escape eba0ac
set -g fish_color_autosuggestion 6c7086
set -g fish_color_cancel f38ba8
set -g fish_color_cwd f9e2af
set -g fish_color_user 94e2d5
set -g fish_color_host 89b4fa
set -g fish_color_host_remote a6e3a1
set -g fish_color_status f38ba8
set -g fish_pager_color_progress 6c7086
set -g fish_pager_color_prefix f5c2e7
set -g fish_pager_color_completion cdd6f4
set -g fish_pager_color_description 6c7086

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
