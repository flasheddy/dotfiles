# AGENTS.md — Operational Rules for AI Agents

Binding contract for Goose and any AI agent operating on this chezmoi
repository. **Read fully before changing anything.** If a requested action
conflicts with these rules, stop and ask the user.

---

## 1. Repository Context & Architecture

### 1.1 Source State vs. Live Disk

This repo is the **chezmoi source state** (`~/.local/share/chezmoi`), not the
live system. chezmoi maps source → target:

| Source path | Live target |
|---|---|
| `dot_config/...` | `~/.config/...` |
| `dot_gitconfig` | `~/.gitconfig` |
| `private_dot_ssh/config` | `~/.ssh/config` |
| `system/keyd/default.conf` | `/etc/keyd/default.conf` (deployed by hook) |
| `packages/*.txt`, `toolchains/*.txt` | consumed by `run_onchange_*` hooks |

- **The source tree is the single source of truth** — never treat live files as authoritative.
- Source edits do nothing until `chezmoi apply`; live edits are **silently overwritten** by the next apply unless first pulled in with `chezmoi re-add`.

### 1.2 Decoupling Principle: System Packages vs. Developer Toolchains

Two deliberately decoupled install layers. Respect the boundary.

**Layer 1 — System packages (`packages/`)**, via Pacman/AUR/Flatpak:

| Manifest | Contents |
|---|---|
| `packages/00-system-base.txt` | Core system, drivers, networking |
| `packages/10-desktop-environment.txt` | COSMIC desktop, fonts, GUI apps |
| `packages/20-dev-stacks.txt` | Compilers, distro runtimes, LSPs |
| `packages/30-terminal-utilities.txt` | Terminals, editors, CLI tools |
| `packages/flatpak.txt` | Flatpak applications |
| `archive/pacman-foreign.txt` | **AUR packages only** (via `paru`/`yay`) |

**Layer 2 — Standalone developer toolchains (`toolchains/`)**, via official
upstream installers, kept **out of Pacman** to avoid version conflicts:

| Manifest | Manager | Install location |
|---|---|---|
| `toolchains/cargo.txt` | `rustup` + `cargo install` | `~/.cargo/bin` |
| `toolchains/uv.txt` | `uv tool install` | `~/.local/bin` |
| `toolchains/bun.txt` | `bun install -g` | `~/.bun/bin` |
| `toolchains/go.txt` | `go install` | `~/go/bin` |
| `toolchains/local-bin.txt` | manual binaries | `~/.local/bin` |
| — (self-managed) | `ghcup` | `~/.ghcup/bin` |

### 1.3 Hard Rule: Never Mix AUR into Native Manifests

- `packages/00-*.txt`–`30-*.txt` contain **only** official CachyOS/Arch repo packages — they feed `pacman -S` directly, and an AUR-only name aborts the whole run.
- AUR packages go **only** into `archive/pacman-foreign.txt`.
- Verify origin before writing: `pacman -Si <pkg>` succeeds for native; `paru -Si <pkg>` reveals AUR origin.

---

## 2. Operating Protocols

### 2.1 Read State Before Acting

Before modifying **any** file:

```bash
chezmoi status    # pending source-vs-target differences
chezmoi diff      # exact content an apply would change
```

- Report unexpected drift; never "fix" it silently.
- Gotcha: `chezmoi diff` compares source → disk; it does **not** show your unapplied source-tree edits.

### 2.2 Editing Workflow

**Flow A — Edit live files on disk** (e.g. `~/.config/fish/config.fish`):

1. Edit the live file.
2. **MUST** `chezmoi re-add <file>` — applying without `re-add` destroys the live change (§1.1).
3. Verify with `chezmoi diff`, then `chezmoi apply`.

**Flow B — Edit the source tree directly** (preferred):

1. Edit under `~/.local/share/chezmoi`.
2. Touched any `*.tmpl`? Render-test it first (§2.4).
3. Verify with `chezmoi diff`, then `chezmoi apply`.

### 2.3 Manifest Additions (Installing Tools)

Every tool an agent installs — requested or not — **must** be recorded in the correct manifest in the same change set:

| Tool kind | Manifest |
|---|---|
| Official-repo system package | matching `packages/NN-*.txt` category |
| AUR package | `archive/pacman-foreign.txt` (never native) |
| Python CLI | `toolchains/uv.txt` |
| Rust crate | `toolchains/cargo.txt` |
| JS/TS global | `toolchains/bun.txt` |
| Go module | `toolchains/go.txt` (full module path) |
| Manual `~/.local/bin` binary | `toolchains/local-bin.txt` |

