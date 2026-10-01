---
tool: bash
binary: /usr/bin/bash
authoritative: man bash
---

# bash

## Canonical here

Used only for `*.sh` files and the git hooks deployed to `~/.config/git/hooks/`.
Fish is the dialect everywhere else.

## Verified gotchas

- **`set -e` plus command substitution needs `|| true`.** A pipeline that
  legitimately matches nothing (`rg` exits 1, `head` on an empty stream) returns
  non-zero, and inside `$( … )` that aborts the entire script. Append `|| true`
  whenever "no match" is a normal outcome, not a failure.
- **Process substitution `< <(...)` does not trip `set -e`** — a command failing
  inside it fails silently. Check its result explicitly if it matters.
- **`[[ "$x" =~ ^#{2,6}[[:space:]] ]]` is ERE**, so `{2,6}` quantifies the
  preceding `#` — that is how "two or more hashes" is expressed.
- **`${var,,}` lowercases** (bash 4+); `$(printf '%.12s' "$var")` truncates a hash
  safely for display.
- **`[ -x "$p" ]` tests executability**; `[ -e "$p" ]` only tests existence. The
  tool-card validator needs the former for its `binary:` field.
