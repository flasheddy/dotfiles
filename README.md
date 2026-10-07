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

Defined in `~/.config/fish/config.fish`:

| Abbreviation | Expands To | Purpose |
|---|---|---|
| `cm` | `cd ~/.local/share/chezmoi` | jump to the chezmoi source directory (native `cd` — no wrapper process) |
| `cma` | `chezmoi apply` | apply source changes to the live system |
| `cms` | `chezmoi status` | show pending changes |
| `jl` | `jless` | read-only JSON pager with tree folding & vi keybindings |
| `tsv` | `csvlens -t` | read-only column-aligned TSV/dataset viewer |

### Terminal Document Readers

Document review is separated from editing: **read-only CLI viewers**
(`jl`/`tsv`) inspect files without ever opening a modifiable buffer, while
Helix (`hx`) is reserved for intentional edits. This eliminates accidental
buffer modifications when reviewing large documents.

| Reader | File Types | Abbreviation | Highlights |
|---|---|---|---|
| `jless` | JSON | `jl` | interactive pager with tree folding and Helix/vi keybindings |
| `csvlens -t` | TSV, Anki exports & datasets | `tsv` | column-aligned viewer (`-t` = tab-separated, shortcut for `-d '\t'`) |

Both are native packages from the Zen 4–optimized `cachyos-extra-znver4`
repository, installed via the `# Readers` group in
`packages/30-terminal-utilities.txt`. Reader abbreviations are defined only for
interactive shells; agent and other non-interactive shells force
non-interactive output per `~/.AGENTS.md`.

### Agent Turn Checkpoint Handoff

`handoff-copy` (Fish function → `~/.config/fish/functions/handoff-copy.fish`)
snapshots the latest Goose session for a turn handoff: it streams the latest
assistant text block, session ID, git context (branch, commit, working-tree
status), and plan path into a Markdown buffer, then copies it to the Wayland
clipboard via `wl-copy` for pasting into Gemini Chat.

`handoff-extract` (companion → `~/.config/fish/functions/handoff-extract.fish`)
reads that same handoff and lifts only the fenced `fish` code block out of
it. It is scoped strictly to the **newest** session and to the **last** fence
inside it, so a block belonging to an earlier handoff is never reused. The block
is printed to stdout and copied to the clipboard (`-n`/`--no-copy` prints only);
`-s`/`--session <id>` targets an explicit session. When no handoff, no assistant
text, or no fish block is available, nothing is copied and a reminder is printed
to stderr with exit status 1.

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

The primary update workflow is the `aup` Fish function (`dot_config/fish/functions/aup.fish`): per-stage isolation (one failure never aborts the rest), missing tools reported as `SKIP (not installed)`, a 2-hour per-stage success cache in `~/.cache/aup/` (user-local, unmanaged; `--force` bypasses), and an OK/SKIP/FAIL summary. Exits 1 if any stage failed. The **goose** stage additionally HEAD-probes the upstream `stable` release asset and skips the re-download while its ETag/Last-Modified fingerprint is unchanged (`~/.cache/aup/goose.asset`).

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
| **tldr** | `tldr --update` | tldr page cache |
| **goose** | `goose update` | goose CLI self-update (stable channel); skipped while the upstream `stable` asset is unchanged (HEAD probe, no download) |

| Flag | Effect |
|---|---|
| *(none)* | run the system stage and all toolchain stages |
| `-t`, `--toolchains` (alias `--no-sys`) | skip the system stage — retry toolchains only |
| `-s`, `--sys-only` | run only the system stage |
| `-f`, `--force` | ignore the success cache and re-run every stage |
| `-h`, `--help` | show usage |

Manual per-manager equivalents (debugging fallback, or single-manager updates): `rustup update` + `cargo install-update -a` · `uv self update` + `uv tool upgrade --all` · `bun upgrade` + `bun update --global --latest` · `gup update` · `tldr --update` · `goose update`.

### Modifying Root Settings

```fish
cm
hx system/keyd/default.conf
cma    # hook 20 deploys to /etc/keyd/default.conf and restarts keyd.service
```

---

## Agentic System Management (Goose / AI Agents)

This workstation is maintained with AI agents (e.g. [Goose](https://github.com/aaif-goose/goose)) working directly in the chezmoi source directory: drift audits, config edits, package/toolchain manifest maintenance, hook updates — always under strict operating rules.

**The binding contract for all agents is [`AGENTS.md`](AGENTS.md).** Point any agent at it before letting it touch this repository or the live system. It carries the chezmoi execution model (§1–§2), the repository enforcement and verification gates (§1.4), the goose configuration map (§1.5), the refinement/maintenance protocol and operator prompts (§2.5), and the offline goose-docs root (§2.11).

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
