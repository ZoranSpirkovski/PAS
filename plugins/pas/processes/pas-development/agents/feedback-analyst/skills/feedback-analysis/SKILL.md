---
name: feedback-analysis
description: Use when processing accumulated feedback signals across PAS artifacts. Scans backlog directories, classifies signals, identifies patterns, and produces a prioritized report.
---

# Feedback Analysis

## Overview

Scan all `feedback/backlog/` directories across the PAS project, read accumulated signals (PPU, OQI, GATE, STA), cluster them by target and theme, and produce a prioritized report that feeds into the Discovery phase.

## When to Use

- At the start of a Discovery phase (feedback-driven mode)
- When the product owner asks "what feedback exists?"
- After multiple process runs have accumulated signals

## Process

1. **Scan for signals**: Glob for all files in `**/feedback/backlog/*.md` across the project (excluding `.gitkeep`)
2. **Parse each signal**: Extract type (PPU/OQI/GATE/STA), target, priority, evidence, and the fix/preference
3. **Cluster by target**: Group signals that target the same artifact (skill, agent, or process)
4. **Cluster by theme**: Within each target, identify recurring themes (e.g., multiple OQIs about the same root cause)
5. **Prioritize**: Rank clusters by:
   - Signal count (more signals = stronger signal)
   - Priority level (HIGH > MEDIUM > LOW)
   - GATE signals always surface (they represent guardrails)
   - STA signals surface as constraints on proposed changes
6. **Check for conflicts**: Do any PPU signals contradict existing STA anchors? Flag these.
7. **Produce report**: Write the analysis to the workspace

## Output Format

```markdown
# Feedback Analysis Report

## Summary
- Total signals: {N}
- By type: {N} PPU, {N} OQI, {N} GATE, {N} STA
- Clusters identified: {N}

## Priority Clusters

### Cluster 1: {theme} ({N} signals, highest priority: {HIGH|MEDIUM|LOW})
**Target:** {artifact}
**Signals:** {list signal IDs}
**Pattern:** {what these signals collectively indicate}
**Suggested action:** {what addressing this would look like}

### Cluster 2: ...

## Conflicts
{Any PPU vs STA conflicts, or contradictory signals}

## Unclustered Signals
{One-off signals that don't form patterns, listed individually}
```

## Quality Checks

- Every signal file was read (none skipped)
- Clusters are based on evidence, not inference
- GATE and STA signals are always surfaced, never buried
- Conflicts are explicitly flagged
- Report says "no signals found" when backlogs are empty — does not fabricate patterns

## Common Mistakes

(Populated by feedback over time)
