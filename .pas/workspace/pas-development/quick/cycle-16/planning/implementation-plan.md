# Cycle 16 — Implementation Plan: Hook Substrate Concurrency Fix

## Goal

Eliminate hook misrouting under concurrent worktree/session runs. Address #173, #174, #162, #160, #156, #155.

Plugin: `pas` 1.4.0 → 1.4.1 (patch, bug fix).
Branch: `feature/cycle-16-concurrency-fix` cut from `dev`.
PR scope: `plugins/pas/` + `.claude-plugin/marketplace.json` only (per CLAUDE.md).

## Doctrine Constraints

- **N/N+1 Protocol** — every commit touches hook substrate. Cycle-16 ships static + harness; live behavior validated cycle-17.
- **Dogfooding hazard** — substrate-mutating commits sequenced last. Verified: cycle-16's session id `885426fe` is in the workspace `sessions:` list, so the new "true-reconnect-only" SessionStart treats this session as bound on any reload.

## Commits

### C1 — Resolver matches `session_id:` field too (#155)

**File:** `plugins/pas/hooks/lib/workspace.sh`

Change Pass 0 grep to match either `current_session:` or `session_id:`:

```diff
-      if grep -q "^current_session:[[:space:]]*${session_id}\b" "$f" 2>/dev/null; then
+      if grep -qE "^(current_session|session_id):[[:space:]]*${session_id}\b" "$f" 2>/dev/null; then
```

**Tests added (test-hooks.sh):**
- T-C16-1a: workspace with `current_session: <id>` resolves via Pass 0 (regression)
- T-C16-1b: workspace with `session_id: <id>` resolves via Pass 0 (new field path)
- T-C16-1c: workspace with neither falls through to Pass 1 (regression)

**Risk to current cycle:** none. Backwards compatible.

### C2 — `route-feedback.sh` path correctness (#156 issues 1 & 3)

**File:** `plugins/pas/hooks/route-feedback.sh`

Two surgical edits:

1. Lines 259-260 and 287-288: replace `$CWD/$PAS_ROOT/feedback` with `${PAS_PROJECT_ROOT:-$CWD}/$PAS_ROOT/feedback` for warnings.log.
2. Lines 80-95 (Tier 3 fallback): replace all `$CWD/$PAS_ROOT/processes` and `$CWD/$PAS_ROOT/library` with `${PAS_PROJECT_ROOT:-$CWD}/...`.

**Tests added:**
- T-C16-2a: warnings.log written to `$PAS_PROJECT_ROOT/.pas/feedback/warnings.log` even when CWD is under `.pas/workspace/...`
- T-C16-2b: Tier 3 finds local process when CWD is a subdirectory of project root

**Risk to current cycle:** none.

### C3 — SessionStart fresh-session-no-bind (#173, #156 issue 2)

**File:** `plugins/pas/hooks/pas-session-start.sh`

Replace lines 42-66 (current unconditional binding block). New behavior:

- Detect `SESSION_BOUND=true` iff `id: ${SESSION_SHORT}` is already in the workspace's status.yaml `sessions:` list (true reconnect).
- On reconnect: refresh `current_session:` (replace existing or add new line), do NOT re-append to `sessions:`.
- On fresh session: do NOT modify status.yaml. Leave the workspace untouched.

Update the display block (lines 144-149) to differentiate bound vs. detected-but-unbound:

- Bound + in_progress → "This session is a reconnect. Read status.yaml to determine where to resume."
- Unbound + in_progress → "Detected in-progress workspace at <path> / Process: <p>/<i> / This session is NOT bound to it. To resume, invoke the matching skill — which will re-bind."
- Bound + completed/other → unchanged "Active workspace: ..." display

Sets shell var `SESSION_BOUND` for use by C4.

**Tests added:**
- T-C16-3a: fresh session id, one in_progress workspace → status.yaml unchanged (no current_session write, no sessions: append)
- T-C16-3b: reconnect (id already in sessions: list) → current_session: refreshed
- T-C16-3c: fresh id, two in_progress workspaces → both untouched

**Risk to current cycle:** low. Cycle-16's session id is already in `cycle-16/status.yaml` `sessions:` list (added at workspace creation), so any reload during this cycle resolves as a reconnect and refreshes correctly.

### C4 — Parseable PAS_WORKSPACE_MISMATCH line (#174)

**File:** `plugins/pas/hooks/pas-session-start.sh`

When `SESSION_BOUND=false` AND `TOP_STATUS=in_progress`, emit two parseable lines BEFORE the English warning so downstream skills/hooks can grep:

```
PAS_WORKSPACE_MISMATCH=<instance-slug>
PAS_WORKSPACE_MISMATCH_PATH=<absolute-workspace-path>
```

Document in `library/orchestration/lifecycle.md` as the canonical machine-readable signal.

