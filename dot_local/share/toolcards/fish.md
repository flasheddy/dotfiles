---
tool: fish
binary: /usr/bin/fish
authoritative: man fish
---

# fish

## Canonical here

Shell dialect for every command and snippet on this workstation. The syntax rules
themselves live in `~/.AGENTS.md` → *Shell Dialect & Syntax (Fish Shell)* and are
not restated here.

## Verified gotchas

- **Command substitution splits on newlines and drops empty elements.**
  `set x (cmd)` yields a *list*, not a string. When the value must stay one
  string — whole-file content especially — use `set x (cmd | string collect)`.
  *Cost:* `floor-stamp` compared a list against a string, so the equality test was
  never true; it rewrote an already-correct file on every run while reporting
  "refreshed". Caught only by a sha256 byte-identity check.
- **`printf` does not accept `--` as an option terminator.** Fish's `printf`
  treats the first argument as the format string, so `printf -- 'x\n'` prints
  `--` and discards the real format entirely. Use `printf 'x\n'`, with no `--`.
  *Cost:* a test fixture written with `printf --` contained only `--`, which made
  a **correct** validator look broken. The probe was at fault, not the check.
- **`path basename` takes no suffix argument.** Strip an extension with
  `string replace -r '\.md$' '' (path basename $c)`.
- **An unmatched glob is passed through literally**, so `ls $dir/*.md` on an empty
  directory fails complaining about the pattern itself. Test the first element
  with `test -f $cards[1]` instead.
- **`$$` does not exist** (`$$ is not the pid`); use `$fish_pid`. A stray `$$`
  anywhere aborts parsing of the whole command before anything runs.
