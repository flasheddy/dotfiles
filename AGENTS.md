# AGENTS.md — Operational Rules for AI Agents

<!-- floor-contract: sha256:000b83ac2ee8054af31fc324b639fe146d3c0a8d9f83978dc1dd367899f2651f -->

Binding contract for Goose and any AI agent operating on this chezmoi
repository. **Read fully before changing anything.** If a requested action
conflicts with these rules, stop and ask the user. This repository inherits the
workstation-wide safety floor in `~/.AGENTS.md`; the rules below are
dotfiles-specific operational extensions.

This file carries **traps, gates, and commands** — not architecture the agent
can read from the tree. Restated maps go stale and cost context on every turn.
Add a rule only when it is non-obvious, was hit more than once, and is actionable.

---

## Chezmoi Execution Model

Chezmoi system management uses a **single-tier workflow**: a plain
`goose session` operating directly in this repository. No multi-role ceremony.

Native summon subagents are available via `delegate`/`load` for scoped work:
`architect`, `g-draft`, `g-flash`, `g-audit-a`, `g-audit-b`.

**Not applicable here** — the heavy tripartite pipeline (execution-envelope
ceremony, phase-gated audit gates, exit-code checkpoints). Those belong
**strictly** to extraction projects (`~/workspace/internal/extraction-infra`),
never to chezmoi system management.

**The actual chezmoi safety gates are:** source-first editing (§2.2), `chezmoi
diff` preview before apply (§2.1), `bash -n` on changed hook templates (§2.4),
and a clean `git diff --check` before the Operator commits (§2.8, §4).

---

## 1. Repository Context & Architecture

### 1.1 Source State vs. Live Disk

This repo is the **chezmoi source state** (`~/.local/share/chezmoi`), not the
live system. chezmoi maps source to target:

- `dot_config/...` → `~/.config/...`
- `dot_gitconfig` → `~/.gitconfig`
- `private_dot_ssh/config` → `~/.ssh/config`
- `system/keyd/default.conf` → `/etc/keyd/default.conf` (deployed by hook)
- `packages/*.txt`, `toolchains/*.txt` → consumed by `run_onchange_*` hooks

- **The source tree is the single source of truth** — never treat live files as authoritative.
- Source edits do nothing until `chezmoi apply`; live edits are **silently overwritten** unless first pulled in with `chezmoi re-add`.

### 1.2 Decoupling Principle: System Packages vs. Developer Toolchains

Two deliberately decoupled install layers. Respect the boundary.

**Layer 1 — system packages (`packages/`)**, fed to `pacman -S` directly and
containing **only** official CachyOS/Arch repo packages. Custom kernel, COSMIC
desktop, compilers, LSPs, and CLI tools by category, plus `flatpak.txt`.

**Layer 2 — standalone toolchains (`toolchains/`)**, installed by official
upstream installers and kept **out of Pacman** to avoid version conflicts:
`cargo.txt`, `uv.txt`, `bun.txt`, `go.txt`, `local-bin.txt`.

Per-file inventory, install methods, and stripping rules live in
`packages/manifest.md`. Read it there; do not re-derive the lists here.

### 1.3 Hard Rule: Never Mix AUR into Native Manifests

- `packages/00-*.txt`–`30-*.txt` contain **only** official CachyOS/Arch repo packages — they feed `pacman -S` directly, and an AUR-only name aborts the whole run.
- AUR packages go **only** into `archive/pacman-foreign.txt`.
- Verify origin before writing: `pacman -Si <pkg>` succeeds for native; `paru -Si <pkg>` reveals AUR origin.

### 1.4 Repository Enforcement & Verification Gates

Commit gates run through a single **global** pre-commit hook, deployed from
`dot_config/git/hooks/executable_pre-commit` to `~/.config/git/hooks/pre-commit`
and wired machine-wide by `~/.gitconfig` (`core.hooksPath`). It is **opt-in per
repository**: it runs only where an `AGENTS.md` (or local `git-hooks/`) exists
and exits 0 otherwise, so third-party clones and scratch trees are untouched.

1. **Documentation drift** — every cross-repo `*.md` path and `##`-prefixed heading cited in the repository's `AGENTS.md` must resolve (globs and `<placeholders>` skipped). Detection only; never rewrites.
2. **Floor freshness** — a `<!-- floor-contract: sha256:… -->` marker must match the live `~/.AGENTS.md`. A stale marker **blocks** any commit staging `AGENTS.md`: re-affirm the inheritance, then run `floor-stamp`.
3. **`git diff --cached --check`** — whitespace errors and conflict markers.
4. **Secret scan** — `gitleaks git --staged --redact`, fail-closed `rg` fallback when absent.