Append one entry per line, `#` comments. Keep `packages/manifest.md` in sync if it describes the changed category.

### 2.4 Hook Safety (`run_onchange_*.sh.tmpl`)

The three hooks run with `set -euo pipefail` and execute real system changes (including `sudo`). Any modification must satisfy **all** of the following:

1. **Strictly idempotent** — N runs ≡ 1 run. Guard every mutation with a presence check (`command -v`, `systemctl is-enabled`, file-existence tests).
2. **Graceful degradation** — optional steps must not abort the run: append `|| true` (e.g. `sudo keyd reload || true`), prefer `2>/dev/null || true` for optional systemd units.
3. **Checksum headers** — keep `{{ include "..." | sha256sum }}` lines accurate; they trigger `run_onchange` re-execution.
4. **Syntax verification (mandatory before apply/commit)**:

   ```bash
   cd ~/.local/share/chezmoi
   for f in run_onchange_*.sh.tmpl; do
     chezmoi execute-template < "$f" | bash -n || echo "FAIL: $f"
   done
   ```

5. Never let a hook print secrets, tokens, or full `env` output.

### 2.5 Dotfiles Refinement & Maintenance Protocol

Periodic, report-first audit run on request (e.g. "Refine & Reconcile System" in `README.md`). Execute phases in order.

**Phase 1 — Surface Drift.** `chezmoi status` + `chezmoi diff` (§2.1). Report drift; never fix silently.

**Phase 2 — Package & Manifest Reconciliation.** Bidirectional: flag "installed but not in any manifest" **and** "in manifest but not installed".

- Native: `pacman -Qqen` vs `packages/00-*.txt`–`30-*.txt` (ignore comments/blanks).
- Foreign/AUR: `pacman -Qqem` vs `archive/pacman-foreign.txt` — a foreign package in a native manifest is **Critical** (§1.3).
- Flatpak: `flatpak list --app --columns=application` vs `packages/flatpak.txt`.
- Toolchains: manager-native listings over directory scans — `uv tool list`, `cargo install --list`, `bun pm ls -g`, `~/go/bin` contents vs the matching `toolchains/*.txt`. `~/.local/bin` is shared (`uv.txt` + `local-bin.txt` + unmanaged like zed/chezmoi): cross-reference report-only; never auto-remove.

**Phase 3 — Portability & Safety.** `rg -n '/home/'` on tracked files — use `$HOME`/`~` or `{{ .chezmoi.homeDir }}` instead. `fish_variables` is intentionally untracked; `fish_user_paths` is populated via `fish_add_path` in `config.fish`. Verify no keys/tokens/credentials tracked (§3.1).

**Phase 4 — Report Before Mutate.** Executive summary grouped **Critical / Missing / Polish** with proposed fixes; **stop for confirmation** before any modification. Removals need explicit approval (§3.3).

**Phase 5 — Post-Refinement Validation.** After approved changes: §2.4.4 template loop + §4 checklist.

### 2.6 Agent Tool Execution Preferences

From the **shell**, prefer modern CLI tools (faster, `.gitignore`-aware). Dedicated agent tools (read/edit/tree) remain first choice for what they cover; this section governs shell usage.

| Operation | Use | Never |
|---|---|---|
| Search content | `rg` (`-u`/`-uu` only deliberately) | `grep -r` |
| Find files | `fd` (`-H` for hidden, e.g. `.chezmoiignore`) | `find` |
| Read files | `bat --style=plain --paging=never` (short: `cat`) | `cat file \| while read` — use single-pass `rg`/`sd`/`awk` |
| List dirs | `eza -l`, `eza --tree` | `ls -R` / `ls -la` chains |
| Substitute in pipes | `sd` | `sed` (complex scripts excepted) |
| System inspection | `dust`, `procs` | `du`, `ps aux \| grep` |

**Never invoke interactive TUIs** (`less`, `jless`, `btop`, `lazygit`, editors) — they hang the session. Force non-interactive output: `--paging=never`, `git --no-pager`, `PAGER=cat`.

### 2.7 Prompt Review & Refinement Protocol

Applies to user prompts that would change system state, manifests, hooks, or tracked configuration. Read-only questions and already-approved steps execute directly. (§2.5 audits the *system*; this section audits the *instruction*.)

