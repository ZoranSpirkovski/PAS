# Cycle 5 Discovery — Verified Priorities

## Signal Triage

| Signal | Status | Evidence |
|--------|--------|----------|
| STA-01 (workspace lifecycle working) | POSITIVE | Confirmed — HARD REQUIREMENT in hub-and-spoke.md:14, discussion.md:59 |
| OQI-01 (orchestrator skipped workspace) | RESOLVED | HARD REQUIREMENT + SessionStart hook reminders (pas-session-start.sh:74-93) |
| OQI-02 (discovery claims unverified) | UNRESOLVED | No verification step exists in orchestration patterns between agent reports and gate |
| OQI-03 (discovery phase skipped) | RESOLVED | SessionStart hook injects lifecycle context; workspace structure enforces phases |
| Generation scripts (rm -rf + no workspace) | RESOLVED | --base-dir flag added to all 3 creation scripts in cycle 4 |

## Verified Priorities

### P1: Fix `route-feedback.sh` deleting feedback files (Issue #13)

**Root cause confirmed:** `route-feedback.sh` line 196 unconditionally deletes `.md` files from the workspace feedback directory after parsing signals.

```bash
# Line 196 — the smoking gun:
rm "$feedback_file"
```

This is why TeamCreate agent feedback files "appeared and disappeared." The hook fires on agent stop, finds feedback files, parses signals, then deletes the source files. This is NOT a Claude Code sandbox issue — it's the script deleting them.

**Fix:** Remove the `rm "$feedback_file"` line. Feedback files should persist in the workspace as permanent records. The route-feedback hook should parse and route signals without destroying the source.

**Impact:** HIGH — currently breaks the entire feedback system for team agents.

### P2: Extract shared workspace utility from hooks

**5 hooks duplicate identical workspace detection pattern** (3-line find/stat/sort core):

| Hook | Lines |
|------|-------|
| route-feedback.sh | 26-28 |
| check-self-eval.sh | 31-33 |
| verify-completion-gate.sh | 38-40 |
| verify-task-completion.sh | 34-36 |
| pas-session-start.sh | 32-34 |

**Fix:** Create `plugins/pas/hooks/lib/workspace.sh` with shared `find_active_workspace_status()` function. Source it from all 5 hooks. Saves ~49 lines (75% reduction in workspace detection code).

**Impact:** MEDIUM — reduces maintenance burden and prevents divergence.

### P3: Add discovery verification step (OQI-02)

**Problem:** Orchestration patterns lack a step between "collect agent reports" and "present gate summary" where the orchestrator verifies agent claims against source code.

**Fix:** Add verification guidance to `plugins/pas/library/orchestration/discussion.md` in the Turn-Taking Protocol section. After step 6 (agents confirm or raise final objections), add: "Moderator verifies key claims against source code before recording the outcome."

Also add to `hub-and-spoke.md` Gate Protocol: "Before presenting output at a gate, verify agent claims against code. Treat agent reports as leads to investigate, not facts."

**Impact:** MEDIUM — prevents unverified claims from passing gates.

### P4: Housekeeping

1. Add `feedback/warnings.log` to `.gitignore` (runtime log tracked in git)
2. Mark resolved signals in backlog (OQI-01, OQI-03, STA-01)
3. Clean stale warnings from `feedback/warnings.log` (references old workspace paths)

**Impact:** LOW — hygiene only.

## Priority Order

1. **P1** — Fix feedback file deletion (blocks feedback system reliability)
2. **P2** — Extract workspace utility (reduces duplication, prevents future bugs)
3. **P3** — Add verification step (prevents unverified claims at gates)
4. **P4** — Housekeeping (clean up resolved signals and runtime artifacts)