**Tests added:**
- T-C16-4a: SessionStart on fresh id with in_progress workspace emits `PAS_WORKSPACE_MISMATCH=<slug>` line
- T-C16-4b: SessionStart on reconnect does NOT emit the mismatch line
- T-C16-4c: SessionStart with no active workspace does NOT emit the line

**Risk to current cycle:** none (additive output).

### C5 — Stop hook session-binding safety (#162, #160)

**File:** `plugins/pas/hooks/verify-completion-gate.sh`

Add a sanity check between resolver call (`guard_active_workspace`) and the gate logic: when SESSION_ID was provided AND the resolved workspace's `current_session:`/`session_id:` does NOT match this session id (i.e., resolver returned via mtime fallback, not Pass 0), warn to stderr and `exit 0` instead of demanding feedback at the wrong path.

Implementation note: `guard_active_workspace` already prefers session_id-matching workspaces. We add a post-resolve assertion:

```bash
if [ -n "$SESSION_SHORT" ] && [ -f "$ACTIVE_STATUS" ]; then
  if ! grep -qE "^(current_session|session_id):[[:space:]]*${SESSION_SHORT}\b" "$ACTIVE_STATUS" 2>/dev/null; then
    echo "[PAS] Stop hook: resolved workspace ${ACTIVE_STATUS} does not bind session ${SESSION_SHORT} — skipping completion gate (not blocking shutdown)" >&2
    exit 0
  fi
fi
```

This means: if the gate would fire on a workspace this session is not bound to, it warns and lets shutdown proceed. The owning session's gate still fires when that session stops.

**Tests added:**
- T-C16-5a: Stop hook with session id + workspace whose current_session matches → gate fires normally (regression)
- T-C16-5b: Stop hook with session id + workspace whose current_session does NOT match (mtime fallback case) → exits 0 with warning to stderr (no block)

**Risk to current cycle:** medium-low. This cycle's workspace WILL have `current_session: 885426fe` (set by SessionStart's existing path before the C3 change is reloaded — confirmed already present in our status.yaml as session 885426fe is in `sessions:`). When this cycle stops, Stop hook's resolver Pass 0 hits, gate fires normally. Sanity check is a no-op for the matching case.

### C6 — Documentation

**Files:**
- `plugins/pas/library/orchestration/lifecycle.md` — Add a "Session Binding Contract" subsection: skills that create or claim a workspace MUST write `current_session: <short-id>` and append to `sessions:`. Reference the new `PAS_WORKSPACE_MISMATCH=` parseable line.
- `plugins/pas/library/orchestration/doctrines.md` — Add a "Hook Substrate — Workspace Binding" doctrine cross-referencing N/N+1 and the contract.
- `plugins/pas/hooks/changelog.md` — Add 1.4.1 entry summarizing C1-C5.

**Risk to current cycle:** none.

### C7 — Version bump + marketplace sync

Run `plugins/pas/hooks/lib/bump-version.sh` (auto-bumps patch in `plugin.json` + `marketplace.json`).

Verify both files show 1.4.1.

## Validation Strategy (Cycle-16 = static only)

Per N/N+1 doctrine, cycle-16 validation is static:

1. `bash -n plugins/pas/hooks/*.sh plugins/pas/hooks/lib/*.sh` — syntax check
2. `bash plugins/pas/hooks/tests/test-hooks.sh` — full harness must pass; expect ≥125 tests (was 117)
3. `grep` checks: confirm new regex in workspace.sh, confirm `${PAS_PROJECT_ROOT:-$CWD}` everywhere in route-feedback.sh, confirm `PAS_WORKSPACE_MISMATCH=` literal in pas-session-start.sh
4. Version files show 1.4.1 in both plugin.json and marketplace.json

Live-behavior validation deferred to cycle-17:

- Open a fresh session in a parallel worktree while another in-progress workspace exists; confirm no auto-bind
- Confirm SessionStart emits PAS_WORKSPACE_MISMATCH= line in the parallel-worktree case
- Confirm Stop hook does not misroute when session_id + sibling workspace are both in_progress

This becomes the cycle-17 validation checklist linked from the PR.

## Release

PR title: `Cycle 16: Fix hook concurrency cluster (#173, #174, #162, #160, #156, #155)`
PR body sections: Summary (per-issue closes line), Validation (static), N+1 Live Validation Checklist (deferred to next cycle), Test plan.

After merge to main: merge main back into dev (CLAUDE.md / pr-management Step 6).

## Issues Closed

- Closes #173 — SessionStart auto-binds fresh sessions to wrong workspace
- Closes #174 — Emit parseable PAS_WORKSPACE_MISMATCH=<slug>
- Closes #162 — Stop hook misroutes to sibling worktree's workspace
- Closes #160 — [Feedback] OQI-03: Stop hook gate misrouted
- Closes #156 — Three secondary hook substrate issues (route-feedback CWD, current_session overwrite, missing local: namespace covered via Tier-3 fix)
- Closes #155 — Resolver should match session_id field

## Approval Gate

Product owner: confirm plan, then proceed to execution.
