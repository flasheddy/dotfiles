# `hx` is a symlink to /usr/bin/helix (tracked as dot_local/bin/symlink_hx).
# fish keys completions off the command NAME, so the vendor card shipped by the
# helix package (`/usr/share/fish/vendor_completions.d/helix.fish`, which
# registers `complete -c helix` only) never applies to `hx`. `-w` (--wraps)
# chains hx onto helix's completions, so they follow whatever the package ships.
complete -c hx -w helix
