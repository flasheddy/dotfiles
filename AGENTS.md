# AGENTS.md — Operational Rules for AI Agents

<!-- floor-contract: sha256:c8cc6975ecd639a665f9d349ad93a91277f38118327097f5c5f110bca70c1fd3 -->

Binding contract for AI agents (Antigravity CLI, OpenCode) in this repository.
Inherits the workstation-wide safety floor in `~/.AGENTS.md`.
Carries only non-obvious traps, verification gates, and mandatory workflows.

---

## 1. Repository Architecture & Constraints

### 1.1 Source-First Discipline

- This repo is the **chezmoi source state** (`~/.local/share/chezmoi`), not live `$HOME`.
- Changes here do not affect the system until `chezmoi apply`.
- Edits made directly to live files are overwritten on apply unless pulled first via `chezmoi re-add <file>`.

### 1.2 Package Layering & Manifests

- **System packages (`packages/`)**: Native official CachyOS/Arch repos only; feeds `pacman -S`.
- **Foreign packages (`archive/pacman-foreign.txt`)**: AUR packages belong exclusively here. Never place AUR packages in native `packages/*.txt` manifests (causes pacman failure).
- **Standalone toolchains (`toolchains/`)**: Upstream language installers (`cargo.txt`, `uv.txt`, `bun.txt`, `go.txt`, `local-bin.txt`).
- Manifest inventories and rules live in `packages/manifest.md`; do not duplicate them here.
- Syncthing sync configuration lives in `packages/manifest.md` → `## Syncthing (PC ↔ Android Sync)`.

### 1.3 Verification Gates

- Global pre-commit hook runs secret scan, floor freshness check, whitespace check, and markdown link verification.
- Pre-push hook dispatches to `just check` (the complete 4-stage gate: hygiene, lint, secrets, drift). Run `just check-fast` for parallel execution.

---

## 2. Operating Protocols

### 2.1 Preview Before Apply

Before modifying or applying managed state:

```fish
chezmoi status    # check uncommitted drift
chezmoi diff      # preview pending changes against live disk
```

Never overwrite unexpected live drift without operator confirmation.

### 2.2 Hook Template Safety (`run_onchange_*.sh.tmpl`)

Every hook runs with `set -euo pipefail` and root privileges (`sudo`):

1. **Strictly idempotent**: Guard all mutations with presence checks (`command -v`, `systemctl is-enabled`).
2. **Graceful degradation**: Append `|| true` on optional tool installs or user units.
3. **Template syntax verification**: Validate before committing:
   ```fish
   for f in run_onchange_*.sh.tmpl; chezmoi execute-template < "$f" | bash -n; end
   ```
4. Changes modifying sudo-invoking hooks require an explicit `[ROOT IMPACT]` disclosure.

### 2.3 Refinement & Maintenance Protocol

Run on request ("Refine & Reconcile"):

1. **Surface drift**: `chezmoi status` and `chezmoi diff`.
2. **Reconcile packages**: Native (`pacman -Qqen` vs `packages/`), AUR (`pacman -Qqem` vs `archive/pacman-foreign.txt`), and toolchains (`uv tool list`, `cargo install --list`, etc.). Stripping exceptions live in `packages/manifest.md` → `## Stripping Rules`.
3. **Safety**: No hardcoded `/home/username` paths (use `$HOME` or `{{ .chezmoi.homeDir }}`).
4. **Report-first**: Present findings (Critical / Missing / Polish); obtain confirmation before any mutation or removal.

### 2.4 Git Discipline & Operator Handoff

The Operator is the sole execution authority for Git writes; agents provide commands only.

1. **Unstaged review first**: Never stage or commit changes automatically. Leave modified files unstaged so the Operator can review with `git diff`.
2. **Read-only inspection**: Prefix git status with `env GIT_OPTIONAL_LOCKS=0 git status --short`.
3. **Short Conventional Commits**: Use `type(scope): subject` as a single, short sentence. Never emit multiline `-m` body blocks (avoids terminal copy-paste and line-wrapping errors). Scopes: `agents`, `aup`, `fcitx5`, `fish`, `git`, `helix`, `toolchains`.
4. **Feature branches & rebasing**: If on `main`, branch off first (`git checkout -b feat/<scope>`). Rebase feature branches against `main` before pushing. Inspect `git log` post-rebase and squash interim "wip" or "fixup" commits.
5. **No unsolicited PRs**: Never run or suggest `gh pr create` without being asked.
6. **Force-push safety**: Explicit confirmation required + `git push --force-with-lease`.

---

## 3. Forbidden Actions

Inherits workstation-wide forbidden actions in `~/.AGENTS.md`. Dotfiles-specific:

1. **Never track credentials or keys**: Only `private_dot_ssh/config` is tracked (its `.gitignore` excludes keys).
2. **Never track hardware `/etc` configs**: No `fstab`, `crypttab`, or NetworkManager configs. The only managed root file is `system/keyd/default.conf` (deployed via hook).
3. **Never run `chezmoi apply --force` or `chezmoi purge`** without explicit operator request.

---

## 4. Verification Checklist

After changes, run:

```fish
chezmoi status       # clean or expected drift only
chezmoi diff         # verify diff preview
just check           # full verification gate (hygiene, lint, secrets, drift)
git status --short   # clean working tree, no secrets staged
```
