# Discovery Priorities: Cycle 4

## Context

This is the first PAS development session after PR #10 (feedback enforcement hooks). Three open GitHub issues (#6, #11, #12) all depend on whether the new hooks work. Five specialist agents analyzed signals from their perspectives and converged on priorities below.

## Priority 1: Validate Hook Enforcement (Passive)

**Source:** All 5 agents unanimous
**Type:** Validation, not implementation
**Effort:** Zero — this cycle IS the test

By running this cycle properly through all 4 phases with workspace lifecycle, status tracking, and self-evaluation, we validate that:
- SessionStart hook surfaces active workspaces (issue #11)
- Stop hook blocks exit without feedback (issue #12)
- TaskCompleted hook enforces deliverable existence
- SubagentStop hook checks for agent self-evaluation

If all hooks fire correctly, issues #11 and #12 can close at end of cycle.

## Priority 2: Fix Concrete Bugs

### 2a. check-self-eval.sh agent-specificity bug (Framework Architect)
**Severity:** HIGH — lets agents skip feedback
**Problem:** Hook checks for ANY .md file in workspace feedback dir, not the specific stopping agent's file. First agent to write feedback lets all others pass unchecked.
**Fix:** Check for `{agent-name}.md` or `{agent-name}-*.md` specifically.

### 2b. Generation script safety (Feedback Analyst, Community Manager, Framework Architect)
**Severity:** HIGH — destroyed 53 real files in a previous session
**Problem:** `pas-create-*` scripts generate into CWD `processes/`. Test cleanup (`rm -rf processes/test-*`) at project root destroys real processes.
**Fix:** Add `--base-dir` flag (mentioned in changelog but absent from scripts). Test in isolated temp directories.

## Priority 3: Close Issue #6 Remaining Sub-Problems

Issue #6 has 7 sub-problems. PR #10 fixed 4, partially fixed 1, left 2 unaddressed:

### 3a. Framework feedback GitHub routing (MEDIUM)
**Problem:** `route-feedback.sh` returns empty for `framework:*` targets. Orchestrator must manually file issues — same pattern as the self-eval skip problem.
**Fix:** Either enhance `route-feedback.sh` to handle `framework:pas` targets via `gh issue create`, or add a dedicated shutdown step hook.

### 3b. creating-processes skill missing hooks step (MEDIUM)
**Problem:** Step 8.5 "Determine Hooks" was dropped during v1.2.0 simplification. Users creating processes don't get prompted about hooks.
**Fix:** Restore the hooks step in the creating-processes skill.

## Priority 4: Version Manifest Sync

**Source:** Ecosystem Analyst
**Severity:** LOW but embarrassing
**Problem:** marketplace.json says 1.1.0, plugin.json says 1.2.0, actual release is 1.3.0.
**Fix:** Sync all version references to current version.

## Priority 5: Shared Workspace Detection Utility

**Source:** Framework Architect
**Severity:** MEDIUM — maintenance burden
**Problem:** Active workspace detection (find most-recent status.yaml by mtime) is duplicated across 5 hook scripts. Changes must be applied to all 5.
**Fix:** Extract shared function to a sourced utility file.

## Deferred to Future Cycles

- **Documentation/onboarding walkthrough** (DX Specialist, Ecosystem Analyst) — important for adoption but not blocking. Needs dedicated cycle.
- **Example process** (Ecosystem Analyst) — prerequisite for tutorial, benefits from stable hooks.
- **SessionEnd hook** (Framework Architect) — covers non-graceful exits. Nice-to-have.
- **Multi-pattern composition docs** (Framework Architect) — document how real processes mix patterns.
- **MCP integration narrative** (Ecosystem Analyst) — strategic, not urgent.

## Agent Contributions

| Agent | Key Finding | Unique Insight |
|-------|------------|----------------|
| Feedback Analyst | 9 OQI + 1 PPU, two dominant failure patterns | PR #10 addressed 5/7 sub-problems in #6 |
| Community Manager | None of 3 issues closable yet, need verification | Framework feedback routing is the biggest remaining gap |
| Framework Architect | Hook architecture sound but has agent-specificity bug | 5 scripts duplicate workspace detection logic |
| DX Specialist | Documentation is biggest adoption barrier | Invisible hook system blocks users without context |
| Ecosystem Analyst | Late alpha, not adoption-ready | Version manifests out of sync across 3 files |

## Recommended Scope for Cycle 4

Priorities 1-4 are achievable in this cycle. Priority 5 (shared utility) is a nice-to-have if bandwidth allows. This keeps the cycle focused on: proving hooks work, fixing the two remaining HIGH bugs, closing the remaining issue #6 gaps, and syncing versions.
