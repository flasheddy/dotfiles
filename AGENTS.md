# AGENTS.md — Operational Rules for AI Agents

This file is the binding contract for Goose and any AI agent operating on this
chezmoi repository. **Read it fully before changing anything.** If a requested
action conflicts with these rules, stop and ask the user.

---

## 1. Repository Context & Architecture

### 1.1 Source State vs. Live Disk

This repository is the **chezmoi source state**, located at:

```text
~/.local/share/chezmoi
```

It is *not* the live system. chezmoi maps source files to targets on disk:

| Source path | Live target |
|---|---|
| `dot_config/...` | `~/.config/...` |
| `dot_gitconfig` | `~/.gitconfig` |
| `private_dot_ssh/config` | `~/.ssh/config` |
| `system/keyd/default.conf` | `/etc/keyd/default.conf` (deployed by hook) |
| `packages/*.txt`, `toolchains/*.txt` | consumed by `run_onchange_*` hooks |

Fundamental implications:

- **The source tree is the single source of truth.** Never treat a live file
  on disk as authoritative.
- Edits inside the source tree do nothing until `chezmoi apply` runs.
- Edits to live files are **silently overwritten** by the next
  `chezmoi apply` unless they are first pulled into the source with
  `chezmoi re-add`.

### 1.2 Decoupling Principle: System Packages vs. Developer Toolchains

Two deliberately decoupled installation layers exist. Respect the boundary.

**Layer 1 — System packages (`packages/`)**, installed via Pacman/AUR/Flatpak:

| Manifest | Contents |
|---|---|
| `packages/00-system-base.txt` | Core system, drivers, networking |
| `packages/10-desktop-environment.txt` | COSMIC desktop, fonts, GUI apps |
| `packages/20-dev-stacks.txt` | Compilers, distro runtimes, LSPs |
| `packages/30-terminal-utilities.txt` | Terminals, editors, CLI tools |
| `packages/flatpak.txt` | Flatpak applications |
| `archive/pacman-foreign.txt` | **AUR packages only** (via `paru`/`yay`) |

**Layer 2 — Standalone developer toolchains (`toolchains/`)**, installed via
official upstream installers, kept **out of Pacman** to avoid version
conflicts:

| Manifest | Manager | Install location |
|---|---|---|
| `toolchains/cargo.txt` | `rustup` + `cargo install` | `~/.cargo/bin` |
| `toolchains/uv.txt` | `uv tool install` | `~/.local/bin` |
| `toolchains/bun.txt` | `bun install -g` | `~/.bun/bin` |
| `toolchains/go.txt` | `go install` | `~/go/bin` |
| `toolchains/local-bin.txt` | manual binaries | `~/.local/bin` |
| — (self-managed) | `ghcup` | `~/.ghcup/bin` |

### 1.3 Hard Rule: Never Mix AUR into Native Manifests

- `packages/00-*.txt` through `packages/30-*.txt` must contain **only**
  packages from the official CachyOS/Arch repositories. They are fed directly
  to `pacman -S`, and an AUR-only name will abort the whole install run.
- AUR packages go **only** into `archive/pacman-foreign.txt` (installed with
  `paru` or `yay`).
- Unsure whether a package is native or AUR? Verify before writing:
  `pacman -Si <pkg>` succeeds for native packages; `paru -Si <pkg>` reveals
  AUR origin.

---

## 2. Operating Protocols

### 2.1 Read State Before Acting

Before modifying **any** file, establish ground truth:

```bash
chezmoi status    # pending source-vs-target differences
chezmoi diff      # exact content that an apply would change
```

- Report unexpected drift to the user instead of "fixing" it silently.
- Remember the gotcha: `chezmoi diff` compares source → disk. It does **not**
  show unapplied edits you just made inside the source tree.

### 2.2 Editing Workflow

**Flow A — Editing live files on disk** (e.g. `~/.config/fish/config.fish`):

1. Edit the live file.
2. **MUST** run `chezmoi re-add <file>` to pull the change into the source —
   applying without `re-add` destroys the live change (§1.1).
3. Then run `chezmoi apply` (or verify with `chezmoi diff` first).

**Flow B — Editing the source tree directly** (preferred):

1. Edit files under `~/.local/share/chezmoi`.
2. If you touched any `*.tmpl` file, render-test it before applying
   (see §2.4).
3. Verify with `chezmoi diff`, then `chezmoi apply`.

### 2.3 Manifest Additions (Installing Tools)

Whenever an agent installs a tool — whether the user asked or the agent
needed it — the installation **must** be recorded in the correct manifest in
the same change set:

