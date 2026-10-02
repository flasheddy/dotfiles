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
- **Local execution is pre-approved; capability changes are not.** The deployed
  posture (`dot_config/goose/private_permission.yaml` →
  `~/.config/goose/permission.yaml`) puts `shell`, `edit`, `write`, `read_image`
  in `always_allow` alongside the read-only tools, so routine local work never
  prompts. `extensionmanager__manage_extensions` stays in `ask_before`; `apps__*`
  and `orchestrator__send_message`/`orchestrator__start_agent` stay in
  `never_allow` (blocked, not merely gated). The `just check-permissions` gate
  (`permissions-no-auto-allow`) now guards only capability-changing tools —
  moving `manage_extensions` into `always_allow` fails the build.

## Verified gotchas

- **goose rewrites `permission.yaml` itself at runtime.** The live file is
  re-sorted and the `user` scope's `always_allow` is mutated, so `chezmoi status`
  turns dirty mid-session and `chezmoi apply` then prompts
  (`diff/overwrite/all-overwrite/skip/quit`). Reconcile with `chezmoi re-add`.
  (Verified 2026-10-02: the live file changed again ~5 min after `re-add` had
  made it byte-identical to the source.)
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
