---
tool: eza
binary: /usr/bin/eza
authoritative: eza --help
---

# eza

## Verified gotchas

- **In an agent shell, bare `eza` prints nothing and exits 0.** Piped (no TTY)
  instead of interactive, `eza` does not fall back to the current directory the
  way the operator's terminal makes it appear to: `eza -1` → 0 lines, exit 0,
  while `eza -1 .` lists normally. Always name the target (`eza .`,
  `eza --tree -L 2 .`) — otherwise a silent exit 0 reads as "empty directory".
  Verified: the identical bare command under a PTY (`script -qec`) does list the
  directory; `fd`, `rg` and `bat` are unaffected, so this is eza-specific.
- **`ls` is a Fish wrapper, and it injects ANSI into agent pipelines.** `ls` is
  not the binary but a function expanding to
  `eza -al --color=always --group-directories-first --icons=always`; it also
  inherits the missing-operand trap above (bare `ls` is equally silent). Piped,
  it emits hundreds of escape sequences (verified: 454 ESC bytes) that corrupt a
  stdout parser. Use `command ls` to reach the real binary (verified: 0 ESC
  bytes). Piped `eza` itself already auto-disables colour — the escapes come
  only from the wrapper's hard-coded `--color=always --icons=always`.
