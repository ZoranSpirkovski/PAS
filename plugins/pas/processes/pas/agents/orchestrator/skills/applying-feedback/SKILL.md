---
name: applying-feedback
description: Use when reviewing and applying accumulated feedback from backlogs across PAS artifacts. Invoked by the PAS router when user mentions feedback, upgrade, or improvement.
---

# Applying Feedback

Review and apply accumulated feedback signals from backlogs across all PAS artifacts. Feedback signals are written by agents during self-evaluation and routed to artifact backlogs by the feedback routing hook.

## Workflow

### 1. Survey Backlogs

Recursively scan for pending feedback:

- `processes/*/feedback/backlog/` — process-level signals
- `processes/*/agents/*/feedback/backlog/` — agent-level signals
- `processes/*/agents/*/skills/*/feedback/backlog/` — skill-level signals
- `library/*/feedback/backlog/` — library skill signals

List all directories containing `.md` files (pending signals).

### 2. Present Accumulation Summary

Show the user a prioritized overview:

| Artifact | Signals | Highest Priority | Signal Types |
|----------|---------|-----------------|--------------|
| {path} | {count} | {HIGH/MEDIUM/LOW} | {PPU, OQI, etc.} |

If targeted (user specified an artifact): focus on that artifact only.
If untargeted: recommend where to start based on signal volume and severity.

### 3. Ask User Preference

Before applying any changes, ask:

- **Apply all + remember**: apply all signals for this artifact, remember this preference for future sessions
- **Apply all once**: apply all signals for this artifact this time only
- **Just this**: let me pick which signals to apply one at a time
- **Review first**: show me each signal before deciding

### 4. Sanity Checks

For each signal, verify:

- **Target validation**: does the target artifact exist? Is the path correct?
- **Signal quality**: is the evidence specific enough to act on? Is the fix clear?
- **Duplicate detection**: is this signal saying the same thing as another signal already processed?
- **STA conflict**: would this change affect behavior protected by a Stability Anchor?

Skip signals that fail sanity checks. Log why they were skipped.

### 5. Pattern Analysis

Look for patterns across signals:

- **3+ reports** pointing to the same issue = strong pattern, high confidence to act
- **2 HIGH priority** signals on the same artifact = moderate pattern, worth acting on
- **Single LOW** signal = weak, apply only if the fix is obvious and low-risk

### 6. Resolve Contradictions

When signals conflict with each other:

1. **Most recent wins**: later sessions have more context
2. **Highest frequency wins**: repeated observations beat one-offs
3. **Context-conditional merge**: both might be right in different contexts (add conditional logic)
4. **Escalate to user**: if contradictions cannot be resolved mechanically

### 7. Evaluate Definitiveness

Is the feedback clear enough to act on?

- Apply Occam's razor: choose the fix with the fewest assumptions
- If ambiguous: ask the user for crystal clarity before changing anything
- Never guess at what the user wants. Better to ask than to apply a wrong fix.

### 8. Apply with Consolidation-First Approach

Prefer tightening existing instructions over adding new ones:

- Can an existing rule be made more specific? Do that instead of adding a new rule.
- Can two related rules be merged? Do that instead of keeping both.
- Only add new instructions when the feedback describes behavior not covered by existing instructions.

### 9. Check STAs

Before finalizing changes, scan for Stability Anchors on the target artifact:

- If the change would affect anchored behavior: **warn the user explicitly**
- Show the STA, explain the conflict, and ask for confirmation
- STAs exist to prevent regression. Overriding them requires explicit user approval.

### 10. Present Diff

Show the user exactly what will change:

- Before/after for each modified section
- Highlight what was added, removed, or changed
- Explain why each change is being made (link to triggering signals)

### 11. Write Changelog Entry

After user approves the changes, write a dated entry to the artifact's `changelog.md`:

```markdown
## {YYYY-MM-DD} — {Brief description of change}

Triggered by: {signal-id} ({workspace-slug}), {signal-id} ({workspace-slug})
Pattern: {what the signals had in common}
Change: {what was actually changed in the artifact}
```

### 12. Clear and Commit

- Remove processed signals from `feedback/backlog/`
- Stage modified artifact and changelog
- Commit with message: `"Apply feedback: {artifact-path} — {brief description}"`

## Quality Tests

Apply these tests to evaluate whether a change is worth making:

| Test | Question |
|------|----------|
| **Efficiency** | Does this change reduce wasted effort or tokens? |
| **Accuracy** | Does this change prevent factual or structural errors? |
| **Alignment** | Does this change better match user preferences? |
| **UX** | Does this change improve the user's experience? |

A change should pass at least one test. If it passes none, reconsider whether it is worth applying.
