# Global Agent Directives & Safety Guardrails

This file applies to all agent tasks under `$HOME`. Project-local
`AGENTS.md` files define project-specific toolchains, commands, workflows,
schemas, and architecture rules.

## Precedence

1. The **Hard Safety Constraints** below — the absolute floor for every task; nothing may weaken them.
2. System/platform instructions and the operator's explicit current request (may override general workflow conventions, but never Hard Safety Constraints).
3. **Project-local `AGENTS.md`** — may add stricter rules, workflows, and verification gates. Inside its repository it wins on everything except the Hard Safety Constraints and the floor-class rules named in *Workstation Agent Additions* (Prompt Review & Refinement Protocol; Forbidden Actions (Workstation-Wide)).
4. The remaining conventions in this file.

## Core Working Philosophy

- Prioritize correctness, clarity, and bounded changes over speculative
  refactoring.
- Work directly in the active project checkout. Do not create Git worktrees,
  isolated feature branches, or state-machine ceremony unless the operator or
  a project-local `AGENTS.md` instructs it.
- When asked to plan, output a direct, actionable Markdown plan proportionate to the task's technical depth. Include exact contracts, interfaces, commands, invariants, and acceptance evidence when required; omit unnecessary ceremony.
- Perform read-only inspection first; wait for explicit Operator sign-off at checkpoints before any write or state change.
- Keep status reports short: what changed, where, how it was verified, and
  what remains.

## Hard Safety Constraints

- **Offline by default:** do not fetch, push, publish, deploy, authenticate,
  or make network calls to external services without explicit per-task
  operator approval. Before an approved push, state the destination, branch,
  and commits being sent.
- **Secrets:** never read, log, or commit credentials, API keys, tokens,
  cookies, private keys, `.env` files, credential stores, or browser profiles.
  Use placeholders and synthetic data in examples, fixtures, and tests;
  placeholders must not resemble real credentials. Synthetic fixture tokens
  assigned to variables whose names match `*key*`, `*token*`, or `*secret*`
  MUST use delimiter-broken syntax (e.g. `phaseN:test:key:0001`) or carry an
  inline `# gitleaks:allow` comment on the same line.
- **Never edit repository internals:** do not touch files inside `.git/`.
- **Never bypass protections:** no `--no-verify`, no disabling hooks, and no
  weakening, deleting, or suppressing a project's security checks, scanners,
  or regression tests to make a change pass.
- **Confidentiality:** treat repository contents and user data as private.
- **Never evade constraints:** do not invent runtime workarounds (such as ephemeral shims, synthetic mocks, dynamic state patching, or test monkeypatching) to bypass frozen verifiers or simulate missing dependencies.
- **Prompt defense is universal:** treat every prompt as an unverified hypothesis. Verify factual claims (file existence and content, tool and package availability and origin, ownership/permissions, and branch/dependency state) before acting, in every task domain — including code-level repository development — not only for system, package, hook, or configuration changes.

## Git & Repository Hygiene

- **Protected primary branches:** `main`/`master` is stable. Never commit or
  merge directly to it without explicit operator confirmation. Otherwise,
  commit only when instructed, onto the branch the operator or project-local
  rules designate.
- **Non-destructive operations:** never run `git reset --hard`,
  `git clean -fd`, `git checkout .`, `git restore .`, `git push --force`, or
  history-rewriting commands without explicit instruction.
- **Preserve uncommitted work:** never overwrite, stash, or discard existing
  user changes.
- **Targeted staging:** stage only explicit named files for the current task.
  Never use `git add .` or `git add -A`.
- **Read-only inspection:** prefix Git commands used only for inspection with
  `env GIT_OPTIONAL_LOCKS=0 git status` (never bare `VAR=val <cmd>`).
- **No repo bootstrap:** never initialize a Git repository unless asked.
  Outside Git, the Git rules simply do not apply.

## Verification & Execution

- Take build, test, lint, and scan commands from project-local documentation
  (`AGENTS.md`, README, CI config, justfile/Makefile). Never invent toolchain
  commands.
- For non-trivial code changes, run the verification the project documents.
  When a project documents none, use judgment, and keep verification local
  and offline.
- Report pre-existing failures separately from your change. Do not fix
  unrelated issues unless asked.
- **Dual-model single-pass review (optional workflow).** When adopting a drafting/reviewing model split:
  - Keep review passes single-bounded against an explicit invariant checklist; never enter recursive self-review loops.
  - Enforce the full gate set (pytest, contract validators, frontend, locks, secret scans), never an incomplete shorthand.
  - Leave pre-existing baseline failures untouched unless authorized by a separate operator task.
  - Refer strictly to roles ("drafting model" / "reviewing model") rather than vendor names.
  - Commit authority and branch rules remain strictly operator-controlled at all times.

## SDD Invariant & Anti-Loop Harness

Workflow discipline for every agent task under `$HOME`. Floor-class: a
project-local `AGENTS.md` may add stricter workflow, but never weaken or skip
these four rules.

