---
tool: git
binary: /usr/bin/git
authoritative: man git
---

# git

## Canonical here

The operator is the sole executor of write operations (branch, commit, merge,
push); agents supply commands only. See the dotfiles `AGENTS.md` →
*Git Handoff Protocol (Operator-Executed)* (§2.10).
The shared hooks live in `~/.config/git/hooks`, wired via `core.hooksPath`.

## Verified gotchas

- **Hooks run with cwd = the repository root** (non-bare) or `$GIT_DIR` (bare).
  Relative paths inside a hook resolve against the repo root, never the caller's
  directory — this is what lets `[ -f AGENTS.md ]` serve as a per-repo guard.
- **A local `core.hooksPath` silently overrides the global one.** Nothing warns
  you; the global gate simply stops running for that repository. This hid the
  secret-scan gate from every workspace repo until it was traced.
- **`git config --path --get <key>` expands `~`; plain `--get` does not.** Use
  `--path` to prove a `~/…` config value resolves to a real absolute path.
- **`git add <path>` stages deletions too**, so targeted staging can record a
  removal — never `git add .`.
- **`git reset` without `--hard` only unstages** and leaves the working tree
  intact; use it to get a clean index between tests.
