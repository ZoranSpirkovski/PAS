# Cycle 5 Implementation Plan

## Task 1: Fix feedback file deletion (P1 — Issue #13)

**File:** `plugins/pas/hooks/route-feedback.sh`
**Change:** Remove line 196 (`rm "$feedback_file"`) — feedback files must persist as workspace records.

Additionally, add idempotency guard: track which files have already been routed to prevent double-routing on subsequent hook invocations. Use a marker approach: after routing signals from a file, touch a `.routed` sidecar file. Skip files that already have a `.routed` marker.

**Specific edits:**
1. Line 192-197: Replace the loop body to add `.routed` marker check and remove the `rm`:

```bash
echo "$FEEDBACK_FILES" | while read -r feedback_file; do
  [ -f "$feedback_file" ] || continue
  # Skip already-routed files
  [ -f "${feedback_file}.routed" ] && continue
  source_basename=$(basename "$feedback_file" .md)
  parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"
  touch "${feedback_file}.routed"
done
```

2. Add `*.routed` to `.gitignore`.

**Dependencies:** None — can run in parallel with Tasks 2-4.

## Task 2: Extract shared workspace utility (P2)

**New file:** `plugins/pas/hooks/lib/workspace.sh`

```bash
#!/usr/bin/env bash
# Shared workspace detection utility for PAS hooks.

find_active_workspace_status() {
  local workspace_dir="$1"
  if [ ! -d "$workspace_dir" ]; then
    return 1
  fi

  local result
  result=$(find "$workspace_dir" -name "status.yaml" -print 2>/dev/null | while read -r f; do
    echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
  done | sort -rn | head -1 | awk '{print $2}')

  if [ -z "$result" ]; then
    return 1
  fi

  echo "$result"
}
```

**Modified files (5):**

Each hook replaces its inline workspace detection with:
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/workspace.sh"
# ... then later:
ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR") || exit 0
```

| Hook | Lines replaced | New source line |
|------|---------------|-----------------|
| `route-feedback.sh` | 19-35 (entire function) | Source utility + call `find_active_workspace_status "$CWD/workspace"` |
| `check-self-eval.sh` | 31-33 | Replace inline with utility call |
| `verify-completion-gate.sh` | 38-40 | Replace inline with utility call |
| `verify-task-completion.sh` | 34-36 | Replace inline with utility call |
| `pas-session-start.sh` | 32-34 | Replace inline with utility call |

**Dependencies:** None — can run in parallel with Tasks 1, 3-4.

## Task 3: Add discovery verification step (P3 — OQI-02)

**Modified files (2):**

1. `plugins/pas/library/orchestration/discussion.md` — Add verification step after step 6 in Turn-Taking Protocol (after line 35):

```markdown
8. Moderator verifies key claims against source code (read referenced files, check line numbers, confirm behavior) before recording the outcome. Treat agent reports as leads to investigate, not established facts.
```

2. `plugins/pas/library/orchestration/hub-and-spoke.md` — Add verification note to Gate Protocol section (after line 191):

```markdown
**Claim verification:** Before presenting output at a gate, verify key agent claims against source code. Read referenced files, check stated behaviors, confirm line numbers. Treat agent reports as leads to investigate, not established facts. The product owner should never be the first to catch an unverified claim.
```

**Dependencies:** None — can run in parallel with Tasks 1-2, 4.

## Task 4: Housekeeping (P4)

**Changes:**

1. **`.gitignore`** — Add entries:
```
feedback/warnings.log
*.routed
```

2. **Mark resolved signals** — Rename with `resolved-` prefix:
   - `processes/pas-development/feedback/backlog/2026-03-07-orchestrator-OQI-01.md` → add `Status: RESOLVED (cycle 5)` header
   - `processes/pas-development/feedback/backlog/2026-03-07-orchestrator-OQI-03.md` → add `Status: RESOLVED (cycle 5)`
   - `processes/pas-development/feedback/backlog/2026-03-07-orchestrator-STA-01.md` → add `Status: ACKNOWLEDGED (cycle 5)`

3. **`feedback/warnings.log`** — Delete (stale entries referencing old workspace paths; will be gitignored going forward).

**Dependencies:** Task 1 must complete first (`.gitignore` includes `*.routed` from Task 1).

## Parallelization

```
Task 1 (route-feedback.sh fix) ──┐
Task 2 (workspace utility)      ├── all parallel ──→ Task 4 (housekeeping, needs *.routed from T1)
Task 3 (verification step)      ┘
```

Tasks 1, 2, 3 are fully independent. Task 4 depends on Task 1 for the `.routed` gitignore entry but can otherwise run in parallel.

Practical approach: run Tasks 1-3 in parallel, then Task 4 sequentially.

## Verification Checklist

- [ ] `route-feedback.sh` no longer deletes feedback files
- [ ] `.routed` marker prevents double-routing
- [ ] All 5 hooks source `lib/workspace.sh` and detect workspaces correctly
- [ ] `discussion.md` and `hub-and-spoke.md` include verification language
- [ ] Resolved signals marked in backlog
- [ ] `warnings.log` gitignored
- [ ] Plugin version unchanged (no version bump for dev-only changes)
- [ ] All existing hook behavior preserved (no regressions)
