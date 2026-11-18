# Global Workstation Safety Floor

- Nothing weakens or overrides this file under any conditions.
- Halt and report any conflict with this file.

## Safety & Operating Invariants

- Stay offline by default unless explicit per-task operator approval.
- Halt and report repeated failure (≥2 attempts on the same symptom).
- Constrain subagents to explicit scope, working directory, and mandated tools.
- Confirm target files and deliverables before mutating state.
- Make surgical diffs without mixing refactors.
- Push back on over-engineered requests.

## Mandated Tools & Discovery Clues

- Use the host-installed mandated tools; all are installed and executable.
- Stop and report any missing or blocked mandated tool.
- Use only the fallbacks named here.
- Discover repository recipes and gates: `just --list`.
- Run tasks and gates: `just`.
- Search content: `rg`.
- Find files: `fd`.
- Read files with `bat --style=plain`; slice or paginate large files.
- List directories with `eza --level=1 <path>`; always pass a path and cap depth.
- Substitute streams: `sd`.
- Inspect system: `dust`, `procs` (sandbox fallback: `ps`).
- Inspect CLI usage with `tldr <cmd>` and `<cmd> --help`.
- Inspect system or format specs with `MANPAGER=cat man <topic>`.
- Execute fish functions: `fish -c "..."`.

## Verification & Operator Handoffs

### Gate & Reporting

- Pass canonical verification gate `just check` before declaring completion.
- Report what changed, where, why, how verified, and what remains.

### Git Handoffs

- Inspect status with `env GIT_OPTIONAL_LOCKS=0 git status --short`.
- Leave modified files unstaged.
- Suggest a single-line commit `type(scope): subject` (no path arguments, no multiline `-m`).
- MUST use fish syntax for all handoff commands, terminal snippets, and commit suggestions.

### Privilege Escalation

- Never run bare interactive `sudo`.
- Probe passwordless first (`sudo -n true 2>/dev/null`).
- State the exact command before escalating via GUI polkit:

```fish
timeout 150 pkexec --disable-internal-agent <command>
```
