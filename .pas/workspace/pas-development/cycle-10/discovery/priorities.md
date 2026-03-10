# Cycle 10 — Discovery Priorities

## Summary

Milestone 2 (Reliability & Library Dedup) begins. Two parallel work tracks: plugin infrastructure (PR-scoped) and process improvements (dev-branch direct). All 5 agents reached consensus after resolving priority tension between signal-driven and foundation-first approaches.

## Track A: Plugin Infrastructure (PR to main)

Files under `plugins/pas/`. Dependency chain is sequential.

### A1. Hook Test Harness (PRIORITY: HIGH)
- Create `plugins/pas/hooks/tests/test-hooks.sh` — bash test runner using stdin JSON / exit code contract
- Cover all 5 hooks (check-self-eval, pas-session-start, route-feedback, verify-completion-gate, verify-task-completion) + workspace.sh
- Use the 14 manual test scenarios from `docs/plans/2026-03-07-feedback-enforcement.md` as test spec
- Add edge cases: malformed JSON, missing jq, unicode in feedback files
- Mock `gh issue create` in route-feedback.sh tests
- **Rationale:** Foundation for all subsequent hook changes. Claude Code's hook I/O contract is now documented and stable. 0 automated tests currently exist for 599 lines of hook code.

### A2. Graceful Error Handling in Hooks (PRIORITY: HIGH)
- Depends on A1 (test harness must exist before changing error paths)
- Add jq availability check to all 5 hooks (currently crash silently if jq missing)
- Add informative stderr messages for non-critical failures
- Consider extracting shared `lib/guards.sh` for common guard patterns (jq check, pas-config check, feedback-enabled check) — 4 of 5 hooks duplicate ~40 lines of identical guards
- Handle: malformed JSON input, read-only filesystem, missing workspace
- Keep `set -euo pipefail` as default; add explicit handling per operation

### A3. Fix Issue #19: Agent Feedback Enforcement (PRIORITY: HIGH)
- Depends on A1 (need tests to verify the fix)
- Modify `verify-completion-gate.sh` to parse agent names from status.yaml phases and verify all expected feedback files exist (not just orchestrator)
- Investigate `TeammateIdle` hook event (v2.1.63) as potential enforcement point for TeamCreate agents
- Strengthen lifecycle.md shutdown sequence with explicit enforcement language
- Close GitHub issue #19 after fix is verified

### A4. Feedback Signal Schema (PRIORITY: MEDIUM)
- Create `plugins/pas/library/self-evaluation/signal-schema.md` as single source of truth
- Define: signal types, required fields, target format grammar, priority levels, ID format
- Update self-evaluation/SKILL.md and applying-feedback/SKILL.md to reference the schema
- Option A only (documentation, not programmatic validation) — no route-feedback.sh code changes
- **Rationale:** Triple-source-of-truth problem confirmed (self-evaluation SKILL.md, route-feedback.sh regex, applying-feedback SKILL.md)

### A5. Quick DX Fixes (PRIORITY: LOW, fold into execution)
- Fix GATE acronym: README.md says "Gate Evaluation", self-evaluation/SKILL.md says "Stability Gate" — align to "Stability Gate" (5 min)
- Define "thin launcher" on first use in creating-processes/SKILL.md and SKILL.md routing (10 min)
- Add `/pas:pas` syntax explanation to README Quick Start (5 min)

## Track B: Process Improvements (dev-branch direct)

Files under `processes/pas-development/` and `docs/`. No PR needed. Independent of Track A.

### B1. Data Verification Protocol (PRIORITY: HIGH)
- Addresses 8 HIGH-priority feedback signals (strongest cluster in entire backlog)
- Add data verification norm to `library/orchestration/discussion.md`: quantitative claims must include source command/API call and raw output
- Update community-manager agent definition and issue-triage skill: metrics must be cross-validated (e.g., high clones vs zero stars/forks = flag discrepancy)
- Update ecosystem-analyst agent definition: cite sources for all external claims (already in agent.md — reinforce in skill)
- Add verification step for orchestrator: before accepting quantitative claims in synthesis, verify at least one key metric independently

### B2. Library Dedup Design Doc (PRIORITY: MEDIUM)
- Missing Milestone 1 deliverable (success criterion #9 not met)
- Write design doc to `docs/plans/` covering: migration path, `${CLAUDE_PLUGIN_ROOT}/library/` as primary mechanism, override model, risk analysis
- Implementation deferred to next cycle — design doc only

### B3. Mark Resolved Backlog Signals (PRIORITY: LOW)
- Mark spawn timing signals (3 MEDIUM) as RESOLVED — ready-handshake shipped in cycle 9
- Mark any other signals addressed by cycle 10 changes
- Update feedback-report.md with resolution notes

## Deferred to Future Cycles

- **README with e2e example** — 0 external users, 0 signals. Important but not urgent. Best done AFTER library dedup (so README doesn't document the copy-on-bootstrap model that's about to change).
- **Library dedup implementation** — Needs design doc first (B2 this cycle). Implementation is Milestone 2's largest item.
- **Agent-based hooks for self-eval** — Interesting ecosystem capability (type: "agent" hooks) but adds token cost. Evaluate after bash hook reliability is solid.

## Scope Assessment

- **Track A** (plugin PR): ~4 items, moderate-heavy. Test harness is the bulk.
- **Track B** (dev-branch): ~3 items, light-moderate. Protocol changes + design doc.
- **Estimated execution agents needed:** framework-architect (A1-A3, B2), dx-specialist (A4-A5), feedback-analyst (B1, B3)
- **Risk:** Track A dependency chain means A2/A3 are blocked until A1 completes. Track B has no internal dependencies.

## Agent Consensus

| Agent | Position |
|-------|----------|
| Feedback Analyst | Both tracks in parallel. Data verification (8 HIGH signals) + test harness as foundation. |
| Community Manager | Issue #19 immediately actionable. Sole open issue. |
| Framework Architect | Test harness -> error handling -> issue #19 -> signal schema. Library dedup design doc needed. |
| DX Specialist | GATE mismatch fix, thin launcher definition, signal schema single source of truth, README deferred. |
| Ecosystem Analyst | Hook contract stable, best time for test harness. TeammateIdle hook for issue #19. Both tracks compatible. |
