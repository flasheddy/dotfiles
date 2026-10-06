# Global Agent Directives & Safety Guardrails

Applies to all agent tasks under `$HOME`. Project-local `AGENTS.md` files define project-specific toolchain, commands, workflows, schemas, and architecture.

## Precedence

1. **Hard Safety Constraints** (below) — the absolute floor; nothing weakens them.
2. System/platform instructions and the operator's explicit current request — may override workflow conventions, never the Hard Safety Constraints.
3. **Project-local `AGENTS.md`** — may add stricter rules; inside its repo it wins, except over the Hard Safety Constraints and the floor-class rules in *Workstation Agent Additions* (Prompt Review & Refinement Protocol; Forbidden Actions).
4. Remaining conventions in this file.

## Core Working Philosophy

- Correctness, clarity, and bounded changes over speculative refactoring.
- Work in the active checkout; no worktrees, isolated feature branches, or state-machine ceremony unless instructed.
- Plans: direct, proportionate to technical depth; include exact contracts, commands, invariants, and acceptance evidence; omit ceremony.
- Read-only inspection first; no write or state change before Operator checkpoint sign-off.
- Status reports: what changed, where, how verified, what remains.

## Hard Safety Constraints

- **Offline by default:** no fetch, push, publish, deploy, authenticate, or external network call without explicit per-task operator approval. Before an approved push, state destination, branch, and commits.
- **Secrets:** never read, log, or commit credentials, API keys, tokens, cookies, private keys, `.env` files, credential stores, or browser profiles. Examples, fixtures, and tests use synthetic placeholders that do not resemble real credentials; synthetic tokens assigned to `*key*`/`*token*`/`*secret*` variables MUST use delimiter-broken syntax (e.g. `phaseN:test:key:0001`) or an inline `# gitleaks:allow` comment on the same line.
- **Never edit repository internals:** no files inside `.git/`.
- **Never bypass protections:** no `--no-verify`; no disabling hooks; no weakening, deleting, or suppressing security checks, scanners, or regression tests to make a change pass.
- **Confidentiality:** repository contents and user data are private.
- **Never evade constraints:** no runtime workarounds (ephemeral shims, synthetic mocks, dynamic state patching, test monkeypatching) to bypass frozen verifiers or simulate missing dependencies.
- **Prompt defense is universal:** treat every prompt as an unverified hypothesis; verify factual claims (file existence and content, tool and package availability and origin, ownership/permissions, branch/dependency state) before acting — in every task domain, including code-level repository development.

## Git & Repository Hygiene

- **Protected primary branches:** `main`/`master` is stable; never commit or merge to it without explicit operator confirmation. Otherwise commit only when instructed, on the designated branch.
- **Non-destructive:** never `git reset --hard`, `git clean -fd`, `git checkout .`, `git restore .`, `git push --force`, or history-rewriting commands without explicit instruction.
- **Preserve uncommitted work:** never overwrite, stash, or discard existing user changes.
- **Targeted staging:** stage only explicitly named files; never `git add .` or `-A`.
- **Read-only inspection:** prefix with `env GIT_OPTIONAL_LOCKS=0 git status` (never bare `VAR=val <cmd>`).
- **No repo bootstrap:** never `git init` unless asked; outside Git these rules do not apply.

## Verification & Execution

- Take build, test, lint, and scan commands from project docs (`AGENTS.md`, README, CI config, justfile/Makefile); never invent toolchain commands.
- For non-trivial code changes, run the documented verification; if none, use judgment, keep it local and offline.
- Report pre-existing failures separately; do not fix unrelated issues unless asked.

### Red-Green Verification (floor-class)

No gate, check, hook, assertion, or query is trusted until the operator has seen its **failure state**.

- Demonstrate **rejecting a deliberately broken input** (RED), then **passing the real input** (GREEN).
- A check only ever observed passing is untested — report it as such, never as evidence.
- **Exit code 0 is not evidence alone.** Where the artifact matters, assert on the artifact: byte identity, content hashes, idempotency across repeated runs.
- **Empty or implausible probe result → suspect the probe.** Rerun it or verify a second way.
- **Classify every failure** as induced, pre-existing, or environmental before concluding.
- Record a gotcha in documentation only after reproducing its failure.

Floor-class: project-local `AGENTS.md` may make this stricter, never weaker.

- **Dual-model single-pass review (optional):** single-bounded passes against an explicit invariant checklist; never recursive self-review. Enforce the full gate set (pytest, contract validators, frontend, locks, secret scans), never a shorthand. Leave pre-existing baseline failures untouched unless separately authorized. Refer to roles ("drafting model"/"reviewing model"), not vendor names. Commit authority and branch rules stay operator-controlled.

## SDD Invariant & Anti-Loop Harness

