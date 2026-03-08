---
name: issue-triage
description: Use when triaging open GitHub issues for the PAS framework. Reads issues, classifies them, assesses priority, and produces a triage report for Discovery.
---

# Issue Triage

## Overview

Read open GitHub issues on the PAS repository, classify each one, assess priority, and produce a triage report that feeds into the Discovery phase alongside internal feedback signals.

## When to Use

- At the start of a Discovery phase
- When the product owner asks about open issues or community requests

## Process

1. **Fetch open issues**: Run `gh issue list --repo ZoranSpirkovski/PAS --state open --json number,title,body,labels,createdAt,comments,author --limit 50`
2. **Classify each issue**:
   - **Bug**: something is broken or behaving incorrectly
   - **Feature request**: a new capability or enhancement
   - **Question**: someone asking how to use PAS
   - **Framework feedback**: feedback about PAS itself routed from the self-evaluation system (target: `framework:pas`)
3. **Assess priority**:
   - HIGH: blocks users, data loss risk, or multiple people report the same thing
   - MEDIUM: degraded experience but workaround exists
   - LOW: nice-to-have, cosmetic, or single report
4. **Check for duplicates**: Group issues that describe the same underlying problem
5. **Identify actionable items**: Which issues have enough information to act on? Which need clarification?
6. **Produce report**: Write triage to workspace

## Output Format

```markdown
# Issue Triage Report

## Summary
- Open issues: {N}
- By type: {N} bugs, {N} feature requests, {N} questions, {N} framework feedback
- Needs clarification: {N}

## Actionable Issues

### #{number}: {title} ({type}, {priority})
**Author:** {author}
**Summary:** {one-sentence summary}
**PAS target:** {which artifact this relates to, if identifiable}
**Action:** {what addressing this would involve}

## Needs Clarification

### #{number}: {title}
**Missing:** {what information is needed}
**Suggested question:** {what to ask the author}

## Duplicates
{Groups of issues describing the same problem}
```

## Quality Checks

- All open issues were read (none skipped)
- Classifications are based on issue content, not just title
- Priority reflects impact, not just recency
- Issues needing clarification have specific questions, not generic "please provide more info"

## Common Mistakes

(Populated by feedback over time)
