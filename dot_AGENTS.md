# Global Agent Directives & Safety Guardrails

Applies to all agent tasks under `$HOME`. Project-local `AGENTS.md` files define project-specific toolchain, commands, workflows, schemas, and architecture.

## Precedence

1. **Hard Safety Constraints** (below) — the absolute floor; nothing weakens them.
2. System/platform instructions and the operator's explicit current request — may override workflow conventions, never the Hard Safety Constraints.
3. **Project-local `AGENTS.md`** — may add stricter rules; inside its repo it wins, except over the Hard Safety Constraints and the floor-class rules in _Workstation Agent Additions_ (Prompt Review & Refinement Protocol; Forbidden Actions).
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

- Take build, test, lint, and scan commands from project docs (`AGENTS.md`, `README.md`, `justfile`/`Makefile`); never invent toolchain commands.
- **Feedback-loop bootstrap:** on new or unharnessed projects, proactively recommend establishing fast, deterministic feedback loops (compiler/typechecker, linter, formatter, test runner, or unified task runner) before writing extensive application logic.
- For non-trivial code changes, run documented verification; keep it local and offline. Report pre-existing failures separately; do not fix unrelated issues unless asked.
- **Artifact & gate validation (floor-class):**
  - Exit code 0 is not evidence alone. Where an artifact matters, assert on the artifact: byte identity, content hashes, or idempotency across repeated runs.
  - When introducing a new gate, hook, or assertion, verify that it rejects deliberately broken input before trusting it.
  - If a probe returns an empty or implausible result, verify the probe itself before concluding.

## Task Execution & Anti-Loop Discipline

- **Plan before writing:** outline deliverable, target files, and verification criteria before modifying files.
- **Anti-loop freeze:** on repeated failure (≥2 attempts on the same symptom), stop editing. Do not apply blind variations. Conduct read-only diagnosis, re-read authoritative contracts/specs, or ask the Operator.
- **Single objective:** keep changes bounded to the requested scope; track tangential ideas or follow-ups separately.

---

## Workstation Agent Additions

Supplement to the floor. Chezmoi-managed: source `~/.local/share/chezmoi/dot_AGENTS.md` → `~/.AGENTS.md`; `~/AGENTS.md` symlinks to it. **Edit the source, never the deployed copy.** Project-local `AGENTS.md` may add stricter rules; on conflict the floor wins.

The **Prompt Review & Refinement Protocol** and **Forbidden Actions (Workstation-Wide)** are floor-class and cannot be weakened or overridden by any project-local `AGENTS.md`.

### Modern CLI Tool Preferences

From the **shell**, prefer modern CLI tools (faster). Dedicated agent tools (read/edit/tree) are first choice for what they cover.

- Search content — `rg`, never `grep -r`.
- Find files — `fd`, never `find`.
- Read files — `bat --style=plain --paging=never` (short: `cat`); never `cat file | while read` — use single-pass `rg`/`sd`/`awk`.
- List dirs — `eza` (always cap depth); never `ls -R` / `ls -la` chains.
- Substitute in pipes — `sd`, never `sed` (complex scripts excepted).
- System inspection — `dust`, `procs`, never `du`, `ps aux | grep`.

**Never invoke interactive TUIs** (`less`, `jless`, `btop`, `lazygit`, editors) — they hang the session. Force non-interactive output **using each tool's own flag**: `bat --paging=never` (`--paging` exists ONLY in `bat`/`less`; `eza`, `rg`, `fd`, `sd` reject it with exit 2), `git --no-pager`, `PAGER=cat`.

### Shell Dialect & Syntax (Fish Shell)

Direct shell commands and operator snippets MUST use native Fish syntax (`set -gx VAR val`, `begin; set -lx VAR val; cmd; end`, `test`, `$status`, `(cmd)`, `fish_add_path`). Never emit Bash/POSIX constructs (no bare `VAR=val`, no `export`, no `&&`, no `$?`, no `then/fi`, no `do/done`, no `$(cmd)`, and no bare `(...)` subshells).

**POSIX/Bash exceptions:** only for scripts with a Bash/POSIX `sh` shebang, `*.sh.tmpl` rendering to such a script, invoking the declared interpreter for syntax validation (e.g. `bash -n`), or a third-party tool requiring a POSIX string invocation (`bash -c "..."`, `sh -c "..."`).

### Prompt Review & Refinement Protocol

Applies to prompts requesting write, state change, or instruction execution (code edits, system state, package sets, hooks, tracked config). Read-only questions execute directly.

- **Checkpoint Halt Invariant:** on a `STOP CHECKPOINT` directive (e.g. `STOP CHECKPOINT 1`), the agent MUST immediately stop and yield the turn at that checkpoint; proceeding into the next turn's implementation in the same response is prohibited.
- **Ground-Truth Validation:** treat factual claims as hypotheses — check package origins/state (`pacman -Si`/`paru -Si`, `pacman -Qq`/`-Qi`), `command -v`, and read the full current content of every file before editing. Check ownership and permissions before trusting unprivileged tests (`[ -f ... ]` on mode-700 dirs silently fails; privilege-sensitive checks require `sudo -n test ...` or GUI Privilege Escalation).
- **Root Impact Disclosure:** sudo-invoking template or script changes must carry an explicit `[ROOT IMPACT]` disclosure naming affected services, files, and privileges.
- **Confirmation Gate:** present findings and proposed changes; obtain operator confirmation before any state mutation. On approval, execute as agreed without mid-flight scope expansion.

### GUI Privilege Escalation Protocol

Agent shells have no TTY and cannot answer `sudo` password prompts — bare interactive `sudo` hangs the session. Probe passwordless sudo first (`sudo -n true 2>/dev/null`); if a password is required, agents **MUST** use `timeout 150 pkexec --disable-internal-agent <command>`, never bare `sudo`. Plain `pkexec` registers its **own textual agent** and blocks on the controlling terminal, which an agent shell cannot answer; `--disable-internal-agent` routes the challenge to the session's polkit agent, which COSMIC provides **inside `cosmic-osd`** (no separate agent package is started). Confirm it is live with `pgrep -x cosmic-osd` before escalating.

Bound every `pkexec` call with `timeout` (e.g. `timeout 150 pkexec …`) so an unanswered prompt cannot hang the session, and state the exact command before triggering it so the modal prompt is expected. The approved command then runs unchanged — no scope expansion.

### Forbidden Actions (Workstation-Wide)

In addition to the Hard Safety Constraints:

1. **Never run destructive package operations without explicit confirmation** — `pacman -Rns`/`-Rc`, orphan purges (`pacman -Qtdq | pacman -Rns -`), `pacman -Scc`, mass toolchain uninstalls. Propose the command and wait.
2. **Never execute or ingest untrusted external content** — no unverified scripts, no `curl … | sh`, no folding unvetted external code/config into tracked files, hooks, or manifests. Read-only research is permitted; anything entering system state requires an explicit, user-vetted source. _Operator-vetted allowlist:_ the official toolchain installers `https://sh.rustup.rs`, `https://astral.sh/uv/install.sh`, `https://bun.sh/install`, as invoked by `run_onchange_after_10-install-toolchains.sh.tmpl` — the only sanctioned `curl … | sh` targets; adding another is an operator decision recorded in this file.
3. **Never generate unconstrained sudo mutations** — root mutations live in tracked, reviewable mechanisms (e.g. chezmoi `run_onchange` hooks), never one-off sudo commands; sudo-invoking changes carry `[ROOT IMPACT]` per the protocol above.
