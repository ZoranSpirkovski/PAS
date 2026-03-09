---
name: self-evaluation
description: Use at agent shutdown to write structured improvement signals. Carried by all agents when feedback is enabled. Zero cost during productive work.
---

# Self-Evaluation

Write structured improvement signals at shutdown. This skill activates only at shutdown step 3 (after receiving downstream feedback, before final shutdown). It costs zero tokens during productive work.

## When to Activate

- You are shutting down after completing your work
- You have already received any downstream feedback from later phases
- Feedback is enabled in `pas-config.yaml`

Do NOT activate during work. Do NOT evaluate while producing output. Wait until shutdown.

## Process

1. Reflect on the session: what went well, what went wrong, what the user corrected
2. For each observation, determine the signal type (see below)
3. Write signals to `workspace/{process}/{slug}/feedback/{your-agent-name}-{session_id}.md`

   The session ID is provided by the SessionStart hook and recorded in `status.yaml` under `current_session`. If no session ID is available, use your agent name without a suffix.
4. If nothing went wrong: write "No issues detected." and stop. Do NOT list positives.

## Signal Types

### PPU — Persistent Preference Update

User preferences with long-term implications ("stop doing X", "always do Y").

```markdown
[PPU-01]
Target: skill:{skill-name}
Frequency: {how often this preference was expressed}
Evidence: "{exact quote or description from session}"
Priority: {HIGH | MEDIUM | LOW}
Preference: {what the user wants going forward}
```

### OQI — Output Quality Issue

Issues that degraded output quality (factual errors, instruction non-compliance, inefficiency).

```markdown
[OQI-01]
Target: skill:{skill-name}
Degraded: {what aspect of output was degraded}
Root Cause: {why this happened}
Fix: {specific change to prevent recurrence}
Evidence: "{exact quote or description from session}"
Priority: {HIGH | MEDIUM | LOW}
```

### GATE — Stability Gate

Changes that should NOT be implemented (frustration-driven, safety-degrading, or would break working behavior).

```markdown
[GATE-01]
Target: skill:{skill-name}
Rejected Change: {what change was considered}
Why Rejected: {why it should not be made}
Alternative: {better approach, if any}
Evidence: "{context for why this gate exists}"
```

### STA — Stability Anchor

Behavior confirmed to work well, that must be preserved during future upgrades. Use sparingly. Only write STA when success occurred in a risky context that future changes might break.

```markdown
[STA-01]
Target: skill:{skill-name}
Strength: {CONFIRMED_BY_USER | OBSERVED}
Behavior: {exact behavior to preserve}
Context: {what made this session risky for this behavior}
```

## Signal Rules

**Target format:** Always one of:
- `skill:{name}` — targets a specific skill
- `agent:{name}` — targets agent-level behavior
- `process:{name}` — targets process-level definition

**Additional target:** `framework:pas` — targets the PAS framework itself (not a specific process artifact). See Framework Feedback Routing below.

**Signal ID format:** `[TYPE-NN]` where NN is sequential within the file (e.g., `[PPU-01]`, `[OQI-01]`, `[OQI-02]`).

**Priority levels:**
- HIGH: user explicitly corrected this, or output was factually wrong
- MEDIUM: suboptimal output that the user noticed
- LOW: minor inefficiency or style issue

## Framework Feedback Routing

When a signal targets the PAS framework itself (not a specific process, agent, or skill), use `Target: framework:pas`. This applies when:

- A PAS convention is missing or broken
- An orchestration pattern has a structural gap
- The feedback system itself has a deficiency
- A library skill needs improvement

**Routing chain:**
1. Agent writes the signal locally to `workspace/{process}/{slug}/feedback/{agent-name}.md` with `Target: framework:pas`
2. Agent appends `Route: github-issue` to the signal block
3. At shutdown, the orchestrator reads all feedback files, finds signals marked `Route: github-issue`, and files them as GitHub issues on the PAS repository

The agent's job is to detect and record the signal. The orchestrator's job is to route it. The COMPLETION GATE (in the orchestration pattern) blocks session completion until all `framework:pas` signals have been filed.

## Saturation Prevention

- OQI and PPU are the primary signals. Write them whenever you observe issues.
- STA is rare and defensive. Only write when success happened in a risky context.
- GATE is written when you observe a change that would be harmful.
- A smooth session produces: "No issues detected." Not a list of positives.
- The correct outcome of a perfect session is minimal or no feedback.

## Recursive Boundary

**Never write feedback about the feedback system itself.** The loop is strictly: work, feedback, apply, work. Never: work, feedback, feedback-about-feedback.

Exception: only when the user explicitly points PAS at its own feedback system (e.g., "the routing keeps misclassifying signals"). That is normal user feedback routed to PAS's own artifacts, not recursive self-feedback.

## Your Role

**Report what you observed. Include evidence and target. Do not evaluate whether it is worth fixing.** The quality improvement framework (Efficiency Test, Accuracy Test, Alignment Test, UX Test) lives in the feedback applicator, which has cross-session context to judge what is worth changing. Your job is accurate signal detection, not signal evaluation.
