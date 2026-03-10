# Issue Triage Report — Cycle 4 Discovery

**Date:** 2026-03-07
**Agent:** Community Manager
**Open issues:** 3 (#6, #11, #12)
**Recent merged PRs:** #10, #9, #5, #4, #2

---

## Issue Status Matrix

### Issue #6 — Feedback system doesn't work: workspace lifecycle, hook routing, self-eval, and enforcement gaps

**Severity:** HIGH | **Sub-problems:** 7

| # | Sub-problem | Status | Addressed by | Notes |
|---|-------------|--------|--------------|-------|
| 1 | Workspace lifecycle not enforced | FIXED | PR #10 — `pas-session-start.sh` (SessionStart hook) injects workspace creation instructions; orchestration patterns (`solo.md`, `hub-and-spoke.md`, `sequential-agents.md`) now create `[PAS]` tasks at startup | Needs verification in a live session |
| 2 | `route-feedback.sh` path resolution wrong for plugin-internal artifacts | FIXED | PR #10 — `route-feedback.sh` lines 47-50, 55-59, 68-71 add fallback `find` into `$CWD/plugins/` for processes, agents, and skills | Needs verification that `process:pas-development` routes correctly now |
| 3 | Self-eval relies solely on hooks | FIXED | PR #10 — Self-eval is now an explicit `[PAS] Self-evaluation` task in orchestration patterns, hooks are the safety net | The structural fix is correct: task + hook gate = belt and suspenders |
| 4 | Feedback doesn't happen unless user demands it | FIXED | PR #10 — `verify-completion-gate.sh` (Stop hook) blocks exit without feedback; `verify-task-completion.sh` (TaskCompleted hook) blocks task completion without deliverables | This is the core structural enforcement. 5-session streak of skipped self-eval should end. |
| 5 | Framework feedback doesn't route to GitHub issues | PARTIALLY FIXED | PR #10 — `pas-session-start.sh` instructs orchestrator to route `framework:pas` signals as GitHub issues at shutdown; `route-feedback.sh` returns empty for `framework:*` targets (lines 75-78) | The hook deliberately does NOT create GitHub issues itself. It relies on the orchestrator reading the SessionStart instructions and manually running `gh issue create`. No structural enforcement exists for this — it's still instruction-based. |
| 6 | `creating-processes/SKILL.md` lost hooks step | NOT FIXED | Not in PR #10 scope | The hooks determination step was dropped during v1.2.0 simplification and has not been restored. |
| 7 | Generation scripts can destroy existing processes | NOT FIXED | Not in PR #10 scope | Scripts still generate into CWD `processes/` and `rm -rf` cleanup can hit real process directories. |

**Closability:** NOT closable. Sub-problems 5 (partial), 6, and 7 remain unresolved. Sub-problems 1-4 need at least one clean session to verify the hooks actually prevent the failure mode.

---

### Issue #11 — Orchestrator does not recognize or use existing workspace

**Severity:** HIGH

| Aspect | Status | Addressed by | Notes |
|--------|--------|--------------|-------|
| SessionStart surfaces active workspaces | FIXED | PR #10 — `pas-session-start.sh` lines 96-109 detect and display active workspace path, process name, instance, and status | The hook prints "This session may be a continuation. Read status.yaml to determine where to resume." when status is `in_progress` |
| `executing-plans` skill lacks PAS lifecycle awareness | UNVERIFIED | PR #10 provides context injection, but the skill itself was not modified | Issue explicitly says: "Verify this works in the next session. If the orchestrator still ignores it, the executing-plans skill may need a PAS-aware preamble." |

**Closability:** NEEDS VERIFICATION. The SessionStart hook provides the fix mechanism, but the issue itself requests verification before closing. If cycle 4 shows the orchestrator recognizing and using the active workspace, this can be closed. If not, a skill-level fix is needed.

---

### Issue #12 — Self-evaluation skipped for 5th consecutive session

**Severity:** HIGH | **Frequency:** 5/5 sessions

| Aspect | Status | Addressed by | Notes |
|--------|--------|--------------|-------|
| Stop hook blocks exit without feedback | IMPLEMENTED | PR #10 — `verify-completion-gate.sh` exits with code 2 if all phases complete but no `orchestrator-{session_id}.md` exists | Hard gate: cannot stop without writing feedback |
| TaskCompleted hook blocks task without deliverable | IMPLEMENTED | PR #10 — `verify-task-completion.sh` blocks `[PAS] Self-evaluation` task completion if feedback file missing | Belt-and-suspenders with Stop hook |
| SessionStart injects lifecycle instructions | IMPLEMENTED | PR #10 — `pas-session-start.sh` outputs full startup/shutdown checklist | Contextual reminder at conversation start |
| Session ID tracking prevents false positives | IMPLEMENTED | PR #10 — `current_session` written to `status.yaml`, feedback files keyed by session ID | Prevents old feedback from satisfying current session check |

**Closability:** NEEDS VERIFICATION. The issue explicitly says "This issue tracks whether the hooks actually solve the problem." The hooks are implemented and structurally sound, but zero sessions have run with them active. Cycle 4 is the first real test. If self-eval happens without user prompting, close this issue.

---

## Summary: Closability Assessment

| Issue | Can close now? | What's needed |
|-------|---------------|---------------|
| #6 | NO | Sub-problems 6 and 7 are untouched. Sub-problem 5 is partial. Sub-problems 1-4 need verification. |
| #11 | AFTER VERIFICATION | One successful session where orchestrator recognizes existing workspace |
| #12 | AFTER VERIFICATION | One successful session where self-eval happens without user prompting |

**Recommendation:** Do not close any issues this cycle. Run cycle 4 as the verification session. If hooks work as designed, #11 and #12 can be closed at end of cycle. #6 needs scoped follow-up work for sub-problems 5 (full), 6, and 7.

---

## Missing Coverage

Problems mentioned in issues that hooks do NOT address:

1. **Framework feedback to GitHub issues (Issue #6, sub-problem 5):** The `route-feedback.sh` hook explicitly returns empty for `framework:*` targets. There is no hook that runs `gh issue create`. The enforcement is purely instructional (SessionStart message tells the orchestrator to do it). An orchestrator that ignores instructions will still skip this step, and no hook will block it.

2. **Creating-processes missing hooks step (Issue #6, sub-problem 6):** This is a skill content gap, not a hook gap. The `creating-processes/SKILL.md` needs its hooks determination step restored. No hook can enforce this — it requires editing the skill.

3. **Generation script safety (Issue #6, sub-problem 7):** This is a script design issue. Hooks cannot prevent `rm -rf` on real process directories. Needs `--base-dir` flag or isolated test directories.

4. **Executing-plans PAS awareness (Issue #11):** The SessionStart hook surfaces context, but if the `executing-plans` skill doesn't read it, the orchestrator may still ignore existing workspaces. This is a skill-level gap.

---

## External Signals from PR History

| PR | Signal |
|----|--------|
| #10 (feedback-enforcement-v2) | Second attempt — #9 was rescoped because it included non-plugin files. Shows the PR scope convention (`plugins/pas/` only) is being enforced. |
| #9 (feedback-enforcement) | Superseded by #10. The iteration suggests the team is learning to separate plugin changes from dev-branch artifacts. |
| #5 (generation-scripts) | The PR that triggered issue #6 sub-problem 7 (script testing destroyed 53 files). Generation tooling is a user-facing feature that needs hardening. |
| #4 (creating-hooks skill) | Added hooks as a first-class PAS concept. Foundation for PR #10's work. |
| #2 (apply-feedback) | First feedback application cycle. The feedback system improvements (#10) are a direct response to this cycle's lessons. |

**Pattern:** The project is in a rapid feedback-on-feedback loop — each cycle reveals gaps in the feedback system itself. The hooks from PR #10 are the first structural enforcement attempt. Cycle 4 is the critical validation point. If the hooks work, the project can shift focus from meta-problems (feedback about feedback) to actual feature work.
