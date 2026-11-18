# Regenerate fish's man-page completions plus the tool-generated ones.
# Generated tool completions live in the fish vendor directory (unmanaged),
# so refreshing them never creates chezmoi drift.
function cup --description 'Regenerate fish, bun, and opencode completions'
    set -l rc 0
    set -l data $HOME/.local/share
    test -n "$XDG_DATA_HOME"
    and set data $XDG_DATA_HOME
    set -l dir $data/fish/vendor_completions.d
    mkdir -p $dir

    fish_update_completions
    or set rc $status

    if type -q bun
        if bun completions >$dir/bun.fish.tmp; and mv -f $dir/bun.fish.tmp $dir/bun.fish
            true
        else
            set rc $status
            rm -f $dir/bun.fish.tmp
        end
    end

    if type -q opencode
        if opencode --completions fish >$dir/opencode.fish.tmp; and mv -f $dir/opencode.fish.tmp $dir/opencode.fish
            true
        else
            set rc $status
            rm -f $dir/opencode.fish.tmp
        end
    end

    return $rc
end
