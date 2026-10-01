---
tool: goose
binary: /home/chen/.local/bin/goose
authoritative: https://goose-docs.ai
---

# goose

## Canonical here

- **Tripartite subagents are bundled in the `summon` extension.** `architect`,
  `g-draft`, `g-audit-a`, `g-audit-b`, and `g-flash` come from `summon` (invoked
  via `delegate`/`load`). They are *not* defined as local files — there is no
  `~/.config/goose/agents/` directory. Do not go looking for agent YAML/JSON.
- **Custom slash commands are recipe aliases.** `~/.config/goose/config.yaml`
  `slash_commands:` maps `command` → `recipe_path` (a `.yaml`/`.json` recipe).
- **Recipe storage locations:** global `~/.config/goose/recipes/`, project-local
  `./.goose/recipes/`, or any dir in `GOOSE_RECIPE_PATH`.

## Verified gotchas

- **`manage_extensions` is session-scoped — it does NOT persist to `config.yaml`.**
  To make enable/disable permanent, edit
  `~/.config/goose/config.yaml` → `extensions.<name>.enabled`, then `chezmoi apply`.
  (Verified: config.yaml mtime was unchanged after a `manage_extensions` disable.)
- **`memory`, `chatrecall`, `tom`, `scheduler` are invariant-pinned to
  `enabled: false`.** The dotfiles `just check` gate fails the build if any is
  flipped on (ephemeral-session / state-on-disk invariants).
- **Recipe files must be `.yaml` (or `.json`), never `.yml`** — goose CLI does
  not support `.yml`.
- **A recipe requires** `title` + `description` + at least one of `instructions`
  or `prompt`.
- **Slash-command names** must be unique, contain no spaces, and not collide with
  built-ins (`/compact`, `/help`, …). They are case-insensitive.
- **Slash commands accept exactly one parameter**; extra recipe parameters need
  defaults.
