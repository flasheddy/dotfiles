---
name: toolcards
description: Local, zero-duplication tool reference for this workstation. Query with `toolcard <tool>` before running unfamiliar, version-sensitive, or previously-failed commands. Cards hold only what cannot be derived — conventions and empirically verified gotchas — never restatements of man pages or --help.
---

# toolcards

One card per tool at `~/.local/share/toolcards/<tool>.md`, tracked in the chezmoi
dotfiles repository and deployed to `$HOME`.

## Scope — what is, and is not, in here

**Derived facts are never stored.** For anything a command can answer, ask the
command: `man <tool>`, `<tool> --help`, `<tool> --version`, `tldr <tool>`,
`pacman -Qi <pkg>`. Those are local, offline, and matched to the installed
binary. A card that restated them would be a copy that drifts.

**Cards hold only what cannot be derived:** workstation conventions and
empirically verified gotchas — each one paid for with a real failure.

## Query protocol

1. `toolcard --list` — see which cards exist.
2. `toolcard <tool>` — read one.
3. If it exits non-zero there is no card. Fall back to `man`/`--help`, and **say
   so** — never invent a flag, path, or behaviour that no card states.
4. `toolcard --validate` checks the cards' own schema and is wired into this
   repository's `just check`.

## How a card earns its place

A gotcha is recorded only after it has been reproduced, in line with the
Red-Green rule in `~/.AGENTS.md` → *Red-Green Verification*. If the failure
cannot be shown, the card is not written.

Each card carries frontmatter that is mechanically checked:

```yaml
---
tool: <name>              # must match the filename stem
binary: /usr/bin/<name>   # must exist and be executable
authoritative: man <name> # the command that answers derived questions
---
```

No version field, deliberately: it is derivable, and it is the one field
guaranteed to rot.
