# Cycle 17 — Implementation Plan

Target release: **PAS plugin 1.4.2**.
Branch: `feature/cycle-17-orchestrator-binding-fix`.

## Commit sequence

Order matters. Doctrine + lifecycle wording goes first because the hook test in C03 will assert against the new SessionStart wording. Substrate-mutating commits (the gate hardening) go late per the **Dogfooding Hazard Awareness** doctrine.

### C01 — Doctrine: Phase Advancement Test

**File:** `plugins/pas/library/orchestration/doctrines.md`

Extend the `Workspace Binding Is Skill-Owned` doctrine with a new "Phase Advancement Test" subsection under **How to apply**:

> **Phase Advancement Test (cycle-17):** Before binding, ask: *is this session about to advance a phase in this workspace?* If no, do not bind. "I see an in-progress workspace and I should register myself somewhere" is not advancing a phase. A fresh session running unrelated work (e.g. user invoked a different skill, or asked an off-topic question) MUST leave the workspace's `status.yaml` untouched: no `current_session:` write, no `sessions:` append, no "off-topic" note added at stop time. The workspace belongs to the session that is actively advancing it.

Add an "Origin" line citing cycle-17 / the consumer transcript and reference the `pas-misrouted-and-migration-ts` recurrence as the concrete incident.

### C02 — Lifecycle: rewrite Session Binding Contract + fix L122 + qualify Ad-Hoc Execution

**File:** `plugins/pas/library/orchestration/lifecycle.md`

Three changes in one commit (all in the same file, no functional code touched):

**1. Section "Session Binding Contract" (currently L26-53)** — rewrite the opening paragraph to define "create or claim" concretely:

> When a skill or process **creates** a workspace (mkdirs the workspace path) or **resumes** a workspace whose phases this session is about to advance, it MUST write the session binding into status.yaml itself. "Resume" means: this session is going to read pending phases and execute them. It does NOT mean "I see the workspace exists, so I should register here."
>
> A fresh session that is *not* advancing any phase in an existing workspace MUST NOT modify that workspace's `status.yaml` — even if a hook output mentions the workspace exists. Read-only inspection is fine; writes are not.

**2. Line ~122 "Session tracking" paragraph** — replace stale text:

> ~~The `pas-session-start.sh` hook automatically writes `current_session` and appends to the `sessions` list when a session begins.~~

becomes

> The `pas-session-start.sh` hook refreshes `current_session:` only when the session id is already in the `sessions:` list (true reconnect). Initial binding is the responsibility of the skill that creates or resumes the workspace — see Session Binding Contract above. Feedback files are named `feedback/orchestrator-{session_id}.md` so the Stop hook can verify that THIS session (not a previous one) produced feedback.

**3. Section "Ad-Hoc Execution" L154-162** — qualify L158:

> ~~1. If a workspace exists for the current cycle, use it — do not create a new one~~

becomes

> 1. If a workspace exists **for the same process and instance** the user is asking you to continue, use it — do not create a new one. If an unrelated in-progress workspace exists, leave it alone — do not register the session there or add notes at stop time.

### C03 — SessionStart hook output: harden unbound-fresh-session branch

**File:** `plugins/pas/hooks/pas-session-start.sh`

Two textual changes inside the heredoc and the unbound-branch echo block:

**1. STARTUP block (currently L79):** add a leading qualifier so it's clear the steps only apply when starting/advancing a PAS process:

> ~~Whether running a formal PAS process or executing an ad-hoc plan, you MUST follow this lifecycle:~~

becomes

> When you are about to start a new PAS process, advance a phase in an existing in-progress one, or run an ad-hoc plan that produces phase outputs, follow this lifecycle:

**2. Unbound-branch echo block (currently L150-159):** harden the wording. After the existing `Detected in-progress workspace at ...` lines, append:

```
echo "  DO NOT register this session in this workspace's status.yaml."
echo "  DO NOT add a 'sessions:' entry, set 'current_session:', or write"
echo "  an 'off-topic' note at stop time. If your work is unrelated, this"
echo "  workspace stays unchanged. Only the skill that owns the workspace"
echo "  may modify it."
```

The existing "To resume, invoke the matching skill" stays.

### C04 — Test harness: assert new SessionStart wording

**File:** `plugins/pas/hooks/tests/test-hooks.sh`

After the existing `PAS_WORKSPACE_MISMATCH_PATH=` assertion (~L278), add three new assertions that the hardened wording is present:

```bash
assert_stdout_contains "DO NOT register this session" \
  "session-start (#cycle-17): unbound branch tells orchestrator not to register"
assert_stdout_contains "DO NOT add a 'sessions:' entry" \
  "session-start (#cycle-17): unbound branch tells orchestrator not to append sessions:"
assert_stdout_contains "Only the skill that owns the workspace" \
  "session-start (#cycle-17): unbound branch attributes ownership to the skill"
```

