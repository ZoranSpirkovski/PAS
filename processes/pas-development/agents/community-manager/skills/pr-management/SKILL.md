---
name: pr-management
description: Use when opening pull requests for completed work from the Execution phase. Creates PRs with proper descriptions linking to issues and the implementation plan.
---

# PR Management

## Overview

Open pull requests for completed work, with structured descriptions that link back to the implementation plan and any related GitHub issues.

## When to Use

- After Execution phase work is complete and reviewed by the product owner
- When QA validation passes

## Process

1. **Determine branch name**: `feature/pas-dev-{slug}` where slug matches the workspace instance
2. **Create branch and stage changes**: stage only the files listed in the implementation plan's execution output
3. **Collect context**:
   - Read the implementation plan from `workspace/pas-development/{slug}/planning/implementation-plan.md`
   - Read the priorities from `workspace/pas-development/{slug}/discovery/priorities.md`
   - Identify linked GitHub issues from the issue triage report
4. **Write PR description** following the format below
5. **Open PR**: Run `gh pr create --repo ZoranSpirkovski/PAS --title "{title}" --body "{body}"`
6. **Link issues**: If issues are addressed, note them in the PR body with "Addresses #{number}"

## PR Description Format

```markdown
## Summary

{2-3 bullet points describing what this cycle accomplished}

## Changes

{Grouped list of changes by area}

## Linked Issues

{List of GitHub issues addressed or progressed, with "Addresses #N" format}

## Discovery Context

{Brief summary of why these changes were prioritized — from the Discovery phase output}

## Validation

{Summary of QA validation results}
```

## Quality Checks

- PR title is under 70 characters and describes the outcome, not the process
- All changed files are accounted for in the description
- Linked issues are accurate (only issues actually addressed)
- No secrets or workspace-internal files are included in the PR

## Common Mistakes

(Populated by feedback over time)
