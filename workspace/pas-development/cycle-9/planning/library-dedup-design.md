# Library Dedup Design

## Problem

PAS uses a copy-on-bootstrap model: first-run detection (`plugins/pas/skills/pas/SKILL.md` lines 31-35) copies library skills from the plugin to the project's `library/` directory. After that, the copies diverge. The plugin copy is canonical, but user processes reference the project copy.

**Evidence of drift:** `library/visualize-process/feedback/backlog/` has 2 feedback files not in the plugin copy. The architecture guarantees this gets worse over time.

**Impact:** Plugin upgrades silently conflict with local modifications. Users who customize library skills lose changes on upgrade. Every fix must be applied to both `plugins/pas/library/` and `library/`.

## Current State

### How library references work today

1. **First-run detection** (`SKILL.md` line 32-33): copies `self-evaluation/`, `message-routing/`, `orchestration/` from plugin to project `library/`
2. **Agent definitions** (e.g., `agents/orchestrator/agent.md`): reference `library/self-evaluation/SKILL.md` (project-level path)
3. **Orchestration patterns**: reference `library/orchestration/discussion.md` etc. (project-level path)
4. **Dev branch mirror**: on the dev branch, changes to `plugins/pas/library/` are manually mirrored to `library/` (copy step in pr-management skill)

### Files involved

Plugin library (`plugins/pas/library/`):
- `orchestration/` -- SKILL.md, lifecycle.md, hub-and-spoke.md, discussion.md, solo.md, sequential-agents.md, changelog.md
- `self-evaluation/` -- SKILL.md, changelog.md
- `message-routing/` -- SKILL.md, changelog.md
- `visualize-process/` -- SKILL.md, changelog.md, generate-overview.sh

Project library (`library/`):
- Same structure, manually synced, may have local additions (feedback backlog files)

## Target State

Processes reference the plugin library directly. Project-level `library/` becomes an optional override layer.

### Resolution order for library references

1. If `library/{skill}/SKILL.md` exists at project level, use it (local override)
2. Otherwise, use `${CLAUDE_PLUGIN_ROOT}/library/{skill}/SKILL.md` (plugin source)

This means:
- By default, processes use the plugin's library -- always up to date, zero drift
- Users who want to customize a library skill copy it to project `library/` -- the local copy takes precedence
- Feedback backlog files at `library/{skill}/feedback/backlog/` are project-local and do not need to exist in the plugin

### What changes

1. **First-run detection** (`SKILL.md`): stop copying library files. Create only `pas-config.yaml` and `workspace/`. The library is accessed from the plugin directly.
2. **Agent definitions**: change `library/self-evaluation/SKILL.md` references to use resolution order (check project first, fall back to plugin)
3. **Orchestration patterns**: already reference `lifecycle.md` and peer files by relative path within the orchestration directory -- no change needed since they're read from the plugin
4. **Dev branch CLAUDE.md**: update protected files note -- `library/` is no longer mandatory (it's an override layer)
5. **pr-management skill**: remove the mirror sync step for library files

### What stays the same

- Library skill structure (SKILL.md + changelog.md + feedback/backlog/)
- Feedback backlog files stay at project level (they're local observations, not shared)
- Library graduation rule (skills graduate when reused in 2+ places)

## Migration Plan

### Step 1: Update first-run detection
- Modify `plugins/pas/skills/pas/SKILL.md`: remove the `library/` copy step from first-run detection
- Keep `pas-config.yaml` and `workspace/` creation

### Step 2: Update library references in process artifacts
- All agent.md files that reference `library/` need the resolution-order logic
- The orchestrator pattern files already reference peer files by relative path -- verify this works when loaded from the plugin directory

### Step 3: Update CLAUDE.md
- `library/` changes from "protected directory" to "optional override directory"
- Update the "Protected Files" section to explain the new role

### Step 4: Update pr-management skill
- Remove the mirror sync step (Step 5 in current pr-management)
- Library changes are plugin-only (they go in PRs with other plugin changes)

### Step 5: Clean up existing project library
- On the dev branch, `library/` can be kept as-is for backward compatibility
- New projects will not have `library/` at all unless they customize

## Risks

### Risk 1: Standalone use (no plugin context)
Processes running outside the plugin context (e.g., someone copies a process to a repo without the PAS plugin) need library skills to work. The project-level `library/` serves as a self-contained fallback.

**Mitigation:** The resolution order checks project-level first. If someone has copied library files to their project, those work. The plugin reference is the default, not the only path.

### Risk 2: Variable availability
`${CLAUDE_PLUGIN_ROOT}` (or equivalent) must be available when agent.md files are read. Need to verify this variable is set by Claude Code when a plugin is loaded.

**Mitigation:** Test with a simple reference before migrating all files. If the variable is not available, the alternative is to use `${CLAUDE_SKILL_DIR}/../../library/` style relative paths from skill files.

### Risk 3: Feedback backlog location
Currently feedback signals route to `library/{skill}/feedback/backlog/`. If the library is in the plugin, writing to `plugins/pas/library/{skill}/feedback/backlog/` modifies the plugin source -- not desirable.

**Mitigation:** Feedback routing continues to write to project-level `library/{skill}/feedback/backlog/` (which is the override layer). The routing hook needs to know to write there, not to the plugin directory.

## Decision Required

Before implementation, verify:
1. What variable provides the plugin root path when agent.md is being read?
2. Can agent.md skills references use `${CLAUDE_PLUGIN_ROOT}`?
3. Does `${CLAUDE_SKILL_DIR}` work from within agent.md or only from SKILL.md?

These determine whether the implementation uses absolute plugin paths or relative paths from skill files.
