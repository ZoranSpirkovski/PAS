---
name: ecosystem-scan
description: Use when researching Claude Code's current capabilities, competing frameworks, and ecosystem trends. Produces an opportunity report for Discovery.
---

# Ecosystem Scan

## Overview

Research the current state of the Claude Code ecosystem, identify new capabilities PAS could leverage, and survey competing approaches to agentic workflow frameworks.

## When to Use

- In the Discovery phase when providing the Ecosystem Analyst's perspective
- When evaluating whether PAS should adopt a new pattern or capability

## Process

1. **Claude Code capabilities**: Search for recent Claude Code updates, new features, API changes:
   - Check Claude Code documentation and changelogs
   - Identify features PAS doesn't leverage yet (e.g., new tool types, hooks improvements, plugin API changes)
   - Note deprecated features PAS currently relies on
2. **Competing approaches**: Search for other agentic workflow frameworks:
   - What abstractions do they use?
   - What do they do well that PAS doesn't?
   - What does PAS do better?
3. **Ecosystem trends**: What patterns are emerging in the broader AI agent space?
   - New orchestration patterns
   - Developer experience innovations
   - Community standards for agent configuration
4. **Synthesize opportunities**: For each finding, assess relevance to PAS's goal

## Output Format

```markdown
# Ecosystem Scan

## New Claude Code Capabilities
- {capability}: {what it is, when it shipped, how PAS could use it}

## Competitive Landscape
- {tool/framework}: {what they do well, what PAS does better, opportunity}

## Ecosystem Trends
- {trend}: {evidence, relevance to PAS}

## Opportunities
{Ranked list of actionable opportunities with estimated impact}

## Risks
{Things PAS depends on that might change or deprecate}
```

## Quality Checks

- Claims about external tools cite specific sources (URLs, docs)
- Opportunities are assessed for PAS relevance, not just general interest
- Competitive analysis is fair — acknowledges competitor strengths honestly
- Risks are grounded in evidence, not speculation

## Common Mistakes

(Populated by feedback over time)
