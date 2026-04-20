---
name: upgrading
description: Scan a PAS project and fix any gaps between its current state and what the installed plugin version expects.
---

# Upgrading PAS Projects

Declarative upgrade: define what PAS expects, scan the project, fix gaps. No version tracking needed — just "does your setup match what the current plugin expects?"

## When to Use

- User says "upgrade", "update", "migrate", or "what's new"
- User reports errors that suggest outdated project layout
- After a PAS plugin update

## Expected State Checklist

The current PAS plugin expects these conditions. Each item has a check and a fix.

### 1. Consumer layout (PAS ≥ 1.4.0 — marketplace-authoritative)

- **Expected (consumer project):** ONLY `.pas/workspace/` exists. No `.pas/config.yaml`, no `.pas/processes/`, no `.pas/library/`. Feedback defaults read from the plugin-level `${CLAUDE_PLUGIN_ROOT}/pas-config.yaml`.
- **Legacy (PAS ≤ 1.3.x consumer):** `.pas/config.yaml` + possibly `.pas/processes/` with old process copies.
- **Fix:** Preserve `.pas/config.yaml` (backward-compat still honored), but delete `.pas/processes/` / `.pas/library/` if they shadow skills that now come from an installed plugin. Back up first. Verify each process: if the plugin marketplace ships the same process, delete the consumer copy.

### 2. Workspace location (unchanged)

- **Expected:** `.pas/workspace/` exists and contains execution state.
- **Legacy:** `workspace/` at project root.
- **Fix:** Move `workspace/` to `.pas/workspace/`.

### 3. Marketplace context (new)

- **Expected (maintainer workflow):** When running `/pas:pas`, cwd is inside a marketplace repository (has `.claude-plugin/marketplace.json` at its root).
- **Legacy:** cwd is inside a consumer project — PAS-the-skill refuses to run (use `/pas:pas` from inside your marketplace instead; hooks still route feedback from anywhere).
- **Fix:** Either cd to your marketplace, or invoke the `bootstrap-marketplace` skill to scaffold one.

### 4. No local library copy

- **Expected:** No `.pas/library/` directory (processes reference `${CLAUDE_PLUGIN_ROOT}/library/` directly)
- **Legacy:** `.pas/library/` or `library/` with copied plugin skills
- **Fix:** Update thin launchers and process lifecycle sections to use `${CLAUDE_PLUGIN_ROOT}/library/`, then remove the local library copy. Back up to `.pas/library.bak/` before deleting.

### 5. Thin launcher references

- **Expected:** `.claude/skills/*/SKILL.md` files reference `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` for lifecycle and patterns
- **Legacy:** References to `.pas/library/orchestration/` or `library/orchestration/`
- **Fix:** Find and replace old library paths with `${CLAUDE_PLUGIN_ROOT}/library/` in each thin launcher

### 6. Process lifecycle references

- **Expected:** `process.md` lifecycle sections reference `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md`
- **Legacy:** References to `.pas/library/orchestration/lifecycle.md`
- **Fix:** Find and replace in each `process.md`

## Workflow

1. **Scan** — Check each item in the checklist against the project
2. **Report** — Show a table: item, status (OK/NEEDS FIX), what will change
3. **Confirm** — Ask user: "Apply these fixes?" (never auto-apply without confirmation)
4. **Back up** — Before modifying, copy affected files/dirs to `.bak` suffixed locations
5. **Apply** — Execute fixes in checklist order
6. **Verify** — Re-scan to confirm all items now pass
7. **Report** — Show final status: what changed, what was backed up

## Key Principles

- Non-destructive: always back up before modifying
- Idempotent: running upgrade twice produces no changes the second time
- User confirms before any modifications
- Show before/after for each change
