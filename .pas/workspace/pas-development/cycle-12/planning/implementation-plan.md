# Cycle 12 Implementation Plan

## Scope

4 work items: version auto-bump, library dedup, README walkthrough, roadmap housekeeping.

---

## Track A: Version Auto-Bump (plugin changes)

### A1: Create `plugins/pas/hooks/lib/bump-version.sh`

Script that:
1. Reads current version from `plugins/pas/.claude-plugin/plugin.json` using jq
2. Increments patch number (1.3.0 → 1.3.1)
3. Writes updated version to:
   - `plugins/pas/.claude-plugin/plugin.json` (`.version`)
   - `.claude-plugin/marketplace.json` (`.metadata.version` and `.plugins[0].version`)
4. Outputs the new version to stdout for use in commit messages

### A2: Update pr-management skill

In `.pas/processes/pas-development/agents/community-manager/skills/pr-management/SKILL.md`:
- Add **Step 0: Bump version** before Step 1
- Run `bash plugins/pas/hooks/lib/bump-version.sh`
- Include `.claude-plugin/marketplace.json` in the plugin commit (Step 1)
- Update Step 3 diff verification to also allow `.claude-plugin/` files

### A3: Update CLAUDE.md PR scope rules

In `.claude/CLAUDE.md`:
- Update PR scope to include `.claude-plugin/marketplace.json` as a distribution artifact
- Clarify that PRs contain `plugins/pas/` files AND `.claude-plugin/marketplace.json`

---

## Track B: Library Dedup (plugin changes)

### B1: Update thin launcher template in `pas-create-process`

File: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process`

Change the generated thin launcher (lines 297-308) from:
```
Read `.pas/library/orchestration/lifecycle.md`
Read the orchestration pattern from `.pas/library/orchestration/`
```
To:
```
Read `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md`
Read the orchestration pattern from `${CLAUDE_PLUGIN_ROOT}/library/orchestration/`
```

Also update the process.md body lifecycle section (lines 218-226) to reference `${CLAUDE_PLUGIN_ROOT}/library/` instead of `.pas/library/`.

### B2: Update first-run detection in `/pas` skill

File: `plugins/pas/skills/pas/SKILL.md`

Change first-run detection (lines 41-46):
- Stop copying library to `.pas/library/`
- First-run creates only: `.pas/config.yaml` and `.pas/workspace/`
- Update confirmation message accordingly

Update Library Bootstrap section (lines 57-58):
- Remove the "copy from plugin library" instruction
- Processes reference plugin library directly via `${CLAUDE_PLUGIN_ROOT}/library/`

### B3: Update creating-processes SKILL.md library bootstrap

File: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md`

Step 5 (line 79) currently says "bootstrap by copying from the PAS plugin's library." Change to:
- Reference `${CLAUDE_PLUGIN_ROOT}/library/orchestration/SKILL.md` directly
- No bootstrap copy needed

### B4: Update README first-run description

File: `README.md`

Line 59 currently says:
> On first use, PAS creates `pas-config.yaml`, `library/`, and `workspace/` directories

Change to reflect that library is no longer copied:
> On first use, PAS creates `.pas/config.yaml` and `.pas/workspace/` in your project root.

Also update the "What's in the Plugin" section if needed to emphasize library lives in the plugin.

---

## Track C: README End-to-End Example (plugin changes)

### C1: Add walkthrough section to README

File: `README.md`

Insert a new "## Walkthrough" section after Quick Start (line 59) showing:

1. **Create a process**: `/pas:pas` conversation with goal → generated files
2. **Directory structure**: what PAS creates (tree view)
3. **Run the process**: invoke the thin launcher, see phases execute
4. **Feedback loop**: agent self-evaluation signals → automatic routing → applying improvements

Keep it concrete with realistic example output, not abstract descriptions. Target ~40-50 lines.

---

## Track D: Roadmap & Dev Artifacts (dev-only, no PR)

### D1: Update roadmap

File: `docs/plans/2026-03-08-six-month-roadmap.md`

- Mark Milestone 1 as "Complete (Cycle 9-10)"
- Update Milestone 2 status: items 2, 3, 4 complete (cycle 10), items 1, 5 completing in cycle 12
- Update progress table with cycle numbers

### D2: Update current state in roadmap

Update the "Current State" section to reflect cycle 12 improvements.

---

## Execution Order

Tracks A, B, C are independent and can be parallelized.
Track D depends on A+B+C completion (needs final version number).

**Parallel dispatch:**
- Agent 1: Track A (version auto-bump) — framework-architect
- Agent 2: Track B (library dedup) — framework-architect
- Agent 3: Track C (README walkthrough) — dx-specialist

**Sequential:**
- Track D after A+B+C complete — orchestrator

## Files Modified (plugin — goes in PR)

- `plugins/pas/hooks/lib/bump-version.sh` (NEW)
- `plugins/pas/.claude-plugin/plugin.json` (version bump)
- `plugins/pas/skills/pas/SKILL.md` (first-run, library bootstrap)
- `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md` (library ref)
- `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process` (thin launcher template)
- `README.md` (walkthrough, first-run description)

## Files Modified (distribution — goes in PR)

- `.claude-plugin/marketplace.json` (version bump)

## Files Modified (dev-only — NOT in PR)

- `.pas/processes/pas-development/agents/community-manager/skills/pr-management/SKILL.md`
- `.claude/CLAUDE.md`
- `docs/plans/2026-03-08-six-month-roadmap.md`
