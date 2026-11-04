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
- CachyOS-specific packages (`cachyos-*`, `cachy-update`)
- Kernels and firmware (`linux-cachyos*`, `linux-firmware`, `amd-ucode`, `sof-firmware`)
- NVIDIA/AMD/Vulkan graphics drivers and 32-bit counterparts
- Filesystem tools (`btrfs-progs`, `lvm2`, `cryptsetup`, `mdadm`, etc.)
- Networking, Bluetooth, firewall, and remote access (incl. `syncthing`;
  its LAN sync ports 22000/tcp+udp and 21027/udp are opened by the
  `run_onchange_after_20-setup-system` hook)
- Package-management helpers (`paru`, `pacman-contrib`)

### `10-desktop-environment.txt`

COSMIC desktop environment and everything needed for a graphical Wayland
workstation: display manager, audio stack, input methods, fonts, themes,
browsers, media codecs, and GUI applications.

Key groups:

- COSMIC desktop components (`cosmic-session` pulls the rest)
- Display manager (`sddm`) and display utilities
- Audio stack (PipeWire, ALSA, JACK, Pavucontrol)
- Input methods (`fcitx5*` + Mozc/Rime, `keyd`)
- Fonts (including `ttf-jetbrains-mono-nerd` for terminal glyph rendering)
  and cursor/wallpaper themes
- Web browsers (`firefox`, `ungoogled-chromium-bin`)
- Email client (`thunderbird`)
- Media players/codecs and document libraries
- Wayland/desktop integration tools (`grim`, `wl-clipboard`, `xdg-*`)
- GUI applications (`clash-verge-rev-bin`, etc.)

> **Note:** `clash-verge-rev-bin` requires the companion `clash-verge-service`
> system service for TUN mode. The service is installed and enabled by the
> `run_onchange_after_20-setup-system.sh.tmpl` hook.

### `20-dev-stacks.txt`

Compilers, language runtimes, language servers, build/test/linters, and databases.

Key groups:

- Language runtimes: Go, Node.js LTS (+ `npm`), Perl, Python
- Go toolchain (`delve`, `golangci-lint`, `gopls`)
- Build/test/linters (`bats*`, `shellcheck`, `shfmt`, `taplo-cli`)
- Language servers and documentation tools (`bash-language-server`, `gdb`,
  `lldb`, `markdown-oxide`, `typos-lsp`, `zola`). `gdb` is Helix's C/C++ debug
  adapter (`gdb --interpreter=dap`, see `dot_config/helix/languages.toml`);
  `lldb`'s `lldb-dap` is unusable with Helix 25.07 (handshake deadlock).
- Spelling/typo gate (`typos`, standalone CLI). Its global config is
  `~/.typos.toml` (chezmoi source: `dot_typos.toml`) — typos walks up from the
  working directory and does **not** read `$XDG_CONFIG_HOME`.

**Note:** Rust (`rustup`/`cargo`) and `uv` are intentionally omitted from this
file. They are managed as standalone toolchains (see the `toolchains/`
directory).

### `30-terminal-utilities.txt`

Terminal emulators, editors, read-only document readers, shell enhancements,
Git tooling, and everyday CLI utilities.

Key groups:

- Editors (`helix`)
- Readers (`csvlens`, `jless`) — read-only terminal document viewers
  (JSON / TSV)
- Shell enhancements (`starship`, `zoxide`)
- Git tooling (`git`, `github-cli`, `gitleaks`, `git-delta`, `lazygit`)
- CLI utilities (`ripgrep`, `fd`, `sd`, `dust`, `duckdb`, `procs`, `hyperfine`, `just`, `tokei`, `btop`, `7zip`, `wget`, `xh`, `vivid`, etc.)
- Local dictation (`whisper-cpp`): the CPU whisper.cpp CLI behind `dictate`
  (see README → Dictation). The `ggml` model is data, not a package, so it is
  fetched once and never tracked.

### `flatpak.txt`

Flatpak applications installed outside of pacman, from the `flathub` remote
(user installation). The `run_onchange_after_00-install-packages.sh.tmpl` hook
installs any app listed here that is not already present — it skips apps that
are already installed, so the step is idempotent.

Currently managed:

- `com.remnote.RemNote`

> **Note:** the hook installs into the **user** installation (`--user flathub`).
> `com.remnote.RemNote` is currently present as a **system** installation.
> `flatpak info` matches either, so the hook skips it today, but a fresh machine
> would receive it as a per-user install.

### `archive/pacman-native.txt` / `archive/pacman-foreign.txt` (source/legacy)

These are the original explicitly-installed package dumps, now archived under
`archive/`:

