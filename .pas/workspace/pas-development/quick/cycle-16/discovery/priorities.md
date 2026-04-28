# Cycle 16 — Discovery: Hook Substrate Concurrency Cluster

## Directive

Fix the cluster of open issues that all stem from one root cause: **PAS hooks misroute to the wrong workspace under concurrent worktree/session runs.**

In scope: #173, #174, #162, #160, #156, #155.

## Root-Cause Map

The cluster is one substrate-level race surfacing in three places.

```
                         ┌─────────────────────────────────────────────┐
                         │ Workspace resolver: find_active_workspace_  │
                         │ status() in lib/workspace.sh                │
                         │                                             │
                         │ Pass 0: match current_session: <id>         │
                         │ Pass 1: most-recent in_progress by mtime    │
                         │ Pass 2: most-recent any                     │
                         └────────────────┬────────────────────────────┘
                                          │
                  ┌───────────────────────┼───────────────────────────┐
                  ▼                       ▼                           ▼
        SessionStart hook         Stop hook (gate)              route-feedback.sh
        - Calls resolver          - Calls resolver              - Independent path bug
        - Writes current_session  - Demands feedback file       - Uses $CWD/.pas/...
          unconditionally           at resolved path              when CWD is under .pas/
        - Pass 0 misses on a                                      → recursive .pas/.pas/
          fresh session →                                       - Tier 3 also uses $CWD
          Pass 1 picks wrong
          sibling → fresh
          session clobbers
          unrelated workspace
```

### The Three Symptoms

**A. Resolver field name (#155).** Pass 0 only matches `^current_session:`. Processes that record session under `session_id:` (the natural choice for many process docs) silently miss Pass 0, so resolver always falls through to mtime. With parallel worktrees, mtime is a coin flip biased toward the latest-touched sibling.

**B. SessionStart auto-binds fresh sessions (#173, #156 issue 2).** Current behavior: every fresh session writes `current_session: <new>` into whatever the resolver returns — and since Pass 0 misses for a fresh id, the resolver returns whatever mtime favors. Effects:

- Fresh sessions clobber unrelated in_progress workspaces' bindings.
- Stop gate later demands feedback from sessions that never ran any phase.
- Real-world: one workspace accumulated 6 session ids in 30min from auto-bound fresh sessions that never touched files.

**C. Stop hook fallback misroute (#162, #160).** When `current_session:` is null/missing, Stop hook's resolver also falls through to mtime — and demands feedback at a sibling worktree's `feedback/` dir. The session worked at workspace X but is blocked because workspace Y's gate isn't satisfied.

### Two Independent Path Bugs in `route-feedback.sh` (#156 issues 1 & 3)

**D. Warnings log uses `$CWD/$PAS_ROOT/feedback/`.** When the agent's CWD is somewhere under `.pas/workspace/<X>/`, this creates `.pas/workspace/<X>/.pas/feedback/warnings.log` — a recursive `.pas/.pas` path that pollutes the workspace tree.

**E. Tier 3 process/agent/skill fallback uses `$CWD`.** Same root cause — Tier 3 only finds local processes when the agent ran from the project root. Subagent CWDs differ; signals get dropped to "Unknown target" instead of routing.

### The Missing Contract (#174)

Even after fixes above land, a downstream skill that wants to *gate* on workspace-binding mismatch must parse the SessionStart hook's English warning. That's brittle — a copy edit silently breaks the gate. Need a parseable, machine-readable line: `PAS_WORKSPACE_MISMATCH=<slug>` and `PAS_WORKSPACE_MISMATCH_PATH=<path>`.

## Fix Strategy

Each fix is small. The interaction matters: get binding semantics right (B) and field matching right (A) and the rest of the cluster (#162, #160) collapses without per-symptom patches.

### Doctrine Constraints

- **N/N+1 Protocol applies.** Every change in this cycle touches hook substrate (resolver, SessionStart, Stop, route-feedback). Cycle-16 ships static + harness validation. Live behavior validated cycle-17 from a fresh session.
- **Dogfooding hazard.** Sequence substrate-mutating commits late. The current cycle session has `current_session: 885426fe` already in this workspace's `sessions:` list, so the new SessionStart's "true-reconnect-only" rule is safe for this cycle's own continuation.

### Ordered Fix List

| # | Issue(s) | File(s) | Risk to current cycle |
|---|----------|---------|----------------------|
| 1 | #155 | `lib/workspace.sh` | None (extends Pass 0 regex; backwards compatible) |
| 2 | #156 (issues 1 & 3) | `route-feedback.sh` | None (path correctness, no resolver semantics) |
| 3 | #173, #156 (issue 2) | `pas-session-start.sh` | Low — current cycle's session id is already in `sessions:` list, so reconnect path triggers normally |
| 4 | #174 | `pas-session-start.sh` | None (additive output) |
| 5 | #162, #160 | `verify-completion-gate.sh` (+ `lib/workspace.sh` opt) | Medium — affects this cycle's own shutdown. Defer the strictest mode (refuse mtime fallback when session_id given) behind a config knob, default to "warn-and-fall-back" so this cycle can still ship |
| 6 | docs | `library/orchestration/lifecycle.md`, `library/orchestration/doctrines.md` | None |
| 7 | version + changelog | `plugin.json`, `marketplace.json`, `changelog.md` | None |

### Test Harness Plan

Add tests for:

- T1: resolver matches `session_id:` field (Pass 0 broadened)
- T2: route-feedback warnings.log writes to `$PAS_PROJECT_ROOT/.pas/feedback/`, not `$CWD/.pas/...`
- T3: route-feedback Tier 3 fallback uses PAS_PROJECT_ROOT
- T4: SessionStart on fresh id with no `sessions:` membership does NOT modify status.yaml
- T5: SessionStart on reconnect (id already in `sessions:`) refreshes `current_session:`
- T6: SessionStart with two in_progress workspaces + fresh id leaves both untouched (no auto-bind)
- T7: SessionStart emits `PAS_WORKSPACE_MISMATCH=<slug>` line for unbound-but-detected case
- T8: Stop hook with session_id provided + no Pass-0 match warns and skips (no mtime misroute)

Existing harness: 117 tests on dev (per cycle-14 memory). Target: 125+ after this cycle.

## Out of Scope

- Skill-side binding contract enforcement (skills explicitly writing their own `current_session:` on workspace creation). The hook fix relies on skills doing this; documenting it in `lifecycle.md` is enough for now. PAS-internal processes already write status.yaml at startup (the lifecycle.md spec).
- Migrating downstream consumers' processes to the `session_id:` field convention. The resolver fix is the universal patch.
- Outbox draining / propagation tooling — orthogonal.

## Approval Gate

Product owner: confirm the ordered fix list, then proceed to planning.
