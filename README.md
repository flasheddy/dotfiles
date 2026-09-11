# CachyOS Dotfiles

A declarative, reproducible CachyOS workstation managed with [chezmoi](https://www.chezmoi.io/): system packages, COSMIC desktop applications, developer toolchains, shell/editor configuration, and root-level system services.

---

## System & Dotfiles Architecture

### High-Level Overview

| Layer | Technology |
|---|---|
| **OS / Desktop** | CachyOS (Arch-based) + COSMIC desktop environment |
| **Shell** | Fish (CachyOS defaults overridden by custom config) |
| **Editors** | Helix (primary), Zed, nano |
| **Document Readers** | glow (Markdown), jless (JSON), csvlens (TSV / Anki datasets) |
| **Prompt** | Starship |
| **Terminals** | Alacritty, Kitty |
| **Theme** | Catppuccin Mocha (shell, Helix, Starship, cursors, Zed, glow) |
| **Input** | keyd (Caps Lock overload), fcitx5 (Mozc/Rime) |
| **Package Management** | Pacman + AUR helpers (`paru`/`yay`) |
| **Dev Toolchains** | Standalone upstream installers: `rustup`, `uv`, `bun`, `ghcup`, `go` |

### Shell / Environment

Fish is the authoritative primary shell for this workstation. Direct shell
commands and agent tool snippets use native Fish syntax. The Fish configuration
permanently exports `GOOSE_SHELL=/usr/bin/fish` with `set -gx`, so agent tools
use Fish as the workstation shell dialect.

### Decoupling Strategy: System Packages vs. Developer Toolchains

System software comes from the CachyOS/Arch repositories and the AUR via the modular manifests in `packages/`. Language tooling is kept **out of Pacman** and installed via official upstream installers — no version conflicts with distro packages, and each toolchain self-updates on its own schedule:

| Toolchain | Manager | Manifest | Install Location |
|---|---|---|---|
| Rust | `rustup` + `cargo` | `toolchains/cargo.txt` | `~/.cargo/bin` |
| Python CLI tools | `uv` | `toolchains/uv.txt` | `~/.local/bin` |
| JS/TS tools | `bun` | `toolchains/bun.txt` | `~/.bun/bin` |
| Go tools | `go install` | `toolchains/go.txt` | `~/go/bin` |
| Haskell | `ghcup` | managed by GHCup | `~/.ghcup/bin`, `~/.cabal/bin` |
| Manual binaries | — | `toolchains/local-bin.txt` | `~/.local/bin` |

### Automated Lifecycle Hooks

Three `run_onchange_after_*.sh.tmpl` hooks re-run whenever their rendered content changes:

1. **`00-install-packages`** — installs/updates native Pacman packages, AUR packages (`paru`/`yay`), and Flatpaks from the manifests.
2. **`10-install-toolchains`** — bootstraps `rustup`, `uv`, `bun`, `zed`, `ghcup` if missing, then restores sub-tools from `toolchains/*.txt`.
3. **`20-setup-system`** — root-level services: deploys `system/keyd/default.conf` → `/etc/keyd/default.conf` and reloads `keyd`; sets UFW defaults (deny incoming, allow outgoing, enable); enables `fstrim.timer` and `paccache.timer`; enables `clash-verge-service` and initializes/starts `postgresql` if installed. Also ensures the user-level symlink `~/AGENTS.md` → `~/.AGENTS.md` exists (no sudo).

### Key Remapping

`system/keyd/default.conf` makes **Caps Lock** dual-function — tap → `Esc`, hold → `Control`:

```ini
[ids]
*

[main]
capslock = overload(control, esc)
```

---

## Fresh Machine Bootstrap

### Prerequisites

1. Install CachyOS with a working internet connection (`git` and `chezmoi` ship by default).
2. Have your SSH private key ready, or generate a new one.

### SSH Key Restoration

Only `private_dot_ssh/config` is tracked; private keys are excluded by `.gitignore` and must be restored separately.

**Option A — copy from backup:**

```fish
mkdir -p ~/.ssh; and chmod 700 ~/.ssh
cp /path/to/backup/id_ed25519 ~/.ssh/
cp /path/to/backup/id_ed25519.pub ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

**Option B — generate a new key** (then add the public key to GitHub/GitLab/servers):

```fish
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519
```

### Master Bootstrap Command

```fish
chezmoi init --apply https://github.com/flasheddy/dotfiles.git   # replace with your repo URL
```

This copies all dotfiles to `~/.config/`, `~/.ssh/config`, `~/.gitconfig`, etc., then runs the three lifecycle hooks described above in order: packages → toolchains → system services.

> **Note:** The first run can take a long time — AUR builds, Flatpak downloads, and toolchain bootstrapping all happen sequentially. Keep the machine plugged in and online.

### Post-Install Checks

```fish
sudo reboot                              # reboot into COSMIC
sudo systemctl status keyd               # verify keyd
sudo keyd list
rustup show; uv --version; bun --version; go version; ghc --version
printf '%s\n' $PATH                      # toolchain bins on PATH
chezmoi status                           # no unexpected drift
```

---

## Daily Workflow & Maintenance Cheat Sheet

### Fish Abbreviations

Defined in `~/.config/fish/config.fish`:

| Abbreviation | Expands To | Purpose |
|---|---|---|
| `cm` | `cd ~/.local/share/chezmoi` | jump to the chezmoi source directory (native `cd` — no wrapper process) |
| `cma` | `chezmoi apply` | apply source changes to the live system |
| `cms` | `chezmoi status` | show pending changes |
| `gm` | `glow` | read-only Markdown reader (see Terminal Document Readers) |
| `jl` | `jless` | read-only JSON pager with tree folding & vi keybindings |
| `tsv` | `csvlens -t` | read-only column-aligned TSV/dataset viewer |

### Terminal Document Readers

Document review is separated from editing: **read-only CLI viewers**
(`gm`/`jl`/`tsv`) inspect files without ever opening a modifiable buffer, while
Helix (`hx`) is reserved for intentional edits. This eliminates accidental
buffer modifications when reviewing large documents.

| Reader | File Types | Abbreviation | Highlights |
|---|---|---|---|
| `glow` | Markdown | `gm` | Catppuccin Mocha theme (Mauve accent), 120-column wrap, auto-paging for long documents |
| `jless` | JSON | `jl` | interactive pager with tree folding and Helix/vi keybindings |
| `csvlens -t` | TSV, Anki exports & datasets | `tsv` | column-aligned viewer (`-t` = tab-separated, shortcut for `-d '\t'`) |

All three are native packages from the Zen 4–optimized `cachyos-extra-znver4`
repository, installed via the `# Readers` group in
`packages/30-terminal-utilities.txt`. The glow theme source lives in
`dot_config/glow/` (→ `~/.config/glow/catppuccin-mocha.json`). Reader
abbreviations are defined only for interactive shells; agent and other
non-interactive shells force non-interactive output per `~/.AGENTS.md`.

### PATH Symlinks

Managed via `dot_local/bin/symlink_*` (tracked in `toolchains/local-bin.txt`): `hx` → `/usr/bin/helix`.

### Editing Files

**Flow A — via the source directory (safest; chezmoi always knows about the changes):**

```fish
cm
hx dot_config/fish/config.fish
cma
```

**Flow B — edit the live file directly:**

```fish
hx ~/.config/fish/config.fish
chezmoi re-add ~/.config/fish/config.fish   # mandatory before applying
cma
```

> **⚠️ Warning:** `cma` without `chezmoi re-add` overwrites your live edits with the source-tree version. Always `re-add` first when editing live files.

### Adding New Software

**System / AUR package:** append to the manifest matching its origin, then `cma` — hook 00 detects the changed checksum and installs it (native via `pacman`, AUR via `paru`/`yay`).

- **Native** (official CachyOS/Arch repos) → `packages/00-system-base.txt` (core/drivers/networking), `10-desktop-environment.txt` (desktop/fonts/GUI), `20-dev-stacks.txt` (compilers/runtimes/dev tools), or `30-terminal-utilities.txt` (terminals/editors/CLI).
- **AUR-only** → `archive/pacman-foreign.txt`. **Never** add AUR names to `packages/*.txt`: they feed `pacman -S` directly, and an unknown name aborts the whole run (AGENTS.md §1.3). Verify origin: `pacman -Si <pkg>` (native) vs `paru -Si <pkg>` (AUR).

**Language CLI tool:** append to `toolchains/uv.txt` (Python), `cargo.txt` (Rust), `bun.txt` (JS/TS), or `go.txt` (Go), then `cma` — hook 10 installs it.

### Updating Standalone Toolchains

The primary update workflow is the `aup` Fish function (`dot_config/fish/functions/aup.fish`): per-stage isolation (one failure never aborts the rest), missing tools reported as `SKIP (not installed)`, a 2-hour per-stage success cache in `~/.cache/aup/` (user-local, unmanaged; `--force` bypasses), and an OK/SKIP/FAIL summary. Exits 1 if any stage failed.

| Stage | Command | Notes |
|---|---|---|
| **system** | `cachy-update` | pacman + AUR via arch-update (prompts for sudo) |
| **rustup** | `rustup update` | Rust toolchain manager |
| **cargo** | `cargo install-update -a` | all cargo-installed crates |
| **uv-self** | `uv self update` | uv itself |
| **uv-tools** | `uv tool upgrade --all` | all uv-managed Python tools |
| **bun-self** | `bun upgrade` | bun itself |
| **bun-globals** | `bun update --global --latest` | global npm packages, no `cd` needed |
| **go** | `gup update` | all `go install`ed binaries |
| **ghcup** | `ghcup upgrade` | ghcup itself (GHC/cabal via `ghcup install`) |
| **tldr** | `tldr --update` | tldr page cache |

| Flag | Effect |
|---|---|
| *(none)* | run the system stage and all toolchain stages |
| `-t`, `--toolchains` (alias `--no-sys`) | skip the system stage — retry toolchains only |
| `-s`, `--sys-only` | run only the system stage |
| `-f`, `--force` | ignore the success cache and re-run every stage |
| `-h`, `--help` | show usage |

Manual per-manager equivalents (debugging fallback, or single-manager updates): `rustup update` + `cargo install-update -a` · `uv self update` + `uv tool upgrade --all` · `bun upgrade` + `bun update --global --latest` · `gup update` · `ghcup upgrade` + `ghcup install ghc recommended` + `ghcup install cabal recommended` · `tldr --update`.

### Modifying Root Settings

```fish
cm
hx system/keyd/default.conf
cma    # hook 20 deploys to /etc/keyd/default.conf and reloads the service
```

---

## Agentic System Management (Goose / AI Agents)

This workstation is maintained with AI agents (e.g. [Goose](https://github.com/block/goose)) working directly in the chezmoi source directory: drift audits, config edits, package/toolchain manifest maintenance, hook updates — always under strict operating rules.

**The binding contract for all agents is [`AGENTS.md`](AGENTS.md).** Point any agent at it before letting it touch this repository or the live system.

> **Context-loading note:** agents that support context files (goose: `AGENTS.md`/`.goosehints`) auto-load them from the working directory up to the repo root into every session — this repo's `AGENTS.md` qualifies. Rules living *above* the repo root are covered too: global inlining via `~/.config/goose/.goosehints` is active and managed by chezmoi (`dot_config/goose/dot_goosehints.tmpl` renders `dot_AGENTS.md` inline into every goose session), and hook 20 keeps `~/AGENTS.md` symlinked to `~/.AGENTS.md` for tools that read the home path directly.

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

### Adopting This Workflow for Your Machine

1. **Fork** this repository, then `chezmoi init <your-fork-url>` (clones into `~/.local/share/chezmoi`). Do **not** apply yet — the manifests describe the original machine, not yours.
2. **Reconcile with a single agent prompt:**

   > "I forked this dotfiles repository. Run a package and manifest reconciliation per AGENTS.md §2.5 Phase 2: compare my installed pacman, AUR, and Flatpak packages and my standalone toolchains against the manifests under `packages/`, `archive/`, and `toolchains/`. Report what to add or remove so the manifests describe THIS machine. Follow AGENTS.md and stop before modifying any files."

3. **Review, then apply.** The agent reports Critical / Missing / Polish findings and waits for approval (AGENTS.md §2.5 Phase 4). Approve the manifest edits, then `chezmoi apply` — the `run_onchange` hooks install everything declaratively.

Before committing to your fork, personalize the machine-specific parts: replace the hosts in `private_dot_ssh/config` (never commit key material — AGENTS.md §3), review `system/keyd/default.conf` against your keyboard, and trim fish abbreviations or environment variables you don't want.

---

## Repository Structure

```text
~/.local/share/chezmoi
├── .chezmoiignore                         # keeps repo-meta files (AGENTS.md, README.md) out of $HOME
├── AGENTS.md                              # binding operational rules for AI agents
├── README.md                              # this file
├── archive/
│   ├── pacman-foreign.txt                 # AUR package manifest (paru/yay)
│   └── pacman-native.txt                  # legacy native package dump
├── dot_AGENTS.md                          # global agent rules & safety floor → ~/.AGENTS.md
├── dot_config/
│   ├── alacritty/                         # Alacritty terminal config
│   ├── fish/                              # config.fish, completions/bun.fish, conf.d/rustup.fish, functions/aup.fish
│   ├── goose/                             # Goose agent config (config.yaml, dot_goosehints.tmpl → .goosehints)
│   ├── glow/                              # glow Markdown reader config + Catppuccin Mocha theme
│   ├── helix/                             # Helix editor config
│   ├── kitty/                             # Kitty terminal config
│   ├── private_fcitx5/                    # fcitx5 input method (Mozc/Rime) config
│   ├── starship.toml                      # Starship prompt config
│   └── zed/                               # Zed editor config
├── dot_gitconfig                          # Git user config
├── dot_local/bin/symlink_hx               # hx → /usr/bin/helix symlink
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
├── system/keyd/default.conf               # keyd keyboard remapping
└── toolchains/                            # bun / cargo / go / local-bin / uv manifests
```

---

## Security & Threat Model

Four boundaries keep routine automation — human or AI — from becoming system compromise:

1. **Isolated blast radius.** Standalone toolchains (`~/.cargo`, `~/.local/bin`, `~/.bun`, `~/go`) live entirely in user space and never touch Pacman or `/etc`: a broken or malicious user-level tool cannot corrupt the system package layer, and a system update cannot silently replace a pinned toolchain.
2. **Controlled privilege escalation.** Repository-managed root mutations exist in exactly one place: the tracked, checksummed `run_onchange_*.sh.tmpl` hooks (and the tracked `system/keyd/default.conf` they deploy) — idempotent, graceful, re-run only on content change. No ad-hoc sudo one-liners; any change to a sudo-invoking template must declare a `[ROOT IMPACT]` tag (AGENTS.md §2.7).
3. **Zero-secret baseline.** No private keys, tokens, or credentials are tracked — ever. Only `private_dot_ssh/config` is managed; `private_dot_ssh/.gitignore` excludes key material, and hooks never print secrets. Untrusted external code is never executed or ingested into tracked state (AGENTS.md §3).
4. **Human-gated AI mutations.** Agents operate under [`AGENTS.md`](AGENTS.md): they read freely, but every state change passes the §2.7 review protocol (ground-truth probes → constraint audit → refined prompt → explicit approval), destructive operations always require confirmation, and forbidden actions stop the task rather than being refined around.

---

## Safety & Troubleshooting

### Understanding `chezmoi diff`

`chezmoi diff` compares generated target state with live destination files, so
it includes source changes that have not yet been applied when they affect
managed targets. Use it with `chezmoi status`; the source of truth remains
`~/.local/share/chezmoi`. If you edited a live file and want to keep it, run
`chezmoi re-add <file>` before applying.

### Testing Templates Before Push

All `run_onchange_*.sh.tmpl` files use Go templates for checksums. Render-test
before committing; `bash -n` intentionally invokes the rendered hooks' declared
shell for syntax validation:

```fish
cd ~/.local/share/chezmoi
for f in run_onchange_*.sh.tmpl
    chezmoi execute-template < "$f" | bash -n
    or echo "FAIL: $f"
end
```

### Re-Running a Single Hook

`run_onchange_` hooks only execute when their rendered content changes. To force one manually:

```fish
chezmoi execute-template < run_onchange_after_20-setup-system.sh.tmpl | bash
```

Or temporarily rename the file to `run_once_after_...`, apply, then rename it back.

### Recovering From a Bad Apply

1. Fix the manifest/template that caused the failure.
2. Re-run `cma`.
3. If needed, run the rendered hook manually with `bash` to see the exact error.

### Private Keys

This repository intentionally does **not** track SSH private keys. If `git status` ever shows an untracked key in `private_dot_ssh/`, do not stage it — the directory is protected by `private_dot_ssh/.gitignore`.

---

## License

Personal dotfiles. Use at your own risk.
