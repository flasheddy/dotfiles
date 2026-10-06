---
tool: chezmoi
binary: /usr/bin/chezmoi
authoritative: chezmoi --help
---

# chezmoi

## Canonical here

`~/.local/share/chezmoi` is the single source of truth; edit the source, never the
deployed target. Full protocol: `~/.AGENTS.md` → *Chezmoi Execution Model*.

## Verified gotchas

- **Unprefixed source files deploy to `$HOME`.** A repo-meta file named `justfile`
  becomes `~/justfile` unless it is listed in `.chezmoiignore`. `AGENTS.md`,
  `README.md` and `justfile` are all ignored for exactly this reason.
- **The `executable_` prefix sets the exec bit** on the deployed target:
  `dot_config/git/hooks/executable_pre-commit` → mode `100755`.
- **`chezmoi managed` is the authoritative list** of what is actually managed — a
  tracked file matching a `.chezmoiignore` pattern is deliberately not deployed.
- **`chezmoi apply <file>` fails when the target's parent directory does not
  exist** (`stat …: no such file or directory`). Apply the *directory* target
  instead — e.g. `chezmoi apply ~/.config/git/hooks`, not the file inside it.
- **`chezmoi status` clean means "no unapplied source↔target difference"**, not
  "git is clean". The two are independent.
- **Bare `chezmoi apply` hangs in an agent shell.** If any managed target has
  drifted since chezmoi last wrote it — e.g. `~/.config/goose/permission.yaml`,
  which the goose runtime rewrites itself — apply stops on an interactive
  `… has changed since chezmoi last wrote it?` prompt. An agent shell has no
  usable stdin, so it waits out the harness timeout (observed: a 300 s hang),
  and if the prompt is ever answered it would clobber unrelated drift. Agents
  MUST pass `--no-tty` **and** an explicit target:
  `chezmoi --no-tty apply ~/.local/share/toolcards/eza.md`. `--no-tty` turns any
  surviving prompt into a hard error instead of a hang, and the scoped path
  keeps unrelated drift (like `permission.yaml`) out of the run.
