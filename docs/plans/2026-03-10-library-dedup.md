# Library Deduplication Design

**Status:** Design — implementation deferred to Milestone 2
**Created:** 2026-03-10
**Context:** Milestone 1 criterion #9 (library dedup design doc)

## Problem

The PAS plugin ships library skills at `plugins/pas/library/`. When a user runs `/pas` for the first time, these are copied to the project's `library/` directory. On the dev branch, both copies exist and must be kept in sync manually. This creates:

1. **Drift risk**: edits to one copy don't propagate to the other
2. **PR noise**: library mirrors show up in diffs
3. **Maintenance burden**: every plugin change that touches library/ requires a manual sync step

## Current State

- `plugins/pas/library/` — authoritative source (ships with plugin)
- `library/` — project-local bootstrap copy (created by first-run detection in `/pas`)
- `plugins/pas/library/orchestration/lifecycle.md` was extracted in cycle 9 (Milestone 1)
- Four orchestration patterns exist in both locations
- `self-evaluation/SKILL.md` exists in both locations

## Design Options

### Option A: `${CLAUDE_PLUGIN_ROOT}` Resolution (Recommended)

Claude Code supports `${CLAUDE_PLUGIN_ROOT}` in skill paths, confirmed working as of v2.1.69. Instead of copying library skills to the project, reference them directly from the plugin:

**Thin launcher change:**
```
Read `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md`
```

**Pros:**
- Zero drift — single source of truth
- No sync step needed
- Smaller project footprint

**Cons:**
- Project depends on plugin being installed (already true for hooks)
- `${CLAUDE_PLUGIN_ROOT}` only works in skill files, not in arbitrary bash scripts
- Orchestration patterns referenced by name in process.md need path resolution

**Migration:** Update thin launchers and orchestration patterns to use `${CLAUDE_PLUGIN_ROOT}`. Remove `library/` bootstrap step from first-run detection. Keep `library/` for user-customized skills that override plugin defaults.

### Option B: Symlinks

Replace `library/` with symlinks to `plugins/pas/library/`.

**Pros:** Simple, familiar
**Cons:** Platform-dependent, git tracks symlinks differently, breaks if plugin path changes

### Option C: Sync Script

A `pas-sync-library.sh` script that copies from plugin to project.

**Pros:** Explicit, auditable
**Cons:** Still requires manual execution, doesn't solve the fundamental duplication

## Recommendation

**Option A** with a fallback: use `${CLAUDE_PLUGIN_ROOT}` for all library references in generated files. Keep the first-run `library/` copy as a fallback for environments where the plugin variable isn't available. Add a `library/README.md` noting these are bootstrap copies and the plugin is authoritative.

## Implementation Steps (Milestone 2)

1. Update `pas-create-process` to use `${CLAUDE_PLUGIN_ROOT}/library/` in generated thin launchers
2. Update orchestration pattern references in generated process.md
3. Update first-run detection to skip library copy if `${CLAUDE_PLUGIN_ROOT}` is available
4. Add `library/README.md` documenting the bootstrap nature
5. Test: generate a process, verify it reads from plugin library
6. Test: remove plugin, verify fallback to local library works

## Open Questions

- Should user-customized library skills (overrides) live in `library/` or a separate `library-overrides/`?
- Should the sync script (Option C) exist as a safety net even with Option A?
