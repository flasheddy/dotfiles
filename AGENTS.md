# AGENTS.md — Operational Rules for AI Agents

Chezmoi source state (`~/.local/share/chezmoi`) managing workstation dotfiles and system packages.

## Source Discipline & Traps

- Edits in source state do not affect the system until `chezmoi apply`.
- Never overwrite live drift; inspect divergence with `chezmoi diff`.
- Never run `chezmoi apply --force` or `chezmoi purge`.
- Never hardcode `/home/username` paths (use `$HOME` or `{{ .chezmoi.homeDir }}`).
- Never track hardware `/etc` configs (`fstab`, `crypttab`, NetworkManager).
- Deploy managed root configs exclusively via root hooks.

## Package Layering (`packages/`)

- Declare official CachyOS/Arch packages in `packages/*.txt`.
- Declare AUR packages exclusively in `archive/pacman-foreign.txt` (never in `packages/*.txt`).
- Declare standalone toolchains in `toolchains/` (`cargo.txt`, `uv.txt`, `bun.txt`, `go.txt`).
- Document package policies and sync configuration in `packages/manifest.md`.

## Root Hooks (`run_onchange_*.sh.tmpl`)

- Guard all mutations with presence checks (`command -v`, `systemctl is-enabled`).
- Require explicit `[ROOT IMPACT]` disclosure for sudo-invoking hooks (naming affected services, files, and privileges).

## Verification

### In-Repo Agent Gate (Pre-apply)

Run fast parallel static verification before presenting changes:

```fish
just check-source
```

### Operator Host Gate (Post-apply)

Execute post-apply verification after operator applies changes live:

```fish
chezmoi diff
chezmoi apply
just check
```
