# Cycle 18 — Validation Report

## Summary

All planned changes landed. Test harness 148 → 151 (all pass). Manual trace against the actual offending consumer status.yaml (`pas-misrouted-and-migration-ts` in Tangled-Roots-V1) confirms silent skip — zero stderr, exit 0.

## Test harness

```
Passed: 151
Failed: 0
Total: 151 tests
```

Re-pointed (3 tests, same count):
- C05-7 — substantive-bypass now silent
- C16-5b — cross-session misroute skip now silent
- C17-1 — no-advanced-phases skip now silent

New (3 tests, +3 net):
- C18-1 — gate demand block contains version footer
- C18-2 — check-self-eval demand block contains version footer
- C18-3 — verify-task-completion demand block contains version footer

## Manual scenario trace

Reproduced the consumer scenario that triggered cycle-17:

```
$ echo '{"cwd":".../Tangled-Roots-V1","stop_hook_active":false,"session_id":"eca8ae88xyz"}' \
  | bash plugins/pas/hooks/verify-completion-gate.sh
STDERR: ''
EXIT: 0
PASS: silent skip on consumer's status.yaml
```

The actual file has `current_session: eca8ae88` (binding match) and inline phase format (`orient: in_progress`, `apply: pending`, etc.). The cycle-17 phase-advancement check finds no `^[[:space:]]+status: (in_progress|completed)` matches, fires the skip — and now exits 0 silently. No stderr, no transcript noise.

## Static guards

| Check | Result |
|---|---|
| `grep -c '\[PAS\] Stop hook' plugins/pas/hooks/verify-completion-gate.sh` | 0 (skip-path stderr removed) |
| `grep -c 'substantive response detected' plugins/pas/hooks/check-self-eval.sh` | 0 (audit line removed) |
| `grep -c 'pas_version_footer' plugins/pas/hooks/lib/guards.sh` | 1 (function defined) |
| `grep -c 'pas_version_footer' plugins/pas/hooks/verify-completion-gate.sh` | 1 (called in demand block) |
| `grep -c 'pas_version_footer' plugins/pas/hooks/check-self-eval.sh` | 1 (called in demand block) |
| `grep -c 'pas_version_footer' plugins/pas/hooks/verify-task-completion.sh` | 4 (called in all 4 demand blocks) |
| Plugin version | 1.4.3 |
| Marketplace version | 1.4.3 |

## Behavior change summary

| Path | Before 1.4.3 | After 1.4.3 |
|---|---|---|
| Cycle-16 cross-session misroute | exit 0 + `[PAS] Stop hook: ... does not bind session ...` stderr | exit 0 silent |
| Cycle-17 no-advanced-phases | exit 0 + `[PAS] Stop hook: ... no advanced phases ...` stderr | exit 0 silent |
| Substantive-response bypass (check-self-eval) | exit 0 + `PAS feedback hook INFO: substantive response detected ...` stderr | exit 0 silent |
| Gate demand (real "GATE FAILED") | exit 2 + demand block | exit 2 + demand block + version footer |
| Subagent self-eval demand | exit 2 + demand block | exit 2 + demand block + version footer |
| Task-completion demands (4 cases) | exit 2 + demand block | exit 2 + demand block + version footer |

## Per N/N+1 protocol

Cycle 18 is hook-substrate-modifying. Static + harness validation is sufficient for cycle-18 completion. Live behavior validation in cycle 19 from a fresh session in a consumer project.

Specifically: cycle 19 should confirm in a real conversational session that:

1. Invoking `/process-maintainer` (or any maintainer-style skill) on a long-running workspace produces no `[PAS] Stop hook: ... — skipping completion gate` stderr on conversational yields.
2. The "Ran 3 stop hooks" header still appears (Claude Code emits this; we cannot suppress it) but each hook entry stays collapsed with no expansion.
3. When the orchestrator actually completes all phases without writing feedback, the demand block fires and includes the new version footer.

## Out of scope (deferred to cycle 19+)

- The investigation into why 1.4.0 hooks may sometimes fire on a 1.4.2 user-scoped install. The version footer in cycle-18 demand blocks makes the next inquiry trivial — when a user reports the gate firing, the footer self-attributes the install path. Wait for the next post-1.4.3 transcript before chasing this.
- Phase-boundary feedback redesign — considered, rejected (loses session-level observations). Filed as out-of-scope in cycle-18 priorities.md.
