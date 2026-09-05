# CachyOS Dotfiles

A declarative, reproducible CachyOS workstation managed with [chezmoi](https://www.chezmoi.io/).

This repository defines the full software stack of a COSMIC desktop development machine: system packages, desktop applications, developer toolchains, shell/editor configuration, and root-level system services.

---

## System & Dotfiles Architecture

### High-Level Overview

| Layer | Technology |
|---|---|
| **OS / Desktop** | CachyOS (Arch-based) + COSMIC desktop environment |
| **Shell** | Fish (with CachyOS defaults overridden by custom config) |
| **Editors** | Helix (primary), Zed, nano |
| **Prompt** | Starship |
| **Terminals** | Alacritty, Kitty |
| **Theme** | Catppuccin Mocha (shell, Helix, Starship, cursors, Zed) |
| **Input** | keyd (capslock overload), fcitx5 (Mozc/Rime) |
| **Package Management** | Pacman + AUR helpers (`paru` / `yay`) |
| **Dev Toolchains** | Standalone upstream installers: `rustup`, `uv`, `bun`, `ghcup`, `go` |

### Decoupling Strategy: System Packages vs. Developer Toolchains

System software is installed from the CachyOS/Arch repositories and the AUR via the modular package manifests in `packages/`.

Language-specific developer tooling is kept **out of Pacman** and installed via official upstream installers:

| Toolchain | Manager | Manifest | Installation Location |
|---|---|---|---|
| Rust | `rustup` + `cargo` | `toolchains/cargo.txt` | `~/.cargo/bin` |
| Python CLI tools | `uv` | `toolchains/uv.txt` | `~/.local/bin` |
| JS/TS tools | `bun` | `toolchains/bun.txt` | `~/.bun/bin` |
| Go tools | `go install` | `toolchains/go.txt` | `~/go/bin` |
| Haskell | `ghcup` | managed by GHCup | `~/.ghcup/bin`, `~/.cabal/bin` |
| Manual binaries | — | `toolchains/local-bin.txt` | `~/.local/bin` |

This avoids version conflicts with distro packages and lets each toolchain self-update on its own schedule.

### Automated Lifecycle Hooks

Three `run_onchange_after_*.sh.tmpl` hooks run after chezmoi applies config changes:

1. **`run_onchange_after_00-install-packages.sh.tmpl`** — Installs/updates native Pacman packages, AUR packages, and Flatpaks from the manifests.
2. **`run_onchange_after_10-install-toolchains.sh.tmpl`** — Bootstraps `rustup`, `uv`, `bun`, `zed`, and `ghcup` if missing, then restores sub-tools from `toolchains/*.txt`.
3. **`run_onchange_after_20-setup-system.sh.tmpl`** — Configures root-level services:
   - Deploys `system/keyd/default.conf` to `/etc/keyd/default.conf` and reloads `keyd`.
   - Sets UFW defaults: deny incoming, allow outgoing, enable firewall.
   - Enables `fstrim.timer` and `paccache.timer`.
   - Enables `clash-verge-service` if installed.
   - Initializes and starts `postgresql` if installed.

### Key Remapping

`system/keyd/default.conf` remaps **Caps Lock** to a dual-function key:

```ini
[ids]
*

[main]
capslock = overload(control, esc)
```

- **Tap** Caps Lock → `Esc`
- **Hold** Caps Lock → `Control`

---

## Fresh Machine Bootstrap

### Prerequisites

1. Install CachyOS with a working internet connection.
2. Ensure `git` and `chezmoi` are available (CachyOS ships them by default).
3. Have your SSH private key ready, or generate a new one.

### SSH Key Restoration

This repository tracks only `private_dot_ssh/config`. Private keys are excluded by `.gitignore` and must be restored separately.

**Option A — Copy from backup:**

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp /path/to/backup/id_ed25519 ~/.ssh/
cp /path/to/backup/id_ed25519.pub ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

**Option B — Generate a new key:**

```bash
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519
```

Then add the new public key to GitHub / GitLab / servers as needed.

### Master Bootstrap Command

```bash
chezmoi init --apply https://github.com/flasheddy/dotfiles.git
```

Replace the URL with your actual repository URL.

### What Happens Automatically

1. **chezmoi** copies all dotfiles to `~/.config/`, `~/.ssh/config`, `~/.gitconfig`, etc.
2. **`run_onchange_after_00-install-packages.sh.tmpl`** runs:
   - `sudo pacman -S --needed --noconfirm - < packages/00-system-base.txt`
   - `sudo pacman -S --needed --noconfirm - < packages/10-desktop-environment.txt`
   - `sudo pacman -S --needed --noconfirm - < packages/20-dev-stacks.txt`
   - `sudo pacman -S --needed --noconfirm - < packages/30-terminal-utilities.txt`
   - AUR packages from `archive/pacman-foreign.txt` via `paru` or `yay`
   - Flatpaks from `packages/flatpak.txt`
3. **`run_onchange_after_10-install-toolchains.sh.tmpl`** runs:
   - Installs `rustup`, `uv`, `bun`, `zed`, and `ghcup` if missing
   - Installs tools from `toolchains/uv.txt`, `toolchains/cargo.txt`, `toolchains/bun.txt`, and `toolchains/go.txt`
4. **`run_onchange_after_20-setup-system.sh.tmpl`** runs:
   - Installs/configures `keyd`
   - Enables UFW, fstrim, paccache timers
   - Sets up PostgreSQL and Clash Verge service if present

> **Note:** The first run can take a long time. AUR builds, Flatpak downloads, and toolchain bootstrapping all happen sequentially. Keep the machine plugged in and online.

### Post-Install Checks

After the initial apply completes:

```bash
# Reboot into COSMIC desktop
sudo reboot

# Verify keyd is running
sudo systemctl status keyd
sudo keyd list

# Verify toolchains
rustup show
uv --version
bun --version
go version
ghc --version

# Verify PATH includes toolchain bins
printf '%s\n' $PATH

# Check chezmoi status
chezmoi status
```

---

## Daily Workflow & Maintenance Cheat Sheet

### Fish Abbreviations

Defined in `~/.config/fish/config.fish`:

| Abbreviation | Expands To | Purpose |
|---|---|---|
| `hx` | `helix` | Launch Helix editor |
| `cm` | `chezmoi cd` | Jump to the chezmoi source directory |
| `cma` | `chezmoi apply` | Apply chezmoi-managed changes to the live system |
| `cms` | `chezmoi status` | Show pending changes |

### Editing Files

#### Flow A — Edit via chezmoi source directory

```bash
cm                         # cd into ~/.local/share/chezmoi
# edit files with your editor, e.g.:
hx dot_config/fish/config.fish
cma                        # apply changes
```

This is the safest flow because chezmoi always knows about the changes.

#### Flow B — Edit directly on disk

```bash
hx ~/.config/fish/config.fish    # edit live file
chezmoi re-add ~/.config/fish/config.fish
cma
```

> **⚠️ Warning:** If you edit a file directly on disk and then run `cma` (`chezmoi apply`) **without** `chezmoi re-add`, chezmoi will overwrite your live changes with the version in its source tree. Always `re-add` before applying when editing live files.

### Adding New Software

#### System / AUR Package

1. Edit the appropriate modular manifest under `packages/`:
   - `packages/00-system-base.txt` — core system, drivers, networking
   - `packages/10-desktop-environment.txt` — desktop, fonts, GUI apps
   - `packages/20-dev-stacks.txt` — compilers, runtimes, dev tools
   - `packages/30-terminal-utilities.txt` — terminal, editors, CLI utilities
2. Run `cma`.
3. The `run_onchange_after_00-install-packages.sh.tmpl` hook detects the changed checksum and installs the new package.

#### Language CLI Tool

1. Edit the appropriate toolchain manifest:
   - `toolchains/uv.txt` for Python tools
   - `toolchains/cargo.txt` for Rust crates
   - `toolchains/bun.txt` for JS/TS tools
   - `toolchains/go.txt` for Go modules
2. Run `cma`.
3. The `run_onchange_after_10-install-toolchains.sh.tmpl` hook installs the new tool.

### Updating Standalone Toolchains

```bash
# Rust
rustup update
cargo install-update -a

# Python / uv
uv self update
uv tool upgrade --all

# Bun
bun upgrade
cd ~/.bun/install/global && bun update --latest && cd ~

# Go
gup update

# Haskell
ghcup upgrade
ghcup install ghc recommended
ghcup install cabal recommended
```

There is also a custom Fish function `aup` (defined in `dot_config/fish/functions/aup.fish`) that runs all of the above in one shot.

### Modifying Root Settings

For `keyd` or other root-level config:

```bash
cm
hx system/keyd/default.conf
cma
```

The `run_onchange_after_20-setup-system.sh.tmpl` hook will copy the file to `/etc/keyd/default.conf` and reload the service.

---

## Agentic System Management (Goose / AI Agents)

This workstation is maintained with the help of AI agents (e.g. [Goose](https://github.com/block/goose)) working directly in the chezmoi source directory. Agents assist with drift audits, config edits, package/toolchain manifest maintenance, and hook updates — always under strict operating rules.

**The binding contract for all agents is [`AGENTS.md`](AGENTS.md).** Point any agent at it before letting it touch this repository or the live system — it defines the architecture rules, operating protocols, and hard prohibitions every agent must follow.

### Safe Instruction Patterns

**Audit (read-only):**

> "Run `chezmoi status` and `chezmoi diff`, report any drift between the source tree and the live system. Change nothing."

**Update packages:**

> "Update the system, then reconcile newly installed/removed packages with the manifests under `packages/` and `archive/pacman-foreign.txt`. Follow `AGENTS.md` and ask before removing anything."

**Add a toolchain:**

> "Install `<tool>` with the appropriate toolchain manager (uv/cargo/bun/go), append it to the matching `toolchains/*.txt` manifest, and verify with `chezmoi status`. Follow `AGENTS.md`."

**Refine & Reconcile System (periodic maintenance):**

> "Run a complete dotfiles refinement audit per AGENTS.md §2.5. Reconcile pacman, AUR, Flatpak, and standalone toolchains with the manifests, scan for drift and portability issues, and report findings before modifying any files."

Rule of thumb: agents may read freely, must document every install in a manifest, and must ask before anything destructive.

---

## Repository Structure

```text
~/.local/share/chezmoi
├── .chezmoiignore                         # keeps repo-meta files out of $HOME
├── AGENTS.md                              # operational rules for AI agents
├── README.md                              # this file
├── archive/
│   ├── pacman-foreign.txt                 # legacy AUR package dump
│   └── pacman-native.txt                  # legacy native package dump
├── dot_config/
│   ├── alacritty/                         # Alacritty terminal config
│   ├── fish/
│   │   ├── completions/bun.fish           # Bun completions
│   │   ├── conf.d/
│   │   │   ├── rustup.fish                # Rustup env setup
│   │   ├── config.fish                    # Fish shell config
│   │   └── functions/aup.fish             # All-update function
│   ├── helix/                             # Helix editor config
│   ├── kitty/                             # Kitty terminal config
│   ├── private_fcitx5/                    # Fcitx5 input method (Mozc/Rime) config
│   ├── starship.toml                      # Starship prompt config
│   └── zed/                               # Zed editor config
├── dot_gitconfig                          # Git user config
├── packages/
│   ├── 00-system-base.txt                 # core system packages
│   ├── 10-desktop-environment.txt         # COSMIC / GUI / fonts
│   ├── 20-dev-stacks.txt                  # compilers / runtimes / LSPs
│   ├── 30-terminal-utilities.txt          # terminals / editors / CLI tools
│   ├── flatpak.txt                        # Flatpak applications
│   └── manifest.md                        # package manifest documentation
├── private_dot_ssh/
│   ├── .gitignore                         # ignores private keys
│   └── config                             # SSH client config
├── run_onchange_after_00-install-packages.sh.tmpl
├── run_onchange_after_10-install-toolchains.sh.tmpl
├── run_onchange_after_20-setup-system.sh.tmpl
├── system/
│   └── keyd/
│       └── default.conf                   # keyd keyboard remapping
└── toolchains/
    ├── bun.txt                            # Bun global packages
    ├── cargo.txt                          # cargo-installed crates
    ├── go.txt                             # Go modules
    ├── local-bin.txt                      # manual ~/.local/bin binaries
    └── uv.txt                             # uv-managed Python tools
```

---

## Safety & Troubleshooting

### The `chezmoi diff` Gotcha

`chezmoi diff` compares the **source tree** to the **live files on disk**. It does **not** show changes you made inside the source tree that have not yet been applied.

Common mistake:

```bash
cm
hx dot_config/fish/config.fish
chezmoi diff    # shows diff between source and disk — may look empty/odd
cma             # applies the source to disk
```

Use `chezmoi status` and `chezmoi diff` together, and remember that the source of truth is `~/.local/share/chezmoi`.

If you edited a live file and want to keep it:

```bash
chezmoi re-add ~/.config/fish/config.fish
```

### Testing Templates Before Push

All `run_onchange_*.sh.tmpl` files use Go templates for checksums. Test them before committing:

```bash
cd ~/.local/share/chezmoi

chezmoi execute-template < run_onchange_after_00-install-packages.sh.tmpl | bash -n
chezmoi execute-template < run_onchange_after_10-install-toolchains.sh.tmpl | bash -n
chezmoi execute-template < run_onchange_after_20-setup-system.sh.tmpl | bash -n
```

If any fail, the rendered script has a syntax or template error.

### Re-Running a Single Hook

Because hooks are `run_onchange_`, they only execute when their rendered content changes. To force a hook manually:

```bash
# Render and execute a hook directly
chezmoi execute-template < run_onchange_after_20-setup-system.sh.tmpl | bash
```

Or temporarily rename the file to `run_once_after_...`, apply, then rename it back.

### Recovering From a Bad Apply

If a hook fails partway through:

1. Fix the manifest/template that caused the failure.
2. Re-run `cma`.
3. If needed, run the rendered hook manually with `bash` to see the exact error.

### Private Keys

This repository intentionally does **not** track SSH private keys. If `git status` ever shows an untracked key in `private_dot_ssh/`, do not stage it. The directory is protected by `private_dot_ssh/.gitignore`.

---

## License

Personal dotfiles. Use at your own risk.
