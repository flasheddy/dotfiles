# Fish UI theme: Catppuccin Mocha (dark) syntax highlighting + pager, matching
# bat/starship/fzf/eza/vivid.
#
# Values are verbatim from fish's built-in themes/catppuccin-mocha.theme [dark]
# section (fish >= 4.3):
#     status get-file themes/catppuccin-mocha.theme
# Bare hex, no '#': that is fish's own canonical form — an unquoted #hex would be
# parsed as a comment and silently leave the variable empty.
#
# This lives in conf.d/ rather than config.fish so the static color set stays a
# separate, dependency-free module. conf.d is sourced before config.fish and wins
# over fish's built-in default theme (whose values carry a --theme=default marker).
# The variables left unset here — fish_color_cwd_root, fish_color_history_current,
# fish_color_valid_path, fish_pager_color_selected_background — intentionally keep
# those fish defaults.
#
# Deliberately NOT sourced via `fish_config theme choose catppuccin-mocha
# --color-theme=dark`: that scripted resolver costs ~5.5 ms per fish process
# (measured 2026-10-16: 12.4 -> 18.1 ms per non-interactive `fish -c exit`) and
# clears every theme variable the chosen theme does not define.
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