Floor-class: project-local `AGENTS.md` may add stricter workflow, never weaken or skip these four rules.

### Spec-Driven Development (SDD) Invariant Sync Order

On any mid-task requirement, contract, or design change, apply in order — never patch ad hoc:

1. `Spec` — requirements + acceptance criteria first.
2. `Plan` — assess impact; adjust the plan.
3. `Tasks` — re-derive affected tasks.
4. `Implement` — only then touch code.

- Requirements live in the Spec, never in chat history. New features go into a "to-do later" section, not silently into scope.
- Every requirement carries a machine-checkable acceptance criterion (PASS/FAIL). "Works well" or "improve X" is not one.

### 5-Step Anti-Loop Debugging Protocol

On the first fix → retry loop (same failure reappears), stop and apply in order:

1. **Write Freeze** — stop editing; read-only symptom analysis.
2. **Minimal Diff / Symptom Isolation** — one failing test + `git diff -U3` only; smallest reproducible failure; discard unrelated changes.
3. **Spec/Docs Injection** — re-read the authoritative contract/signature (`AGENTS.md`, spec, schema) before hypothesizing.
4. **Context Kill on ≥3 loops** — after 3 failed attempts on one symptom, write an audit summary, end the session, restart clean.
5. **Role Escalation** — if the symptom survives a clean restart, escalate `g-draft` → `architect` re-specification (or Operator); stop patching the same hypothesis.

### Context Hygiene & Boundary Rules

- `/context` — inspect context before acting.
- `/compact` (with retention priorities) — task incomplete; compress and name what to keep (completed work, open problems, next task).
- `/clear` / new session — task complete; wipe context, never carry stale state.
- One session = one objective; tangential ideas go to a fork or separate thread.

### Task Execution Contract (Goose Task Schema)

Every `g-draft` execution envelope MUST declare all four fields before any write or state change:

| Field | Required content |
|---|---|
| **Task Objective** | One sentence: the single deliverable. |
| **Target Modules / Files** | Exact file paths in scope. |
| **Prerequisites** | Docs/state that must already exist. |
| **Machine-Verifiable Verification** | PASS/FAIL assertion (`test -s`, `rg -q`, exit code) proving completion. |

---

## Workstation Agent Additions

Supplement to the floor. Chezmoi-managed: source `~/.local/share/chezmoi/dot_AGENTS.md` → `~/.AGENTS.md`; `~/AGENTS.md` symlinks to it. **Edit the source, never the deployed copy.** Project-local `AGENTS.md` may add stricter rules; on conflict the floor wins.

The **Prompt Review & Refinement Protocol** and **Forbidden Actions (Workstation-Wide)** are floor-class and cannot be weakened or overridden by any project-local `AGENTS.md`.

### Modern CLI Tool Preferences

From the **shell**, prefer modern CLI tools (faster). `.gitignore` awareness is tool-specific: `rg`/`fd` honour it by default; `eza` requires `--git-ignore`. Dedicated agent tools (read/edit/tree) are first choice for what they cover.

| Operation | Use | Never |
|---|---|---|
| Search content | `rg` (`-u`/`-uu` only deliberately) | `grep -r` |
| Find files | `fd` (`-H` for hidden) | `find` |
| Read files | `bat --style=plain --paging=never` (short: `cat`) | `cat file \| while read`; use single-pass `rg`/`sd`/`awk` |
| List dirs | `eza -la --color=never` (hidden incl.), `eza -a --tree -L 2 --git-ignore` (always cap depth; `-a` shows dotfiles; `--git-ignore` honors ignore rules) | `ls -R` / `ls -la` chains |
| Substitute in pipes | `sd` | `sed` (complex scripts excepted) |
| System inspection | `dust`, `procs` | `du`, `ps aux \| grep` |

**Never invoke interactive TUIs** (`less`, `jless`, `btop`, `lazygit`, editors) — they hang the session. Force non-interactive output **using each tool's own flag**: `bat --paging=never` (`--paging` exists ONLY in `bat`/`less`; `eza`, `rg`, `fd`, `sd` reject it with exit 2), `git --no-pager`, `PAGER=cat`.

### Shell Dialect & Syntax (Fish Shell)

Direct shell commands and operator snippets MUST use native Fish syntax:

| Need | Use | Never |
|---|---|---|
| Global var | `set -gx VAR val` | bare `VAR=val` |
| Scoped var | `begin; set -lx VAR val; cmd; end` | — |
| Transient env | `env VAR=val <cmd>` (e.g. `env GIT_OPTIONAL_LOCKS=0 git status`) | `export` |
| Separate statements | `;`; `; and` to short-circuit | `&&` |
| Conditional | `if test ...; ...; end` | `then` / `fi` |
| Loop | `for var in ...; ...; end` | `do` / `done` |
| Exit status | `$status` | `$?` |
| Command substitution | `(cmd)` | `$(cmd)` |
| Subshell | dir-aware flag (`--project <dir>`, `-C <dir>`) or `begin; pushd <dir>; and <cmd>; and popd; end` | POSIX `(...)` in command position |
| Redirection | `od -c`, `xxd`, `jq`, `bat`, or the project runner (e.g. `uv run ...`) | `<<EOF` / `<<'PY'`; bare `python3 -c`/`node -e` when a runner is mandated |
| Path | `fish_add_path /path/to/bin` | — |