- `archive/pacman-native.txt`: packages from official repositories.
- `archive/pacman-foreign.txt`: packages from the AUR or other non-official sources.
  This is also the **live** AUR manifest that hook 00 consumes (§1.3), so new AUR
  entries go here. Added beyond the original dump: `dotool` (compositor-agnostic
  text injection through `/dev/uinput`, used by `dictate`) and `docker-desktop`
  (AUR — runs its own QEMU/KVM VM and **provides** `docker-compose`,
  `docker-buildx`, `docker-debug`, `docker-mcp` and `docker-scout`, so those must
  never be added as standalone packages while it is installed). Its dependencies
  (`docker`, `qemu*`, `pass`, `nftables`, …) are deliberately left transitive;
  `w3m` is a makedep and is not tracked. `pass` is unusable as Desktop's
  credential store until a GPG secret key exists (`pass init <key-id>`). The
  root `docker.service` stays **disabled** — Desktop drives its own VM through
  the per-user `docker-desktop.service`.

They were used as the source for the modular lists above. Several packages
appear in both files; in practice those overlapping packages are AUR builds.
The active package lists in `packages/` are the modular manifests only.

## Tracked Configuration Files

Dotfiles managed under `dot_config/` include:

- **Fish shell**: `config.fish`, completions (`bun.fish`), and functions
  (`aup.fish`). PATH is configured to include standalone toolchain directories
  (`~/.local/bin`, `~/.cargo/bin`, `~/.bun/bin`, `~/go/bin`).
- **Helix editor**: `config.toml`, `languages.toml`.
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
| Manual `~/.local/bin` binaries | downloaded manually | `toolchains/local-bin.txt` |

### `toolchains/cargo.txt`

Rust crates installed with `cargo install`, plus the binaries they provide.

### `toolchains/uv.txt`

Python CLI tools installed with `uv tool install`:

- `litecli`
- `ruff`

### `toolchains/bun.txt`

Global JavaScript/TypeScript packages installed with `bun install -g`:

- `prettier`
- `typescript`
- `typescript-language-server`
- `vscode-langservers-extracted`

### `toolchains/go.txt`

Go modules installed with `go install`:

- `github.com/nametake/golangci-lint-langserver`
- `github.com/nao1215/gup`

### `toolchains/local-bin.txt`

Standalone binaries placed directly in `~/.local/bin` and not managed by any
toolchain manager above. Managed symlinks live in `dot_local/bin/`.

Previously this file also contained symlinks for `uv`/`uvx` (standalone
toolchain), `python3.12` (uv-managed Python), and
`litecli`/`ruff` (uv-managed tools). Those entries were removed
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

Other tools like `fish`, `fastfetch`, `fzf`, `pkgfile`, `bat`, and `eza` are
pulled in by `cachyos-fish-config` and do not need to be listed separately.

## Syncthing (PC ↔ Android Sync)

Continuous file sync between this workstation and Android. The repository
provisions the package, the firewall holes, and session independence; the sync
root itself is data and is deliberately **not** chezmoi-managed.

Provisioned by the repository:

- **Native package** — `syncthing` in `00-system-base.txt`, v2.x with
  `[noupgrade]`, so the version follows the repo and no self-updater runs.
- **Firewall rules** — `run_onchange_after_20-setup-system.sh.tmpl` opens
  inbound `22000/tcp`, `22000/udp` (QUIC), and `21027/udp` (local discovery).
- **Session independence** — the same hook runs `loginctl enable-linger`, which
  keeps the user service alive with no login session.

Runtime layout (data and key material — not managed, never tracked):

- `~/.local/state/syncthing/` — `config.xml`, `cert.pem`, `key.pem`,
  `https-key.pem`, `index-v2/*.db`. This directory holds the device private keys
  and the GUI/API credentials, so it must never be tracked.
- `~/Sync/` — the sync root; files are placed here manually.
- `127.0.0.1:8384` — web UI, loopback-only and deliberately not opened in ufw.
- `syncthing.service` (user) — run and checked with `systemctl --user`.

Verified behaviour and known limits:

- **Symlinks are not synced.** The scanner records a `FILE_INFO_TYPE_SYMLINK`
  entry with `size 0`, `numBlocks 0` and no platform target, so the linked
  content is never indexed or transferred. To sync a directory that lives
  elsewhere, add that directory as its own Syncthing folder rather than linking
  it into a synced one.
- **Media settings** (recommended, not required) — set the PC folder to
  *Send Only* and the phone to *Receive Only* so a deletion on the phone cannot
  delete the PC library; enable file versioning for recoverability; on the phone
  restrict syncing to Wi-Fi and set battery usage to *Unrestricted* (a flapping
  link is the symptom of the latter).
- **Local discovery vs. the TUN proxy** — `255.255.255.255` is hijacked by the
  Clash Verge TUN, but Syncthing announces to the per-interface broadcast
  address (`192.168.2.255`), which routes direct. Discovery and direct LAN
  connections therefore work. If a peer ever falls back to relay, pin a static
  `tcp://<LAN-IP>:22000` address for that device.

Verification:

```fish
systemctl --user is-active syncthing.service              # active
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8384   # 200
ss -lntup | rg '22000|21027|8384'                         # listeners bound
loginctl show-user (id -un) -p Linger                     # Linger=yes
syncthing cli show connections                            # peer state, connection.lan
syncthing cli debug file <folder-id> <path>               # index entry for one path
```
