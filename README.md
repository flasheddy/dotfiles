# CachyOS Dotfiles

A declarative, reproducible CachyOS workstation managed with [chezmoi](https://www.chezmoi.io/): system packages, COSMIC desktop applications, developer toolchains, shell/editor configuration, and root-level system services.

> Architecture, enforcement, agentic-system, and security documentation lives in
> **[`AGENTS.md`](AGENTS.md)** (the binding agent contract) and in the long-form
> posts on [Dev Journal Blogs](https://hech.dev/blog/).

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

This copies all dotfiles to `~/.config/`, `~/.ssh/config`, `~/.gitconfig`, etc., then runs the repository's `run_onchange` lifecycle hooks in order: packages → toolchains → system services.

> **Note:** The first run can take a long time — AUR builds, Flatpak downloads, and toolchain bootstrapping all happen sequentially. Keep the machine plugged in and online.

### Post-Install Checks

```fish
sudo reboot                              # reboot into COSMIC
sudo systemctl status keyd               # verify keyd
sudo keyd list-keys
rustup show; uv --version; bun --version; go version
printf '%s\n' $PATH                      # toolchain bins on PATH
chezmoi status                           # no unexpected drift
```

---

## Daily Workflow & Maintenance Cheat Sheet

### Fish Abbreviations

```fish
abbr --show # Show all abbreviations in the terminal
```

### Dictation

Add `dictate toggle` on `Super+Alt+D` in COSMIC Settings.

### PATH Symlinks

Managed via `dot_local/bin/symlink_*` (tracked in `toolchains/local-bin.txt`): `hx` → `/usr/bin/helix`.

### Editing Files

**Flow A — via the source directory (safest; chezmoi always knows about the changes):**

```fish
cd ~/.local/share/chezmoi
hx dot_config/fish/config.fish
chezmoi apply
```

**Flow B — edit the live file directly:**

```fish
hx ~/.config/fish/config.fish
chezmoi re-add ~/.config/fish/config.fish
chezmoi apply
```

### Adding New Software

**System / AUR package:** append to the manifest matching its origin, then `chezmoi apply` — hook 00 detects the changed checksum and installs it (native via `pacman`, AUR via `paru`/`yay`).

- **Native** (official CachyOS/Arch repos) → `packages/00-system-base.txt` (core/drivers/networking), `10-desktop-environment.txt` (desktop/fonts/GUI), `20-dev-stacks.txt` (compilers/runtimes/dev tools), or `30-terminal-utilities.txt` (terminals/editors/CLI).
- **AUR-only** → `archive/pacman-foreign.txt`. **Never** add AUR names to `packages/*.txt`: they feed `pacman -S` directly, and an unknown name aborts the whole run ([AGENTS.md §1.2](AGENTS.md)). Verify origin: `pacman -Si <pkg>` (native) vs `paru -Si <pkg>` (AUR).

**Language CLI tool:** append to `toolchains/uv.txt` (Python), `cargo.txt` (Rust), `bun.txt` (JS/TS), or `go.txt` (Go), then `chezmoi apply` — hook 10 installs it.

### Updating Standalone Toolchains

```fish
aup --help # for more info
aup # update toolchains before system packages
```

### Modifying Root Settings

```fish
cd ~/.local/share/chezmoi
hx system/keyd/default.conf
chezmoi apply # restart keyd.service
```

---

## Agentic System Management (AI Agents)

This workstation is maintained with AI agents (Antigravity CLI, OpenCode) working directly in the chezmoi source directory: drift audits, config edits, package/toolchain manifest maintenance, hook updates — always under strict operating rules.

**The binding contract for all agents is [`AGENTS.md`](AGENTS.md).** Point any agent at it before letting it touch this repository or the live system. It carries the chezmoi execution model (§1–§2), the repository enforcement and verification gates ([§1.3](AGENTS.md)), the refinement and maintenance protocol ([§2.3](AGENTS.md)), and the operator git workflow ([§2.4](AGENTS.md)).

---

## Safety & Troubleshooting

### Understanding `chezmoi diff`

`chezmoi diff` compares generated target state with live destination files, so
it includes source changes that have not yet been applied when they affect
managed targets. Use it with `chezmoi status`; the source of truth remains
`~/.local/share/chezmoi`. If you edited a live file and want to keep it, run
`chezmoi re-add <file>` before applying.

### Testing Templates & Linters Before Push

All `run_onchange_*.sh.tmpl` files use Go templates for checksums. Validate templates and all configs with the repository linter before pushing:

```fish
just lint    # checks hook templates, git hooks, fish syntax, TOML, typos, and whitespace
just check   # full pre-push verification gate (hygiene, lint, secrets, drift)
```

### Re-Running a Single Hook

`run_onchange_` hooks only execute when their rendered content changes. To force one manually:

```fish
chezmoi execute-template < run_onchange_after_20-setup-system.sh.tmpl | bash
```

Or temporarily rename the file to `run_once_after_...`, apply, then rename it back.

### Recovering From a Bad Apply

1. Fix the manifest/template that caused the failure.
2. Re-run `chezmoi apply`.
3. If needed, run the rendered hook manually with `bash` to see the exact error.

### Private Keys

This repository intentionally does **not** track SSH private keys. If `git status` ever shows an untracked key in `private_dot_ssh/`, do not stage it — the directory is protected by `private_dot_ssh/.gitignore`.

---

## License

Personal dotfiles. Use at your own risk.
