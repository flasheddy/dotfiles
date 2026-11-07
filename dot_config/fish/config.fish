# CachyOS base config
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# core shell functions
# disable greeting
function fish_greeting
end
# set vim mode
function fish_user_key_bindings
    set -g fish_key_bindings fish_vi_key_bindings
    # Accept autosuggestion with Ctrl-F
    bind -M insert \cf forward-char
    bind -M default \cf forward-char
end

# global environment variables
# editor
set -gx EDITOR hx
set -gx VISUAL hx
set -gx SUDO_EDITOR /usr/bin/helix

# theme
# bat
set -gx BAT_PAGING auto
set -gx BAT_THEME "Catppuccin Mocha"
# fzf: match BAT_THEME
set -gx FZF_DEFAULT_OPTS "--height=60% --layout=reverse --border --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# paths
# user binary and toolchain
fish_add_path -P -m $HOME/.local/bin $HOME/.bun/bin $HOME/go/bin
# deduplicate $PATH preserving priority order
set -l _unique_path
for _entry in $PATH
    if not contains -- $_entry $_unique_path
        set -a _unique_path $_entry
    end
end
set -gx PATH $_unique_path

# interactive guard
if status is-interactive
    # fast abbreviations
    # chezmoi
    abbr --add --global cm 'cd ~/.local/share/chezmoi'
    abbr --add --global cma 'chezmoi apply'
    abbr --add --global cmd 'chezmoi diff'
    abbr --add --global cms 'chezmoi status'
    # uv
    abbr --add --global uvs 'uv sync'
    abbr --add --global uvr 'uv run'
    # doc readers
    abbr --add --global jl jless
    abbr --add --global tsv 'csvlens -t'
    # focus timer
    abbr --add --global ft focus-timer

    # tool initializations
    # fuzzy finder
    type -q fzf; and fzf --fish | source
    # prompt engine
    type -q starship; and starship init fish | source
    # smarter cd
    type -q zoxide; and zoxide init fish | source
    # file listing palette generator
    type -q vivid; and set -gx LS_COLORS (vivid generate catppuccin-mocha)
end
