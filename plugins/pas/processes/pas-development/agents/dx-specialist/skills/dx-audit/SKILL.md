---
name: dx-audit
description: Use when evaluating PAS from a new user's perspective. Assesses onboarding path, naming clarity, documentation gaps, and overall developer experience.
---

# DX Audit

## Overview

Evaluate the PAS framework from the perspective of a developer encountering it for the first time. Identify friction points in onboarding, confusing terminology, documentation gaps, and ergonomic issues.

## When to Use

- In the Discovery phase when providing the DX Specialist's perspective
- When the product owner asks about user experience or onboarding
- Before making changes to user-facing artifacts

## Process

1. **Trace the onboarding path**: Starting from README.md, follow the path a new user would take:
   - Can they understand what PAS is in 30 seconds?
   - Can they install it?
   - Can they create their first process?
   - Where do they get stuck?
2. **Audit naming**: For every user-facing term, ask:
   - Is this term standard or PAS-specific jargon?
   - If jargon, is it defined where it's first used?
   - Are there competing terms for the same concept?
3. **Audit documentation**: For each SKILL.md and major markdown file:
   - Is the purpose clear in the first 2 sentences?
   - Are instructions actionable (not vague)?
   - Are examples provided where they'd help?
   - Is progressive disclosure working (overview first, details in references)?
4. **Audit error paths**: What happens when things go wrong?
   - Are error messages helpful?
   - Can users recover without deep PAS knowledge?
5. **Compare to expectations**: What would a user expect based on similar tools? Where does PAS violate expectations?

## Output Format

```markdown
# DX Audit

## Onboarding Assessment
**Time to first process:** {estimate}
**Friction points:** {list with severity}

## Naming Issues
- {term}: {problem and suggestion}

## Documentation Gaps
- {file}: {what's missing or unclear}

## Error Experience
- {scenario}: {what happens and what should happen}

## Quick Wins
{Changes that would have high DX impact with low effort}
```

## Quality Checks

- Assessment is from the user's perspective, not the developer's
- Every issue has a concrete suggestion, not just "this is confusing"
- Quick wins are genuinely quick (not disguised large projects)
- Audit covers the full onboarding path, not just individual files

## Common Mistakes

(Populated by feedback over time)
