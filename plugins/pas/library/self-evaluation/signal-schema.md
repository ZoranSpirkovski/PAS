---
name: signal-schema
description: Single source of truth for feedback signal types, fields, target grammar, and priority levels.
---

# Signal Schema

Canonical reference for all feedback signal types used in PAS self-evaluation. All agents writing feedback MUST conform to this schema.

## Signal Types

| Type | Name | Purpose | Frequency |
|------|------|---------|-----------|
| PPU | Persistent Preference Update | User preferences with long-term implications | Common |
| OQI | Output Quality Issue | Issues that degraded output quality | Common |
| GATE | Stability Gate | Changes that should NOT be implemented | Rare |
| STA | Stability Anchor | Behavior confirmed to work well, must be preserved | Rare |

## Signal ID Format

`[TYPE-NN]` where NN is zero-padded sequential within the file.

Examples: `[PPU-01]`, `[OQI-01]`, `[OQI-02]`, `[GATE-01]`, `[STA-01]`

## Target Grammar

Every signal MUST have exactly one `Target:` field. Valid formats:

| Target | Scope | Example |
|--------|-------|---------|
| `skill:{name}` | A specific skill | `Target: skill:creating-processes` |
| `agent:{name}` | Agent-level behavior | `Target: agent:orchestrator` |
| `process:{name}` | Process-level definition | `Target: process:pas-development` |
| `framework:pas` | The PAS framework itself | `Target: framework:pas` |

The target determines where the signal is routed:
- `skill:`, `agent:`, `process:` → routed to the artifact's `feedback/backlog/` directory
- `framework:pas` → filed as a GitHub issue (requires `Route: github-issue` annotation)

## Priority Levels

| Priority | Criteria | Action |
|----------|----------|--------|
| HIGH | User explicitly corrected this, or output was factually wrong | Fix immediately |
| MEDIUM | Suboptimal output that the user noticed | Fix in next cycle |
| LOW | Minor inefficiency or style issue | Fix when convenient |

## Field Reference by Type

### PPU — Persistent Preference Update

```markdown
[PPU-NN]
Target: {target}
Frequency: {how often this preference was expressed}
Evidence: "{exact quote or description from session}"
Priority: {HIGH | MEDIUM | LOW}
Preference: {what the user wants going forward}
```

### OQI — Output Quality Issue

```markdown
[OQI-NN]
Target: {target}
Degraded: {what aspect of output was degraded}
Root Cause: {why this happened}
Fix: {specific change to prevent recurrence}
Evidence: "{exact quote or description from session}"
Priority: {HIGH | MEDIUM | LOW}
```

### GATE — Stability Gate

```markdown
[GATE-NN]
Target: {target}
Rejected Change: {what change was considered}
Why Rejected: {why it should not be made}
Alternative: {better approach, if any}
Evidence: "{context for why this gate exists}"
```

### STA — Stability Anchor

```markdown
[STA-NN]
Target: {target}
Strength: {CONFIRMED_BY_USER | OBSERVED}
Behavior: {exact behavior to preserve}
Context: {what made this session risky for this behavior}
```

## Framework Signal Routing

Signals targeting `framework:pas` follow a two-step routing chain:

1. Agent writes signal locally with `Target: framework:pas` and appends `Route: github-issue`
2. At shutdown, orchestrator reads all feedback files and files `framework:pas` signals as GitHub issues

The `route-feedback.sh` hook automates step 2. The completion gate blocks session completion until all `framework:pas` signals have been filed.

## Signal Rules

- A smooth session produces: "No issues detected." — not a list of positives.
- OQI and PPU are the primary signals. Write them whenever issues are observed.
- STA is rare and defensive — only when success happened in a risky context.
- GATE is written when a change would be harmful.
- Never write feedback about the feedback system itself (recursive boundary).
- Report what you observed with evidence. Do not evaluate whether it is worth fixing.

## Status Annotations

Backlog signals may have a `Status:` line prepended when resolved:

```markdown
Status: RESOLVED (cycle N — description of resolution)
```

Resolved signals remain in the backlog for historical context but are not actioned again.
