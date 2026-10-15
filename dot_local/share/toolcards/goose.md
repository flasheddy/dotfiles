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
- **Local execution is pre-approved; capability changes are not.** The canonical
  posture (`dot_config/goose/private_permission.yaml` — tracked, **not** deployed;
  goose owns the live `~/.config/goose/permission.yaml`) puts `shell`, `edit`, `write`,
  `read_image` in `always_allow` alongside the read-only tools, so routine local work
  never prompts. `extensionmanager__manage_extensions` stays in `ask_before`; `apps__*`
  and `orchestrator__send_message`/`orchestrator__start_agent` stay in
  `never_allow` (blocked, not merely gated). The `just check-permissions` gate
  (`permissions-no-auto-allow`) now guards only capability-changing tools —
  moving `manage_extensions` into `always_allow` fails the build.

## Verified gotchas

- **goose rewrites `permission.yaml` itself at runtime — the live file is NOT
  chezmoi-managed** (`.chezmoiignore` → `.config/goose/permission.yaml`; tracked
  source stays as the `just check-permissions` input and the fresh-machine
  reference). The live file loses the comment block and the active mode's scope
  key is repartitioned: verified 2026-10-15, `smart_approve` moved `edit`,
  `read_image`, `shell`, `todo__todo_write` and `write` into `ask_before` while
  the `user` scope survived byte-identical; an earlier 2026-10-02 run mutated the
  `user` scope's `always_allow` instead. So the rewrite is not merely a re-sort —
  never `chezmoi re-add` it and never re-manage it. Two-writer proof:
  `chezmoi state dump` (entryState) records the **source** hash
  (`719429a1…`), the live file carries a different hash (`d55fab34…`) and an
  mtime inside the running session.
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
