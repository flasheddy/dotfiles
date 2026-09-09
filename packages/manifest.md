# Package Manifest

This directory contains the machine/package lists for reproducing the CachyOS
dotfiles managed by this chezmoi repository.

## Files

### `00-system-base.txt`

Core CachyOS tooling, kernel utilities, hardware drivers, base system
meta-packages, filesystem/storage tools, networking stack, and system-wide
services.

Key groups:

- `base` / `base-devel` meta-packages
- CachyOS-specific packages (`cachyos-*`, `cachy-update`, `chwd`)
- Kernels and firmware (`linux-cachyos*`, `linux-firmware`, `amd-ucode`, `sof-firmware`)
- NVIDIA/AMD/Vulkan graphics drivers and 32-bit counterparts
- Filesystem tools (`btrfs-progs`, `lvm2`, `cryptsetup`, `mdadm`, etc.)
- Networking, Bluetooth, firewall, and remote access
- Package-management helpers (`paru`, `yay`, `shelly`, `pacman-contrib`)

### `10-desktop-environment.txt`

COSMIC desktop environment and everything needed for a graphical Wayland
workstation: display manager, audio stack, input methods, fonts, themes,
browsers, media codecs, and GUI applications.

Key groups:

- COSMIC desktop components (`cosmic-session` pulls the rest)
- Display manager (`sddm`) and display utilities
- Audio stack (PipeWire, ALSA, JACK, Pavucontrol)
- Input methods (`fcitx5*` + Mozc/Rime, `keyd`)
- Fonts and cursor/wallpaper themes
- Web browsers (`firefox`, `ungoogled-chromium-bin`)
- Media players/codecs and document libraries
- Wayland/desktop integration tools (`grim`, `wl-clipboard`, `xdg-*`)
- GUI applications (`android-studio`, `clash-verge-rev-bin`, `wechat-universal-bwrap`, etc.)

### `20-dev-stacks.txt`

Compilers, language runtimes, language servers, build/test/linters, databases,
and Android tooling.

Key groups:

- Language runtimes: Go, OpenJDK 17, Node.js LTS (+ `npm`), Perl, PostgreSQL,
  Python
- Go toolchain (`delve`, `golangci-lint`, `gopls`)
- Python tooling (selected Python libraries)
- Build/test/linters (`bats*`, `shellcheck`, `shfmt`, `taplo-cli`)
- Language servers and documentation tools (`bash-language-server`, `lldb`,
  `marksman`, `pandoc-bin`, `zola`)
- Android tools (`android-tools`, `android-udev`)

**Note:** Rust (`rustup`/`cargo`) and `uv` are intentionally omitted from this
file. They are managed as standalone toolchains (see the `toolchains/`
directory).

### `30-terminal-utilities.txt`

Terminal emulators, editors, shell enhancements, Git tooling, everyday
CLI utilities, and the Nerd Font used by Starship/Helix glyphs.

Key groups:

- Terminal emulators (`alacritty`, `kitty`)
- Editors (`helix`, `nano`)
- Shell enhancements (`bash-completion`, `starship`, `zoxide`)
- Nerd Font (`ttf-jetbrains-mono-nerd`) for terminal glyph rendering
- Git tooling (`git`, `github-cli`, `gitleaks`, `git-delta`, `lazygit`)
- CLI utilities (`ripgrep`, `fd`, `sd`, `dust`, `procs`, `hyperfine`, `tokei`, `jless`, `btop`, `7zip`, `wget`, `xh`, `vivid`, etc.)

### `flatpak.txt`

Flatpak applications installed outside of pacman:

- `com.discordapp.Discord`
- `com.remnote.RemNote`
- `com.spotify.Client`
- `com.super_productivity.SuperProductivity`

### `archive/pacman-native.txt` / `archive/pacman-foreign.txt` (source/legacy)

These are the original explicitly-installed package dumps, now archived under
`archive/`:

- `archive/pacman-native.txt`: packages from official repositories.
- `archive/pacman-foreign.txt`: packages from the AUR or other non-official sources.

They were used as the source for the modular lists above. Several packages
appear in both files; in practice those overlapping packages are AUR builds.
The active package lists in `packages/` are the modular manifests only.

## Tracked Configuration Files

Dotfiles managed under `dot_config/` include:

- **Fish shell**: `config.fish`, completions (`bun.fish`), functions
  (`aup.fish`), and Pure prompt variables (`private_fish_variables`). PATH is
  configured to include standalone toolchain directories (`~/.local/bin`,
  `~/.cargo/bin`, `~/.bun/bin`, `$(go env GOPATH)/bin`).
- **Helix editor**: `config.toml`, `languages.toml`.
- **Zed editor**: `private_settings.json`, `keymap.json` (no database/state
  caches tracked).