- Official-repo system package → the matching `packages/NN-*.txt` category.
- AUR package → `archive/pacman-foreign.txt` (never a native manifest).
- Python CLI tool → `toolchains/uv.txt`.
- Rust crate → `toolchains/cargo.txt`.
- JS/TS global tool → `toolchains/bun.txt`.
- Go module → `toolchains/go.txt` (full module path).
- Manual binary in `~/.local/bin` → `toolchains/local-bin.txt`.

Append in the established format (one entry per line, comments with `#`).
If `packages/manifest.md` describes the category you changed, keep it in sync.

### 2.4 Hook Safety (`run_onchange_*.sh.tmpl`)

The three hooks run with `set -euo pipefail` and execute real system changes
(including `sudo`). Any modification must satisfy **all** of the following:

1. **Strictly idempotent** — running the rendered script N times must have
   the same effect as running it once. Guard every mutation with a presence
   check (`command -v`, `systemctl is-enabled`, file-existence tests).
2. **Graceful degradation** — optional/best-effort steps must not abort the
   run: append `|| true` (existing convention, e.g. `sudo keyd reload || true`)
   and prefer `2>/dev/null || true` for optional systemd units.
3. **Checksum headers** — keep the `{{ include "..." | sha256sum }}` header
   lines accurate; they are what triggers `run_onchange` re-execution.
4. **Syntax verification (mandatory before apply/commit)**:

   ```bash
   cd ~/.local/share/chezmoi
   for f in run_onchange_*.sh.tmpl; do
     chezmoi execute-template < "$f" | bash -n || echo "FAIL: $f"
   done
   ```

5. Never let a hook print secrets, tokens, or full `env` output.

### 2.5 Dotfiles Refinement & Maintenance Protocol

A periodic, report-first audit an agent runs on request (e.g. via the
"Refine & Reconcile System" instruction in `README.md`). Execute the
phases in order.

**Phase 1 — Surface Drift.** Run `chezmoi status` and `chezmoi diff` to
surface unmanaged local modifications and source-vs-live divergence
(invokes §2.1). Do not "fix" drift silently — report it.

**Phase 2 — Package & Manifest Reconciliation.** Bidirectional: flag both
"installed but not in any manifest" and "in manifest but not installed".

- Native: compare `pacman -Qqen` against `packages/00-system-base.txt`
  through `packages/30-terminal-utilities.txt` (ignoring comments and
  blank lines).
- Foreign/AUR: compare `pacman -Qqem` against
  `archive/pacman-foreign.txt`. AUR packages must remain in
  `archive/pacman-foreign.txt` and never enter native lists (§1.3); a
  foreign package found in a native manifest is a **Critical** finding.
- Flatpak: compare `flatpak list --app --columns=application` against
  `packages/flatpak.txt`.
- Toolchains: prefer manager-native listings over raw directory scans —
  `uv tool list` vs `toolchains/uv.txt`, `cargo install --list` vs
  `toolchains/cargo.txt`, `bun pm ls -g` vs `toolchains/bun.txt`,
  `~/go/bin` contents vs `toolchains/go.txt`. Note that `~/.local/bin` is
  shared (`uv.txt` tools + `toolchains/local-bin.txt` + unmanaged
  binaries like zed/chezmoi): cross-reference it report-only; never
  auto-remove anything.

**Phase 3 — Portability & Safety.** Scan tracked source files for
non-portable hardcoded paths, e.g. `rg -n '/home/'` — use `$HOME`/`~` in
shell or `{{ .chezmoi.homeDir }}` in templates instead.
`~/.config/fish/fish_variables` is intentionally not tracked (fish
universal-variable state); `fish_user_paths` is populated dynamically in
`config.fish` via `fish_add_path`. Verify no private keys, tokens, or
credentials are tracked (§3.1).

**Phase 4 — Report Before Mutate.** Output an executive summary grouped
as **Critical / Missing / Polish**, with the proposed fix per finding,
and **stop for user confirmation** before modifying any file. Removals
of any kind require explicit approval (§3.3).

**Phase 5 — Post-Refinement Validation.** After any approved changes,
run the §2.4.4 template test loop and the §4 checklist.

### 2.6 Agent Tool Execution Preferences

When inspecting this workspace **from the shell**, prefer the modern CLI
tools installed on this workstation over their POSIX ancestors — they are
faster, respect `.gitignore` by default, and produce agent-friendly output.
Dedicated agent tools (file read/edit, directory tree) remain the first
choice for operations they cover; this section governs shell usage.

- **Search content:** `rg`, never `grep -r`. `.gitignore` awareness is
  deliberate here; use `-u`/`-uu` only when intentionally including
  hidden/ignored paths.
