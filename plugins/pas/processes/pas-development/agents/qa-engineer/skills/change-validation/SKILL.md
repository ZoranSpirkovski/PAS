---
name: change-validation
description: Use when validating implemented changes against the plan, PAS conventions, cross-artifact consistency, and regressions.
---

# Change Validation

## Overview

Systematically validate all changes made during the Execution phase. Check completeness against the plan, PAS convention compliance, cross-artifact consistency, and regressions.

## When to Use

- In the Validation phase, after Execution is complete
- When the product owner asks for a quality check on recent changes

## Process

### 1. Plan Completeness

Read `workspace/pas-development/{slug}/planning/implementation-plan.md` and check each change item:
- Was the change implemented?
- Do the modified/created files match what the plan specified?
- Were any unplanned changes made? (Flag for review — they may be valid but need acknowledgment)

### 2. Convention Compliance

For every new or modified artifact, verify:
- **Processes**: valid YAML frontmatter, all referenced agents exist, phase I/O forms valid DAG, mode files present
- **Agents**: valid YAML frontmatter, model is a valid tier, all referenced skills exist, has feedback/backlog/ and changelog.md
- **Skills**: valid YAML frontmatter, description starts with "Use when", has required sections (Overview, When to Use, Process, Output Format, Quality Checks), has feedback/backlog/ and changelog.md
- **Library skills**: actually used in 2+ places (verify cross-references)

### 3. Cross-Artifact Consistency

Check that changes don't contradict existing artifacts:
- Do modified skills still match their agent.md references?
- Do modified agents still match their process.md references?
- Do orchestration pattern changes align across all pattern files?
- Are terminology changes applied consistently everywhere?

### 4. Regression Check

For existing processes and skills that were NOT targeted by this cycle:
- Do they still reference valid files?
- Have any shared dependencies changed in a breaking way?
- Do library skills still work for all their consumers?

### 5. Changelog Verification

- Every modified artifact has a changelog entry for this cycle
- Changelog entries describe what changed and why
- Version numbers are bumped appropriately

## Output Format

```markdown
# Validation Report

## Status: {PASS | FAIL}

## Plan Completeness
- {N}/{N} changes implemented
- Unplanned changes: {list or "none"}

## Convention Violations
- {file}: {violation} — **{blocking | advisory}**

## Consistency Issues
- {description} — **{blocking | advisory}**

## Regressions
- {description} — **{blocking | advisory}**

## Changelog Status
- {N}/{N} artifacts have updated changelogs

## Blocking Issues (must fix before release)
1. {issue with file path and fix instruction}

## Advisory Issues (should fix, not blocking)
1. {issue with file path and suggestion}
```

## Quality Checks

- Every file changed in this cycle was reviewed (none skipped)
- Every check category was performed (no shortcuts)
- Blocking vs advisory distinction is consistent: blocking = would break something or violate a hard convention; advisory = suboptimal but functional
- Fix instructions are specific enough for another agent to implement

## Common Mistakes

(Populated by feedback over time)
