---
name: framework-assessment
description: Use when evaluating PAS's current state at the start of a development cycle. Audits artifacts against conventions, identifies architectural gaps, and compares capabilities to goals.
---

# Framework Assessment

## Overview

Evaluate the current state of the PAS framework — audit all artifacts for convention compliance, identify architectural gaps, and compare current capabilities against the stated goal of being the best way to build agentic workflows in Claude Code.

## When to Use

- In the Discovery phase when providing the Framework Architect's perspective
- When the product owner asks "where does PAS stand?"
- Before proposing architectural changes (understand current state first)

## Process

1. **Audit conventions**: Check all processes, agents, and skills for:
   - Every artifact has `feedback/backlog/` and `changelog.md`
   - Skills follow Agent Skills spec (SKILL.md with YAML frontmatter)
   - Agents are process-local (no cross-process sharing)
   - Library skills are genuinely reused in 2+ places
2. **Audit completeness**: For each process, verify:
   - All agents referenced in process.md exist
   - All skills referenced in agent.md exist
   - Mode files exist and have correct frontmatter
   - Phase I/O dependencies form a valid DAG
3. **Identify gaps**: Compare current capabilities to goals:
   - What orchestration patterns are untested in real usage?
   - What common user needs can't be expressed in current PAS constructs?
   - Where does the framework constrain rather than enable?
4. **Version analysis**: Read changelogs to understand trajectory — what's been improving, what's stalled

## Output Format

```markdown
# Framework Assessment

## Convention Compliance
- {N} artifacts audited
- {N} violations found
- {list violations with specific file paths}

## Completeness
- {N} processes checked
- {issues found}

## Capability Gaps
- {gap 1}: {description and impact}
- {gap 2}: ...

## Trajectory
- Improving: {areas with recent changelog activity}
- Stalled: {areas with no changes despite known issues}

## Architectural Observations
{Broader observations about PAS's design direction}
```

## Quality Checks

- Assessment is based on reading actual files, not assumptions
- Every violation cites a specific file path
- Gaps are described in terms of user impact, not abstract concerns
- Observations distinguish between "not yet built" and "architecturally blocked"

## Common Mistakes

(Populated by feedback over time)