- **Find files:** `fd`, never `find`. Add `-H` in this repo when hidden
  files matter (e.g. `.chezmoiignore`).
- **Read files:** dedicated read tools first; in shell use
  `bat --style=plain --paging=never` (short files: plain `cat` is fine).
  Never `cat file | while read ...` for bulk text — use single-pass
  `rg` / `sd` / `awk` pipelines.
- **List directories:** `eza` (`eza -l`, `eza --tree`) instead of
  `ls -R` / `ls -la` chains.
- **Substitute text in pipelines:** `sd` for simple find/replace; reserve
  `sed` for genuinely complex scripts.
- **System inspection:** `dust` over `du`, `procs` over `ps aux | grep`.
- **Never invoke interactive TUIs from agent shell commands** — `less`,
  `jless`, `btop`, `lazygit`, editors — they hang the session. Force
  non-interactive output: `--paging=never`, `git --no-pager`, `PAGER=cat`.

### 2.7 Prompt Review & Refinement Protocol

Applies when the user issues an operational prompt that would change
system state, manifests, hooks, or tracked configuration. Read-only
questions and steps the user has already approved execute directly —
do not review-gate them. (Distinct from §2.5, which audits the *system*;
this section audits the *instruction*.)

For in-scope prompts, the agent must **not** execute immediately — act as
a defensive reviewer first:

1. **Ground-Truth Validation (read-only probes, batched):**
   - Treat every factual claim in the prompt as unverified. Check paths,
     package names, and live state before drafting: `pacman -Si` vs
     `paru -Si` (origin, §1.3), `pacman -Qq` / `pacman -Qi` (install
     state and reason), `command -v`, and direct file reads of the full
     current content being modified.
   - Check ownership and permissions before relying on shell tests: an
     unprivileged `[ -f … ]` / `[ -d … ]` against a mode-700 directory
     silently returns false (the hook 20 PostgreSQL failure mode) —
     privilege-sensitive checks need `sudo test …`.

2. **Constraint & Protocol Audit** — verify the proposal obeys:
   - Layer boundaries: native vs AUR (§1.3) and toolchain routing (§2.3).
   - Hook safety: idempotency guards, non-interactive flags, graceful
     degradation, checksum headers (§2.4).
   - chezmoi discipline: Flow A vs Flow B, `re-add` rules, template
     checks (§2.1–§2.2).
   - Forbidden actions (§3): if the prompt requests one, **stop and
     flag it — do not refine around it.**

3. **Output a Refined Prompt (then stop):**
   - Verdict line, then numbered findings: what was wrong, missing, or
     unverifiable in the draft, with evidence from the probes.
   - A fenced refined-prompt block the user can copy-paste: exact file
     edits/commands with corrected syntax, verification steps per §4
     (template loop, `git diff` review, `chezmoi status`, staging list),
     manifest routing per §2.3 where relevant, and the post-apply
     consequences to expect.
   - **Wait for explicit user confirmation** before any write or
     state-changing command. On approval, execute the refined prompt as
     written — do not re-review or expand scope mid-flight.

---

## 3. Forbidden Actions

1. **Never stage or commit secrets.** No private keys, passphrases, API
   tokens, host tokens, or credential files — even "temporarily". Only
   `private_dot_ssh/config` is tracked; `private_dot_ssh/.gitignore` excludes
   keys. If `git status` shows an untracked key material file, **do not
   `git add` it** — warn the user instead.
2. **Never track hardware-dependent `/etc` configs.** Do not add `fstab`,
   `crypttab`, `NetworkManager` profiles, or any machine-specific
   disk/network/boot configuration to this repo. The only root-level config
   managed here is `system/keyd/default.conf` (deployed via hook).
3. **Never run destructive package operations without explicit user
   confirmation.** This includes `pacman -Rns`/`pacman -Rc` removals, orphan
   purges (`pacman -Qtdq | pacman -Rns -`), `pacman -Scc` cache wipes, and
   mass toolchain uninstalls. Propose the command and wait for approval.
4. **Never run `chezmoi apply --force` or `chezmoi purge`** without the user
   explicitly requesting it.
5. **Never bypass §2 protocols** (skipping `chezmoi status`, skipping
   `re-add`, skipping template checks) "to save time".

---

## 4. Standard Verification Checklist

After any change an agent makes, run and report:

```bash
chezmoi status                                          # expected drift only
chezmoi diff                                            # pending apply preview
chezmoi execute-template < <changed-hook> | bash -n     # if hooks changed
git status --short                                      # no secrets staged
```

Summarize: what changed, which manifest/hook was touched, what the user must
run next (usually `chezmoi apply`), and any risks.