Test count goes from 142 → 145.

### C05 — Stop-gate phase-mtime sanity check

**File:** `plugins/pas/hooks/verify-completion-gate.sh`

Add a second sanity check after the existing binding-match check at L36-47. If the gate would fire, but no phase under `phases:` has its `status:` set to anything other than `pending` AND `completed_at:` is unset on every phase, the workspace had no phase-level work happen during this session — skip the gate.

Cheaper, safer signal than file mtime: count completed/in_progress phases. Pseudocode:

```bash
# Phase-advancement sanity check (#cycle-17, belt-and-suspenders against
# orchestrator-side bindings to in_progress workspaces where no phase
# actually advanced). If the workspace shows zero phases past `pending`,
# the session did not do PAS work even if `current_session:` matches.
if grep -qE '^\s*status:\s*(in_progress|completed)\s*$' "$ACTIVE_STATUS"; then
  : # at least one phase advanced — proceed with gate
else
  echo "[PAS] Stop hook: resolved workspace ${ACTIVE_STATUS} has no advanced phases — skipping completion gate (orchestrator-side binding without phase work)" >&2
  exit 0
fi
```

Important: this check must run *after* the binding-match check, so the existing mtime-fallback skip still wins for cross-worktree misroutes. New check only fires when binding matches but no phase advanced.

### C06 — Test harness: add C17 phase-advancement gate cases

**File:** `plugins/pas/hooks/tests/test-hooks.sh`

Add a new section `15. C17 — orchestrator-side binding & phase-advancement gate` at the end (before the summary). Three tests:

- **T-C17-1:** binding matches AND all phases pending → gate skipped (exit 0).
- **T-C17-2:** binding matches AND at least one phase `completed` AND no feedback → gate fires (exit 2). Confirms we didn't break the normal "real work happened, demand feedback" path.
- **T-C17-3:** binding matches AND one phase `in_progress` AND no feedback → gate fires (exit 2). Mid-cycle Stop should still demand feedback once orchestrator self-eval is required (well, actually pending phases short-circuit at L59 — so this asserts existing behavior holds).

Test count goes from 145 → 148.

### C07 — Changelogs

**Files:**
- `plugins/pas/hooks/changelog.md` — entry under 1.4.2: SessionStart hardening, gate phase-advancement check.
- `plugins/pas/library/orchestration/changelog.md` — entry: Phase Advancement Test doctrine, lifecycle.md Session Binding Contract rewrite, Ad-Hoc Execution qualifier.

### C08 — Version bump (auto)

`plugins/pas/hooks/lib/bump-version.sh` runs in the SessionEnd / pre-commit and bumps `1.4.1 → 1.4.2` in both `plugin.json` and `.claude-plugin/marketplace.json`. Manual fallback if the auto-bump didn't fire in the commit chain.

## Validation plan

Per **N/N+1 Protocol**: cycle 17 ships the changes; live behavior validation in cycle 18 (or whenever the next cycle starts in this consumer-style scenario). Cycle 17 validation is static:

1. `bash plugins/pas/hooks/tests/test-hooks.sh` — must pass with 148 tests.
2. `grep -n "claims\|automatically writes current_session" plugins/pas/library/orchestration/lifecycle.md` — must return zero hits (regression guard against the old wording sneaking back).
3. `grep -n "DO NOT register this session" plugins/pas/hooks/pas-session-start.sh` — must hit.
4. Manual trace of the offending scenario against the new code path:
   - Construct a synthetic status.yaml with all phases pending and `current_session: <fresh-id>`.
   - Pipe a Stop event with matching `session_id` into `verify-completion-gate.sh`.
   - Assert the new phase-advancement check skips the gate.

## Out of scope

- End-to-end PAS testing framework — filed as framework signal at cycle shutdown.
- Multi-worktree concurrency tests beyond the existing C16 set — same.
- Any consumer-side skill changes (process-maintainer, /intake) — those live in consumer projects and are not under PAS plugin scope.

## Risk & rollback

- **Doctrine/wording-only commits (C01-C04, C07)** — pure docs/test, zero runtime risk. Revert by `git revert` if needed.
- **C05 gate hardening** — runtime risk is low (only adds an additional skip path; never tightens the gate). Worst case: a workspace with all phases still pending but real work happened gets skipped. But "all pending" already means the existing pending-short-circuit at L59 would have skipped anyway — so the new check is a no-op in well-formed cases. Safe.

## Estimated effort

~30 minutes total (no agent dispatch, all solo edits in a single quick cycle).
