function aup --description 'Update system, rust, uv, bun, go, and tldr'
    # 1. System updates
    cachy-update

    # 2. Rust ecosystem updates
    and rustup update
    and cargo install-update -a

    # 3. Python/uv tool updates
    and uv self update
    and uv tool upgrade --all

    # 4. Bun global package updates (isolated in a block)
    and begin
        bun upgrade
        cd ~/.bun/install/global
        and bun update --latest
        and cd ~
    end

    # 5. Go global binaries update
    and gup update

    # 6. tldr update
    and tldr --update
end