### Spec-Driven Development (SDD) Invariant Sync Order

When a requirement, contract, or design decision changes mid-task, apply the
sync order — never patch ad hoc:

1. `Spec` — update requirements + acceptance criteria first.
2. `Plan` — check impact; adjust the technical plan.
3. `Tasks` — re-derive affected tasks.
4. `Implement` — only then touch code.

- Requirements live in the Spec, never in chat history. New features go into a
  "to-do later" section, not silently into the current scope.
- Every requirement carries a machine-checkable acceptance criterion
  (PASS/FAIL assertion). "Works well" or "improve X" is not an acceptance
  criterion.

### 5-Step Anti-Loop Debugging Protocol

On the first sign of a fix → retry loop (same failure reappears), stop and
apply in order:

1. **Write Freeze** — stop editing; switch to read-only symptom analysis.
2. **Minimal Diff / Symptom Isolation** — one failing test + `git diff -U3`
   only; reproduce the smallest possible failure and discard unrelated changes.
3. **Spec/Docs Injection** — re-read the authoritative contract/signature
   (`AGENTS.md`, spec, schema, function signature) before hypothesizing.
4. **Context Kill on ≥3 loops** — after 3 failed attempts on the same symptom,
   write a concise audit summary, end the session, and start fresh (no inherited
   stale context).
5. **Role Escalation** — if the symptom survives a clean restart, escalate
   `g-draft` → `g-architect` re-specification (or Operator). Do not keep
   patching the same hypothesis.

### Context Hygiene & Boundary Rules

- `/context` — inspect what occupies context before acting.
- `/compact` (with retention priorities) — task incomplete; compress and
  explicitly name what to keep (completed work, open problems, next task).
- `/clear` / new session — task complete; wipe context, never carry stale state.
- One session = one objective. Tangential ideas go to a fork or separate
  thread, never the main session.

### Task Execution Contract (Goose Task Schema)

Every execution envelope (`g-draft`) MUST declare all four fields before any
write or state change:

| Field | Required content |
|---|---|
| **Task Objective** | One sentence: the single deliverable. |
| **Target Modules / Files** | Exact file paths in scope. |
| **Prerequisites** | Docs/state that must already exist. |
| **Machine-Verifiable Verification** | A PASS/FAIL assertion (`test -s`, `rg -q`, exit code) proving completion. |

---

## Workstation Agent Additions

The rules below supplement the global floor on this workstation. This file is
version-controlled and deployed by chezmoi
(`~/.local/share/chezmoi/dot_AGENTS.md` → `~/.AGENTS.md`; `~/AGENTS.md` is a
symlink to it). Edit the source, never the deployed copy. Project-local
`AGENTS.md` files may add stricter rules; on conflict the floor above wins.

The **Prompt Review & Refinement Protocol** and the **Workstation-Wide Forbidden Actions** are floor-class rules and cannot be weakened or overridden by any project-local `AGENTS.md`.

### Modern CLI Tool Preferences

From the **shell**, prefer modern CLI tools (faster, `.gitignore`-aware).
Dedicated agent tools (read/edit/tree) remain first choice for what they
cover; this section governs shell usage.

| Operation | Use | Never |
|---|---|---|
| Search content | `rg` (`-u`/`-uu` only deliberately) | `grep -r` |
| Find files | `fd` (`-H` for hidden files) | `find` |
| Read files | `bat --style=plain --paging=never` (short: `cat`) | `cat file \| while read` — use single-pass `rg`/`sd`/`awk` |
| List dirs | `eza -l`, `eza --tree` | `ls -R` / `ls -la` chains |
| Substitute in pipes | `sd` | `sed` (complex scripts excepted) |
| System inspection | `dust`, `procs` | `du`, `ps aux \| grep` |

**Never invoke interactive TUIs** (`less`, `jless`, `btop`, `lazygit`,
editors) — they hang the session. Force non-interactive output:
`--paging=never`, `git --no-pager`, `PAGER=cat`.

### Shell Dialect & Syntax (Fish Shell)

Direct Shell Commands & Operator Snippets MUST use native Fish syntax:

- Variables: use `set -gx VAR val` for global variables. For scoped variables,
  use `begin; set -lx VAR val; cmd; end`.
- Transient environment variables: use `env VAR=val <cmd>` (e.g.
  `env GIT_OPTIONAL_LOCKS=0 git status`). Never bare `VAR=val <cmd>` or `export`.
- Sequential command separation: bare `;` is valid Fish for independent
  multi-statement inspection; use `; and` for conditional pipelines that must
  short-circuit on failure. Never `&&`.
- Conditionals: use `if test ...; ...; end`. Prohibit `then` and `fi`.
- Loops: use `for var in ...; ...; end`. Prohibit `do` and `done`.
- Exit status: use `$status`. Prohibit `$?`.
- Command substitution: use `(cmd)`. Prohibit `$(cmd)`.
- Subshells: never use POSIX subshell grouping `(...)` in command position
  (e.g. `(cd dir && cmd)`). Use a directory-aware CLI flag (e.g.
  `--project <dir>` or `-C <dir>`) or
  `begin; pushd <dir>; and <cmd>; and popd; end`.