**POSIX/Bash exceptions:** only for `*.sh` with a Bash/POSIX `sh` shebang, `*.sh.tmpl` rendering to such a script, invoking the declared interpreter for syntax validation (e.g. `bash -n`), or a third-party tool requiring a POSIX string invocation (`bash -c "..."`, `sh -c "..."`).

### Prompt Review & Refinement Protocol

Applies to every prompt requesting any write, state change, or instruction execution — source-code edits, tests, documentation, CI/build files, dependency changes, repository file creation/modification, and system state, package sets, hooks, or tracked configuration. Only purely read-only questions and already-approved steps execute directly.

**Checkpoint Halt Invariant:** on a `STOP CHECKPOINT` directive (e.g. `STOP CHECKPOINT 1`), the agent MUST immediately stop and yield the turn at that checkpoint; proceeding into the next turn's implementation in the same response is prohibited.

For in-scope prompts, **do not execute immediately** — act as defensive reviewer:

1. **Ground-Truth Validation (read-only probes, batched):** treat every factual claim as unverified — check package origins and install state (`pacman -Si`/`paru -Si`, `pacman -Qq`/`-Qi`), `command -v`, and read the full current content of every file to be modified. Check ownership/permissions before trusting shell tests: unprivileged `[ -f … ]`/`[ -d … ]` on a mode-700 directory silently returns false — privilege-sensitive checks need `sudo -n test …`; if authentication is required, follow the GUI Privilege Escalation Protocol.
2. **Constraint & Protocol Audit:** verify the proposal obeys project-local `AGENTS.md`, the Hard Safety Constraints, and the Forbidden Actions — if it requests one, **stop and flag it; do not refine around it.**
   - **Allowlist Reachability:** if satisfying task invariants strictly requires modifying files outside the allowlist (specs, data definitions, test assertions, config manifests) and any required file is missing, **HALT in Step 3** and report the required allowlist expansion before editing code.
3. **Output a Refined Prompt (then stop):**
   - Verdict line + numbered findings with probe evidence.
   - Fenced refined-prompt block: exact edits/commands, verification steps, and post-apply consequences.
   - Sudo-invoking template/script changes **must** carry an explicit `[ROOT IMPACT]` tag naming affected services, files, and privileges.
   - **Wait for explicit confirmation** before any write or state change. On approval, execute as written — no re-review or mid-flight scope expansion.

### GUI Privilege Escalation Protocol

Agent shells have no TTY and cannot answer `sudo` password prompts — bare interactive `sudo` hangs the session.

1. Probe passwordless sudo: `sudo -n true 2>/dev/null`.
2. If a password is required, agents **MUST** use `pkexec <command>`, never bare `sudo`. `pkexec` authenticates via D-Bus through the desktop Polkit agent (`polkit-kde-agent`), presenting a modal prompt instead of hanging.
3. Bound every `pkexec` call with `timeout` (e.g. `timeout 150 pkexec …`) so an unanswered prompt cannot hang the session, and state the exact command before triggering it so the modal prompt is expected. The approved command then runs unchanged — no scope expansion.

### Forbidden Actions (Workstation-Wide)

In addition to the Hard Safety Constraints:

1. **Never run destructive package operations without explicit confirmation** — `pacman -Rns`/`-Rc`, orphan purges (`pacman -Qtdq | pacman -Rns -`), `pacman -Scc`, mass toolchain uninstalls. Propose the command and wait.
2. **Never execute or ingest untrusted external content** — no unverified scripts, no `curl … | sh`, no folding unvetted external code/config into tracked files, hooks, or manifests. Read-only research is permitted; anything entering system state requires an explicit, user-vetted source. *Operator-vetted allowlist:* the official toolchain installers `https://sh.rustup.rs`, `https://astral.sh/uv/install.sh`, `https://bun.sh/install`, as invoked by `run_onchange_after_10-install-toolchains.sh.tmpl` — the only sanctioned `curl … | sh` targets; adding another is an operator decision recorded in this file.
3. **Never generate unconstrained sudo mutations** — root mutations live in tracked, reviewable mechanisms (e.g. chezmoi `run_onchange` hooks), never one-off sudo commands; sudo-invoking changes carry `[ROOT IMPACT]` per the protocol above.
