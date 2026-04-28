# Cycle 17 — Validation Report

## Summary

All planned changes landed. Test harness passed 148/148 (was 142). Manual trace of the offending Tangled-Roots-V1 scenario against the new gate logic confirms the recurrence is now caught: the gate skips with a clear stderr message instead of demanding feedback at a workspace where no phase advanced.

## Static checks

| Check | Result |
|---|---|
| `grep -c '**claims**' lifecycle.md doctrines.md` | 0, 0 (stale wording removed) |
| `grep -c 'automatically writes' lifecycle.md` | 0 (stale L122 paragraph fixed) |
| `grep -c 'DO NOT register this session' pas-session-start.sh` | 1 (new prohibition present) |
| `grep -c 'Phase Advancement Test' lifecycle.md doctrines.md` | 2, 1 (doctrine + cross-reference) |
| Plugin version (plugin.json) | 1.4.2 |
| Marketplace version | 1.4.2 |

## Test harness

- 148 / 0 fail (was 142 / 0)
- New tests:
  - 3 wording asserts in `pas-session-start.sh` section: `DO NOT register this session`, `DO NOT add a 'sessions:' entry`, `Only the skill that owns the workspace`
  - 3 new C17 phase-advancement gate tests (T-C17-1, T-C17-2, T-C17-3) covering: all pending → skip; all completed + no feedback → fire; mid-cycle → skip via existing pending-short-circuit

## Manual scenario trace

Reproduced the offending status.yaml from `pas-misrouted-and-migration-ts`:

```yaml
process: process-maintainer
instance: pas-misrouted-and-migration-ts
status: in_progress
session_id: 680584a2
current_session: e6d3092e

phases:
  orient:    { status: pending }
  apply:     { status: pending }
  finalize:  { status: pending }
  shutdown:  { status: pending }

sessions:
  - id: e6d3092e
```

Piped a Stop event with `session_id: e6d3092exyz` into `verify-completion-gate.sh`:

```
[PAS] Stop hook: resolved workspace .../status.yaml has no advanced phases —
skipping completion gate (orchestrator-side binding without phase work;
see doctrines.md → Phase Advancement Test)
EXIT=0
```

Before 1.4.2: the gate would have fired (binding matches, all phases technically not pending after the existing `PENDING_COUNT` check fell through — but for any case where the orchestrator had marked phases as completed without doing real work, the gate fired and demanded feedback). After 1.4.2: gate skips cleanly when no phase advanced past `pending`.

## Doctrine coverage

The fix has three independent layers of defense, all now in place:

1. **Hook-side suppression (cycle 16, retained):** SessionStart only refreshes `current_session:` for true reconnects. Fresh sessions don't auto-bind.
2. **Doctrine + wording (cycle 17, new):** Phase Advancement Test in doctrines.md; concrete "creates or claims" definition in lifecycle.md; hardened SessionStart unbound-branch wording. Skill authors and the orchestrator itself are now told explicitly not to register fresh sessions in workspaces they aren't advancing.
3. **Stop-gate phase-advancement check (cycle 17, new):** Even if a layer-1 or layer-2 violation slips through, the gate skips when no phase under `phases:` shows `status: in_progress` or `status: completed`. The owning skill (when it eventually advances a phase) takes over the feedback obligation.

## Dogfooding observation (filed as framework signal)

This very session is running the pre-1.4.1 SessionStart hook (Claude Code cached the hook command at session start before 1.4.1 was installed). The 1.4.0 hook auto-bound my session id `fb520104` to `cycle-16/status.yaml` (which is `status: completed`, not in_progress). The cycle-16 fix is on disk and in the test harness, but only takes effect for sessions started **after** 1.4.1 was installed. This is exactly the **N/N+1 protocol** doctrine in action and reinforces the user's framework-testing-suite request.

The cycle-16/status.yaml mutation observed at the start of execution was **not** committed (reverted before staging). It was harmless in this case but illustrates the substrate-substrate failure mode.

## Per N/N+1 protocol

Cycle 17 is hook-substrate-modifying. Static + harness validation is sufficient for cycle-17 completion. Live behavior validation deferred to **cycle 18**, which should:

1. Open in a fresh consumer-side session (e.g. Tangled-Roots-V1) on 1.4.2.
2. Confirm SessionStart text shows the hardened wording.
3. Trigger the offending pattern (start fresh session, do off-topic work, hit Stop) and confirm the gate skips with the new "no advanced phases" message.
4. Confirm `current_session:` is not written to a foreign workspace.

## Out-of-scope items (filed at shutdown)

- Proper PAS testing framework (per user direction in cycle 17): hook-isolation tests cannot catch the lifecycle-level binding bugs that recurred in cycle 17. End-to-end fixture tests, multi-worktree concurrency tests, skill-side contract tests are the right scope for a separate cycle. → file as framework:pas signal.