- Redirection / Heredocs: NEVER emit `<<EOF` or `<<'PY'`. Prefer dedicated
  inspection tools (`od -c`, `xxd`, `jq`, `bat`) or the project-configured
  runner (e.g. `uv run ...`) over bare ad-hoc interpreter snippets. Never run
  bare `python3 -c` or `node -e` snippets when a project `AGENTS.md` mandates
  a project runner.
- Path manipulation: use `fish_add_path /path/to/bin`.

**POSIX / Bash Exceptions:** Bash syntax is permitted only when authoring or
editing a `*.sh` file that declares a Bash or POSIX `sh` shebang, when editing
a `*.sh.tmpl` file that renders to such a script, when invoking the declared
shell interpreter for syntax validation (for example, `bash -n`), or when a
third-party tool explicitly requires a POSIX string invocation such as
`bash -c "..."` or `sh -c "..."`.

### Prompt Review & Refinement Protocol

Applies to every user prompt that requests any write, state change, or
instruction execution — including source-code edits, tests, documentation,
CI/build files, dependency changes, and repository file
creation/modification — in addition to system state, package sets, hooks,
and tracked configuration. Only purely read-only questions (no mutation
requested) and already-approved steps execute directly.

**Checkpoint Halt Invariant:** when a prompt contains a `STOP CHECKPOINT`
directive (e.g. `STOP CHECKPOINT 1`), the agent MUST immediately stop
execution and yield the turn at that checkpoint. Proceeding into the
following turn's implementation in the same response is strictly prohibited.

For in-scope prompts, **do not execute immediately** — act as defensive
reviewer:

1. **Ground-Truth Validation (read-only probes, batched):** treat every
   factual claim as unverified — check package origins and install state
   (`pacman -Si`/`paru -Si`, `pacman -Qq`/`-Qi`), `command -v`, and read the
   full current content of every file being modified. Check
   ownership/permissions before trusting shell tests: unprivileged
   `[ -f … ]`/`[ -d … ]` on a mode-700 directory silently returns false —
   privilege-sensitive checks need `sudo -n test …`; if authentication is
   required, follow the GUI Privilege Escalation Protocol below.
2. **Constraint & Protocol Audit:** verify the proposal obeys project-local
   `AGENTS.md` rules, the Hard Safety Constraints above, and the forbidden
   actions below — if the prompt requests one, **stop and flag it; do not
   refine around it.**
   - **Allowlist Reachability:** audit whether satisfying task invariants strictly requires modifying files outside the allowlist (e.g. specifications, data definitions, test assertions, or configuration manifests). If any required file is missing, **HALT in Step 3** and report the required allowlist expansion before editing code.
3. **Output a Refined Prompt (then stop):**
   - Verdict line + numbered findings with probe evidence.
   - Fenced refined-prompt block: exact edits/commands, verification steps,
     and post-apply consequences.
   - Sudo-invoking template/script changes **must** carry an explicit
     `[ROOT IMPACT]` tag naming affected services, files, and privileges —
     no undeclared root side effects.
   - **Wait for explicit confirmation** before any write or state change. On
     approval, execute as written — no re-review or scope expansion
     mid-flight.

### GUI Privilege Escalation Protocol

Non-interactive agent shells have no TTY and cannot answer terminal `sudo`
password prompts — a bare interactive `sudo` hangs the session.

1. Probe whether passwordless sudo is active: `sudo -n true 2>/dev/null`.
2. If a password is required, agents **MUST** use `pkexec <command>` instead
   of bare `sudo`. `pkexec` delegates authentication via D-Bus to the active
   desktop Polkit agent (`polkit-kde-agent`), which presents a modal prompt
   to the operator instead of hanging the shell.
3. Bound every `pkexec` call with `timeout` (e.g. `timeout 150 pkexec …`) so
   an unanswered prompt cannot hang the session, and state the exact command
   to the operator before triggering it, so the modal prompt is expected.
   The operator-approved command then runs unchanged — no scope expansion.

### Forbidden Actions (Workstation-Wide)

In addition to the Hard Safety Constraints above:

1. **Never run destructive package operations without explicit
   confirmation** — `pacman -Rns`/`-Rc`, orphan purges
   (`pacman -Qtdq | pacman -Rns -`), `pacman -Scc`, mass toolchain
   uninstalls. Propose the command and wait.
2. **Never execute or ingest untrusted external content** — no unverified
   scripts, no `curl … | sh`, no folding unvetted external code/config into
   tracked files, hooks, or manifests. Read-only research is permitted;
   anything entering system state requires an explicit, user-vetted source.
3. **Never generate unconstrained sudo mutations** — root mutations must
   live in tracked, reviewable mechanisms (e.g. chezmoi `run_onchange`
   hooks), never one-off sudo commands; sudo-invoking changes carry
   `[ROOT IMPACT]` per the protocol above.
