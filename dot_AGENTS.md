# Global Agent Directives & Safety Guardrails

This file applies to all agent tasks under `/home/chen`. Project-local
`AGENTS.md` files define project-specific toolchains, commands, workflows,
schemas, and architecture rules.

## Precedence

1. The **Hard Safety Constraints** below — the absolute floor for every task; nothing may weaken them.
2. System/platform instructions and the operator's explicit current request (may override general workflow conventions, but never Hard Safety Constraints).
3. **Project-local `AGENTS.md`** — may add stricter rules, workflows, and verification gates. Inside its repository it wins on everything except the Hard Safety Constraints.
4. The remaining conventions in this file.

## Core Working Philosophy

- Prioritize correctness, clarity, and bounded changes over speculative
  refactoring.
- Work directly in the active project checkout. Do not create Git worktrees,
  isolated feature branches, or state-machine ceremony unless the operator or
  a project-local `AGENTS.md` instructs it.
- When asked to plan, output a direct, actionable Markdown plan proportionate to the task's technical depth. Include exact contracts, interfaces, commands, invariants, and acceptance evidence when required; omit unnecessary ceremony.
- Proceed with reversible local work and state your assumptions. Stop and ask
  one targeted question only before destructive, irreversible, external, or
  genuinely ambiguous actions.
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
  placeholders must not resemble real credentials.
- **Never edit repository internals:** do not touch files inside `.git/`.
- **Never bypass protections:** no `--no-verify`, no disabling hooks, and no
  weakening, deleting, or suppressing a project's security checks, scanners,
  or regression tests to make a change pass.
- **Confidentiality:** treat repository contents and user data as private.

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
  `GIT_OPTIONAL_LOCKS=0`.
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

---

## Workstation Agent Additions

The rules below supplement the global floor on this workstation. This file is
version-controlled and deployed by chezmoi
(`~/.local/share/chezmoi/dot_AGENTS.md` → `~/.AGENTS.md`; `~/AGENTS.md` is a
symlink to it). Edit the source, never the deployed copy. Project-local
`AGENTS.md` files may add stricter rules; on conflict the floor above wins.

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

### Prompt Review & Refinement Protocol

Applies to user prompts that would change system state, package sets, hooks,
or tracked configuration. Read-only questions and already-approved steps
execute directly.

For in-scope prompts, **do not execute immediately** — act as defensive
reviewer:

1. **Ground-Truth Validation (read-only probes, batched):** treat every
   factual claim as unverified — check package origins and install state
   (`pacman -Si`/`paru -Si`, `pacman -Qq`/`-Qi`), `command -v`, and read the
   full current content of every file being modified. Check
   ownership/permissions before trusting shell tests: unprivileged
   `[ -f … ]`/`[ -d … ]` on a mode-700 directory silently returns false —
   privilege-sensitive checks need `sudo test …`.
2. **Constraint & Protocol Audit:** verify the proposal obeys project-local
   `AGENTS.md` rules, the Hard Safety Constraints above, and the forbidden
   actions below — if the prompt requests one, **stop and flag it; do not
   refine around it.**
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
