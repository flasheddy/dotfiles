---
tool: just
binary: /usr/bin/just
authoritative: just --help
---

# just

## Canonical here

`just check` is the single uniform full-gate entry point across repositories; the
global `pre-push` hook dispatches to it. Contract and guards: dotfiles README →
*Repository Enforcement*.

## Verified gotchas

- **Each recipe line runs in its own shell** (`sh -c` by default). Anything
  multi-line, stateful, or dialect-specific needs a *shebang recipe* — first body
  line `#!/usr/bin/env fish` — which runs the whole body as one script.
- **Recipe bodies are tab-indented.** just 1.58 happened to tolerate space
  indentation during testing; do not rely on it. `unexpand -t 4` converts safely.
- **A recipe's doc comment is the comment line immediately above it.** A
  multi-line comment block exposes only its last line in `just --list`.
- **`just --dry-run <recipe>` prints what would run without executing it** — the
  cheap way to prove an adapter resolves before trusting it.
- **Recipe names are matched exactly**, so `check` is not confused with
  `check-partial`. That is why a partial gate must not be named `check`.