The companion **pre-push** hook runs a repository's **full** verification before
anything leaves the machine: it dispatches to `just check` where that recipe
exists (this repository's `justfile` is the reference adapter) and fails closed
when the entry point is present but unrunnable. Partial gates must use other
recipe names so they can never be mistaken for the full gate.

`just check` is this repository's full gate:

- `just check` — full sequential gate: config invariants, recipe gate, gate self-test, AGENTS.md hygiene, lint, secret scan
- `just check-fast` — the same set plus the advisory drift report, **in parallel**, pinned to 3 workers
- `just check-commands [accept|reject] [root]` — structural recipe gate; `reject` runs the RED fixture self-test
- `just check-agents [accept|reject] [file]` — AGENTS.md hygiene: no tables outside code fences, Prettier-idempotent, context budget, single H1, no duplicate bullets, floor marker current
- `just check-config`, `just check-permissions`, `just lint`, `just secrets`, `just drift` — individual stages

### 1.5 Goose Configuration Map

Every goose surface is chezmoi-managed except `permission.yaml` (below). The full
mapping is `chezmoi managed` output. Only four entries carry a trap:

- `dot_config/goose/dot_goosehints.tmpl` → `~/.config/goose/.goosehints` — **inlines the global floor**, so editing the floor edits goose's system prompt.
- `dot_AGENTS.md` → `~/.AGENTS.md` (+ `~/AGENTS.md` symlink) — the floor itself; also read directly by home-path tools.
- `dot_config/goose/prompts/system.md` → `~/.config/goose/prompts/system.md` — system-prompt template, not the floor.
- `dot_config/fish/config.fish` → `~/.config/fish/config.fish` — `GOOSE_SHELL` and CLI theme; read at shell startup only.

`just check-config` enforces the `config.yaml` invariants: `GOOSE_MODE`
non-autonomous, `memory` family disabled, `GOOSE_DOCS_ROOT` an absolute populated
tree, no remote recipe repo.

**Tracked but not deployed — `permission.yaml`.** `dot_config/goose/private_permission.yaml`
holds the canonical posture (`always_allow` local execution, `ask_before`
extension management, `never_allow` apps/orchestrator). goose rewrites
`~/.config/goose/permission.yaml` itself at runtime — comments dropped, the
active mode's scope key repartitioned — so chezmoi can never hold a byte-identical
copy; managing it produced permanent drift plus an interactive _"has changed
since chezmoi last wrote it"_ prompt. It is `.chezmoiignore`d. The source file
stays the `just check-permissions` gate input (that gate reads the **source**
name, never the deployed file) and the fresh-machine reference posture.

**Context budget trap.** goose loads **both** `AGENTS.md` and `.goosehints` at
every hierarchy level, concatenated. Floor (~15 KB) + this file must stay under
32 KiB (Codex `AGENTS_MD_MAX_BYTES`); `just check-agents` enforces it.

### 1.6 Syncthing (PC ↔ Android Sync)

Moved: package, firewall rules, linger, runtime layout, verified behaviour, and
verification commands now live in `packages/manifest.md` →

`## Syncthing (PC ↔ Android Sync)`

---

## 2. Operating Protocols

### 2.1 Read State Before Acting

Before modifying **any** file:

```fish
chezmoi status    # pending source-vs-target differences
chezmoi diff      # generated target vs. live destination; apply preview
```

Report unexpected drift; never "fix" it silently. `chezmoi diff` includes
unapplied source-tree changes that affect managed targets.

### 2.2 Editing Workflow

**Flow A — edit live files on disk** (e.g. `~/.config/fish/config.fish`):

1. Edit the live file.
2. **MUST** `chezmoi re-add <file>` — applying without `re-add` destroys the live change (§1.1).
3. Verify with `chezmoi diff`, then `chezmoi apply`.

**Flow B — edit the source tree directly** (preferred):

1. Edit under `~/.local/share/chezmoi`.
2. Touched any `*.tmpl`? Render-test it first (§2.4).
3. `chezmoi diff` must show only the intended target change before you apply.

### 2.3 Manifest Additions (Installing Tools)

Every tool an agent installs — requested or not — **must** be recorded in the
correct manifest in the same change set:

- Official-repo system package → matching `packages/NN-*.txt` category
- AUR package → `archive/pacman-foreign.txt` (never a native manifest)
- Python CLI → `toolchains/uv.txt`; Rust crate → `toolchains/cargo.txt`
- JS/TS global → `toolchains/bun.txt`; Go module → `toolchains/go.txt` (full module path)
- Manual `~/.local/bin` binary → `toolchains/local-bin.txt`

One entry per line, `#` for comments. Keep `packages/manifest.md` in sync.

### 2.4 Hook Safety (`run_onchange_*.sh.tmpl`)

Every `run_onchange` hook runs with `set -euo pipefail` and executes real system
changes (including `sudo`). Any modification must satisfy **all** of the
following:

1. **Strictly idempotent** — N runs ≡ 1 run. Guard every mutation with a presence check (`command -v`, `systemctl is-enabled`, file-existence tests).
2. **Graceful degradation** — optional steps must not abort the run: append `|| true` (e.g. `uv tool install "$tool" || true`), prefer `2>/dev/null || true` for optional systemd units.
3. **Checksum headers** — keep `{{ include "..." | sha256sum }}` lines accurate; they trigger re-execution.
4. **Syntax verification (mandatory before apply/commit)**:

   ```fish
   cd ~/.local/share/chezmoi
   for f in run_onchange_*.sh.tmpl
       chezmoi execute-template < "$f" | bash -n
       or echo "FAIL: $f"
   end
   ```

5. Never let a hook print secrets, tokens, or full `env` output.

### 2.5 Dotfiles Refinement & Maintenance Protocol

Report-first audit, run on request. Execute phases in order.

**Phase 1 — Surface Drift.** `chezmoi status` + `chezmoi diff` (§2.1). Report
drift; never fix silently.

**Phase 2 — Package & Manifest Reconciliation.** Bidirectional: flag "installed
but unlisted" **and** "listed but not installed".

- Native: `pacman -Qqen` vs `packages/00-*.txt`–`30-*.txt` (ignore comments/blanks). Packages documented in the **Stripping Rules** section of `packages/manifest.md` are deliberately absent and _always_ show as false positives; a package installed as a dependency never appears in `pacman -Qqen` — check `pacman -Qi <pkg>` → _Install Reason_ before flagging.
- Foreign/AUR: `pacman -Qqem` vs `archive/pacman-foreign.txt` — a foreign package in a native manifest is **Critical** (§1.3).
- Flatpak: `flatpak list --app --columns=application` vs `packages/flatpak.txt`.
- Toolchains: manager-native listings, not directory scans — `uv tool list`, `cargo install --list`, `bun pm ls -g`, `~/go/bin` vs the matching `toolchains/*.txt`. `~/.local/bin` is shared (`uv.txt` + `local-bin.txt` + unmanaged like chezmoi): report-only, never auto-remove.

**Phase 3 — Portability & Safety.** `rg -n '/home/'` on tracked files — use
`$HOME`/`~` or `{{ .chezmoi.homeDir }}`. `fish_variables` is intentionally
untracked; `fish_user_paths` is populated via `fish_add_path` in `config.fish`.
Confirm no credentials tracked (§3).

**Phase 4 — Report Before Mutate.** Summary grouped **Critical / Missing /
Polish** with proposed fixes; **stop for confirmation** before any modification.
Removals need explicit approval (`~/.AGENTS.md` forbidden actions).

**Phase 5 — Post-Refinement Validation.** After approved changes: §2.4 item 4
template loop + §4 checklist.

Routine operator prompts:

- **"Refine & Reconcile System"** — "Run a complete dotfiles refinement audit per AGENTS.md §2.5. Reconcile pacman, AUR, Flatpak, and standalone toolchains with the manifests, scan for drift and portability issues, and report findings before modifying any files."
- Variants on the same protocol: read-only audit ("Run `chezmoi status` and `chezmoi diff`, report drift. Change nothing."), system update + manifest reconciliation, and add-a-toolchain (install, append to the matching `toolchains/*.txt`, verify with `chezmoi status`).

Rule of thumb: agents may read freely, must document every install in a
manifest, and must ask before anything destructive.

### 2.6 Agent Tool Execution Preferences

Workstation-wide — see `~/.AGENTS.md` (Modern CLI Tool Preferences), including
the ban on interactive TUIs in agent shells. Address retained for cross-reference
stability.

### 2.7 Prompt Review & Refinement Protocol

Follow the workstation-wide protocol in `~/.AGENTS.md` (Prompt Review &
Refinement Protocol). Its Constraint & Protocol Audit applies this file's rules:
layer boundaries (§1.3, §2.3), hook safety (§2.4), chezmoi discipline
(§2.1–§2.2), and §3.

Dotfiles-specific: any change to a sudo-invoking hook template
(`run_onchange_*.sh.tmpl`) **must** carry an explicit `[ROOT IMPACT]` tag naming
the affected system services, files, and privileges (§2.4).

### 2.8 Git Commit Discipline & Attribution

Every agent-created or -rewritten commit:

1. **Conventional Commits, scope mandatory** — `type(scope): subject`; unscoped is a defect. Narrowest accurate scope (established: `agents`, `aup`, `fcitx5`, `fish`, `git`, `helix`, `toolchains`); new single-token lowercase scopes only when none fit.
2. **History rewrites: scripted, backed up, remote restored** — no interactive rebases (interactive TUIs hang agent sessions — `~/.AGENTS.md`); `git filter-repo` with a scripted callback; `git bundle` backup _outside_ the repo first (filter-repo rewrites all refs, expires reflogs, gc's — in-repo branches are not backups); restore `origin` after. The rewrite plan goes through §2.7 review.
3. **Force-push gate** — explicit user confirmation + `git push --force-with-lease`, never bare `--force`.

### 2.9 Session Auditing

**Session Auditor** is a read-only role auditing session history and repository
state for drift. The goose store
`~/.local/share/goose/sessions/sessions.db` is opened **only** with
`sqlite3 -readonly`; no `DELETE`/`UPDATE`/`VACUUM` is ever issued. The same rule
covers `handoff-copy` (`dot_config/fish/functions/handoff-copy.fish`), which
snapshots the latest assistant block, git state, and plan path via `wl-copy`.

### 2.10 Git Handoff Protocol (Operator-Executed)

The agent is the sole **provider** of conventional git commands; the Operator is
the sole **executor**. At every Operator-gated checkpoint:

1. Read local git state read-only: `env GIT_OPTIONAL_LOCKS=0 git status --short`,
   `env GIT_OPTIONAL_LOCKS=0 git branch --show-current`,
   `env GIT_OPTIONAL_LOCKS=0 git log --oneline -1`.

2. Emit exact, copy-pasteable commands (never execute them): branch `git checkout -b feat/<scope>`; commit `git commit -m "type(scope): subject" -m "body"`.
3. Never run git write operations (add/commit/merge/switch/branch/tag/reset/checkout -b/push). The Operator is sole execution authority for branch/commit/merge/push (inherited from `~/.AGENTS.md`).

### 2.11 Offline Goose Docs Root (`/opt/goose-docs`)

`goose-doc-guide` reads documentation from `GOOSE_DOCS_ROOT`, pinned to a local
tree so lookups never hit the network. Provision it **once, online** — the only
step that needs a network: clone the goose repo at the tag matching
`goose --version`, run `npm ci && npm run build` in `documentation/`, and copy
`documentation/build/` into `~/.cache/goose-docs-build/`. `chezmoi apply` then
installs it to `/opt/goose-docs` via the idempotent `run_onchange_after_30` hook,
which never fetches by itself. `check-config`'s `docs-root` rule fails closed
until the tree exists.

---

## 3. Forbidden Actions

Universal forbidden actions — secrets/credentials, destructive package
operations, untrusted external content, unconstrained sudo mutations — are
defined in `~/.AGENTS.md` and apply unchanged. Dotfiles-specific:

1. **Only `private_dot_ssh/config` is tracked** (its `.gitignore` excludes keys). Untracked key material in `git status`? Do **not** `git add` — warn the user.
2. **Never track hardware-dependent `/etc` configs** — no `fstab`, `crypttab`, NetworkManager profiles, or machine-specific disk/network/boot config. The only managed root-level config is `system/keyd/default.conf` (via hook).
3. **Never run `chezmoi apply --force` or `chezmoi purge`** unless the user explicitly requests it.
4. **Never bypass §2 protocols** (skipping `chezmoi status`, `re-add`, template checks, AGENTS.md hygiene checks) "to save time".

---

## 4. Standard Verification Checklist

After any change an agent makes, run and report:

```fish
chezmoi status       # expected drift only
chezmoi diff         # pending apply preview
chezmoi execute-template < <changed-hook> | bash -n   # if hooks changed
just check-agents    # if AGENTS.md changed
git status --short   # no secrets staged
```

Summarize: what changed, which manifest/hook was touched, what the user must run
next (usually `chezmoi apply`), and any risks.