For in-scope prompts, **do not execute immediately** — act as defensive reviewer:

1. **Ground-Truth Validation (read-only probes, batched):** treat every factual claim as unverified — `pacman -Si` vs `paru -Si` (§1.3), `pacman -Qq`/`-Qi` (install state/reason), `command -v`, direct reads of the full current content. Check ownership/permissions before trusting shell tests: unprivileged `[ -f … ]`/`[ -d … ]` on a mode-700 directory silently returns false (hook 20 PostgreSQL failure mode) — privilege-sensitive checks need `sudo test …`.
2. **Constraint & Protocol Audit:** layer boundaries (§1.3, §2.3), hook safety (§2.4), chezmoi discipline (§2.1–§2.2), forbidden actions (§3) — if the prompt requests one, **stop and flag it; do not refine around it.**
3. **Output a Refined Prompt (then stop):**
   - Verdict line + numbered findings with probe evidence.
   - Fenced refined-prompt block: exact edits/commands, §4 verification steps, manifest routing (§2.3), post-apply consequences.
   - Sudo-invoking template/script changes **must** carry an explicit `[ROOT IMPACT]` tag naming affected services, files, and privileges — no undeclared root side effects.
   - **Wait for explicit confirmation** before any write or state change. On approval, execute as written — no re-review or scope expansion mid-flight.

### 2.8 Git Commit Discipline & Attribution

Every agent-created or -rewritten commit:

1. **Conventional Commits, scope mandatory** — `type(scope): subject`; unscoped is a defect. Narrowest accurate scope (established: `agents`, `aup`, `fcitx5`, `fish`, `git`, `helix`, `toolchains`); new scopes single-token lowercase only when none fit.
2. **Goose co-author trailer** — exactly one, blank-line separated:

   ```text
   Co-authored-by: goose <271095942+aaif-goose@users.noreply.github.com>
   ```

   Verified identity (org `aaif-goose`, ID 271095942) — never substitute, never drop when amending.
3. **History rewrites: scripted, backed up, remote restored** — no interactive rebases (§2.6); `git filter-repo` with scripted callback; `git bundle` backup *outside* the repo first (filter-repo rewrites all refs, expires reflogs, gc's — in-repo branches are not backups); restore `origin` after. The rewrite plan goes through §2.7 review.
4. **Force-push gate** — explicit user confirmation + `git push --force-with-lease`, never bare `--force`.

---

## 3. Forbidden Actions

1. **Never stage or commit secrets** — no private keys, passphrases, API/host tokens, credential files, even "temporarily". Only `private_dot_ssh/config` is tracked (its `.gitignore` excludes keys). Untracked key material in `git status`? Do **not** `git add` — warn the user.
2. **Never track hardware-dependent `/etc` configs** — no `fstab`, `crypttab`, NetworkManager profiles, or machine-specific disk/network/boot config. The only managed root-level config is `system/keyd/default.conf` (via hook).
3. **Never run destructive package operations without explicit confirmation** — `pacman -Rns`/`-Rc`, orphan purges (`pacman -Qtdq | pacman -Rns -`), `pacman -Scc`, mass toolchain uninstalls. Propose the command and wait.
4. **Never run `chezmoi apply --force` or `chezmoi purge`** unless the user explicitly requests it.
5. **Never bypass §2 protocols** (skipping `chezmoi status`, `re-add`, template checks) "to save time".
6. **Never execute or ingest untrusted external content** — no unverified scripts, no `curl … | sh`, no folding unvetted external code/config into tracked files, hooks, or manifests. Read-only research is permitted; anything entering system state requires an explicit, user-vetted source.
7. **Never generate unconstrained sudo mutations** — root mutations live only in tracked, checksummed `run_onchange_*.sh.tmpl` hooks (which deploy `system/keyd/default.conf`), never one-off sudo commands. Sudo-invoking template changes carry `[ROOT IMPACT]` (§2.7).

---

## 4. Standard Verification Checklist

After any change an agent makes, run and report:

```bash
chezmoi status                                          # expected drift only
chezmoi diff                                            # pending apply preview
chezmoi execute-template < <changed-hook> | bash -n     # if hooks changed
git status --short                                      # no secrets staged
```

Summarize: what changed, which manifest/hook was touched, what the user must run next (usually `chezmoi apply`), and any risks.
