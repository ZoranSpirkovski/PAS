---
name: implementation-planning
description: Use when producing a scoped implementation plan from approved priorities. Creates file-level specificity with parallelization analysis.
---

# Implementation Planning

## Overview

Take approved priorities from Discovery and produce a concrete, scoped implementation plan that specifies exactly what changes to make, to which files, in what order, and what can be parallelized.

## When to Use

- In the Planning phase, after the product owner approves Discovery priorities
- When the product owner asks "how would we implement X?"

## Process

1. **Read approved priorities**: Load `workspace/pas-development/{slug}/discovery/priorities.md`
2. **For each priority, determine scope**:
   - Which existing files need modification? (Read them first)
   - What new files need creation? For new PAS artifacts (skills, agents, processes), specify the
     `pas-create-*` command with all flags. Scripts live at
     `plugins/pas/processes/pas/agents/orchestrator/skills/creating-{type}/scripts/pas-create-{type}`.
     Use `--base-dir` to target the correct root. If the creation scripts themselves are the change
     target, note this as a bootstrap exception and create manually.
   - What files might be affected indirectly? (Check cross-references)
3. **Identify dependencies**: Which changes depend on others? Which are independent?
4. **Assign to agents**: Based on the change type:
   - Architectural changes (process definitions, orchestration, library skills) → Framework Architect
   - Documentation, tutorials, naming, readability → DX Specialist
   - Signal processing, changelog updates → Feedback Analyst
   - PRs, issue comments, linking → Community Manager
5. **Determine parallelism**: Group independent changes that can be dispatched simultaneously
6. **Estimate scope**: Flag any priority that seems too large for a single cycle — suggest splitting

## Output Format

```markdown
# Implementation Plan

## Priorities Addressed
{List from Discovery, with reference}

## Changes

### Change 1: {description}
**Priority:** {which Discovery priority this addresses}
**Agent:** {who implements this}
**Files:**
- Modify: `{path}` — {what changes}
- Create: `{path}` — {what this is}
  Command: `bash plugins/pas/.../pas-create-{type} --name ... --base-dir ...` (for PAS artifacts)
**Depends on:** {other change numbers, or "none"}

### Change 2: ...

## Execution Order

### Parallel Group 1 (no dependencies)
- Change 1 → Framework Architect
- Change 3 → DX Specialist

### Parallel Group 2 (depends on Group 1)
- Change 2 → Framework Architect

### Sequential
- Change 4 → Feedback Analyst (after all other changes)

## Out of Scope
{Anything considered but deferred, with reasoning}
```

## Quality Checks

- Every priority from Discovery is addressed (or explicitly deferred with reasoning)
- Every file path is verified to exist (for modifications) or verified not to exist (for creations)
- No circular dependencies between changes
- Agent assignments match agent capabilities
- Plan is achievable in a single Execution phase — if not, split into sub-cycles

## Common Mistakes

- Creating PAS artifacts by hand instead of using `pas-create-*` scripts. The scripts guarantee
  correct structure (SKILL.md frontmatter, changelog.md, feedback/backlog/.gitkeep). Manual
  creation risks missing convention requirements.
- Library skills: `pas-create-skill` outputs to `processes/{p}/agents/{a}/skills/{name}/` — there
  is no `--library` flag. For library skills, create under a temporary agent path then move to
  `library/`, or scaffold the directory manually following the same structure.
