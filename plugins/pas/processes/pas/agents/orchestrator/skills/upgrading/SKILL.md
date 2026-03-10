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

### 1. Config location

- **Expected:** `.pas/config.yaml` exists
- **Legacy:** `pas-config.yaml` at project root (no `.pas/` directory)
- **Fix:** Create `.pas/` directory, move `pas-config.yaml` to `.pas/config.yaml`

### 2. Workspace location

- **Expected:** `.pas/workspace/` exists
- **Legacy:** `workspace/` at project root
- **Fix:** Move `workspace/` to `.pas/workspace/`

### 3. Processes location

- **Expected:** `.pas/processes/` contains process definitions
- **Legacy:** `processes/` at project root
- **Fix:** Move `processes/` to `.pas/processes/`

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