- **Terminal emulators**: `alacritty/`, `kitty/`. (`ghostty/` was removed because
the package is not currently installed.)
- **Starship prompt**: `starship.toml`.
- **Git**: `dot_gitconfig`.
- **SSH**: `private_dot_ssh/config` only; private keys are ignored via
  `.gitignore`.

## Stripping Rules

Packages that are direct dependencies of meta-packages already kept in these
lists have been removed to avoid redundancy. Only packages that were actually
present in the original `archive/pacman-native.txt` / `archive/pacman-foreign.txt`
lists are shown here:

| Meta-package | Stripped direct dependencies |
|--------------|------------------------------|
| `base-devel` | `sudo`, `texinfo`, `which` |
| `cachyos-fish-config` | `fastfetch`, `pkgfile` |
| `cachyos-kernel-manager` | `chwd` |
| `cachyos-micro-settings` | `micro` |
| `cachyos-plymouth-bootanimation` / `cachyos-plymouth-theme` | `plymouth` |
| `cosmic-session` | `noto-fonts`, `ttf-opensans`, `xorg-xwayland` |

`cachyos-fish-config` also pulls in `bat`, `eza`, `fish`, `fish-autopair`,
`fish-pure-prompt`, `fisher`, `fzf`, `tealdeer`, and `ttf-fantasque-nerd`, but
those were not listed in the original package dumps, so they did not need to be
stripped.

## Standalone Toolchains

Several language runtimes and developer tools are **not** managed by pacman/AUR.
They are installed via their official installers and tracked separately in
`toolchains/`:

| Toolchain | Install method | Manifest |
|-----------|----------------|----------|
| Rust (`rustup`, `cargo`, `rustc`) | [rustup.rs](https://rustup.rs) | `toolchains/cargo.txt` |
| Python tools (`uv`, `uvx`) | [astral.sh/uv](https://docs.astral.sh/uv/getting-started/installation/) | `toolchains/uv.txt` |
| Bun (`bun`, `bunx`) | [bun.sh](https://bun.sh) | `toolchains/bun.txt` |
| Go tools (`go install`) | Built from module paths | `toolchains/go.txt` |
| Zed editor | [zed.dev](https://zed.dev) | symlinked into `~/.local/bin` |
| Haskell (GHCup, `ghc`, `cabal`) | [ghcup.haskell.org](https://www.haskell.org/ghcup/) | managed by `ghcup` |
| Manual `~/.local/bin` binaries | downloaded manually | `toolchains/local-bin.txt` |

### `toolchains/cargo.txt`

Rust crates installed with `cargo install`, plus the binaries they provide.

### `toolchains/uv.txt`

Python CLI tools installed with `uv tool install`:

- `litecli`
- `pgcli`
- `python-lsp-server`
- `ruff`

### `toolchains/bun.txt`

Global JavaScript/TypeScript packages installed with `bun install -g`:

- `prettier`
- `sql-language-server`
- `typescript`
- `typescript-language-server`
- `vscode-langservers-extracted`

### `toolchains/go.txt`

Go modules installed with `go install`:

- `github.com/bootdotdev/bootdev`
- `github.com/nametake/golangci-lint-langserver`
- `github.com/nao1215/gup`

### `toolchains/local-bin.txt`

Standalone binaries placed directly in `~/.local/bin` and not managed by any
toolchain manager above:

- `exercism`
- `goose`

Previously this file also contained symlinks for `uv`/`uvx` (standalone
toolchain), `zed` (standalone editor), `python3.12` (uv-managed Python), and
`litecli`/`pgcli`/`pylsp`/`ruff` (uv-managed tools). Those entries were removed
because they are covered by the standalone toolchain manifests.

## Additions Based on Tracked Configs

The following packages are not in the original `archive/pacman-native.txt` /
`archive/pacman-foreign.txt` dumps but are referenced by tracked configs
(`dot_config/fish/`, `dot_config/helix/`) and have been added to the appropriate
modular list:

- `npm` → `20-dev-stacks.txt` (separate pacman package required for Node.js tooling)

The following tools are also referenced by configs but are intentionally
managed as standalone toolchains and documented above:

- `rustup` / `cargo` / `rustc` (referenced by `dot_config/fish/conf.d/rustup.fish`)
- `uv` / `uvx` (referenced by `dot_config/fish/conf.d/uv.env.fish`)
- `bun` (completion file in `dot_config/fish/completions/bun.fish`)
- GHCup (`ghc`, `cabal`) (referenced in `dot_config/fish/config.fish`)
- `zed` (editor, symlinked into `~/.local/bin`)

Other tools like `fish`, `fastfetch`, `fzf`, `pkgfile`, `bat`, and `eza` are
pulled in by `cachyos-fish-config` and do not need to be listed separately.
