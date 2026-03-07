# Feedback Enforcement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make feedback structurally unavoidable using Claude Code's full hook lifecycle (SessionStart, TaskCompleted, SubagentStop, Stop) instead of relying on text-level instructions the orchestrator can skip. Also integrate PAS process phases with Claude Code's task system so predictable work is tracked and enforceable.

**Architecture:** Four enforcement layers, each catching what the previous one misses:

1. **SessionStart hook** — injects PAS lifecycle context at session start (workspace, feedback, shutdown requirements)
2. **Task creation** — orchestration patterns create Claude Code tasks for each phase + shutdown steps, making work visible and trackable
3. **TaskCompleted hook** — blocks task completion until deliverables exist on disk (e.g., can't complete "Self-evaluation" task without `feedback/orchestrator.md`)
4. **Stop hook** — final safety net, blocks session end if all phases are done but feedback is missing

Plus enhanced SubagentStop blocking for team members.

**Session tracking:** Each session gets a short ID (first 8 chars of Claude Code's `session_id`). Feedback files are named `feedback/orchestrator-{session_id}.md`. The Stop hook checks for a file matching the *current* session — feedback from a previous session doesn't count. `status.yaml` tracks all sessions with their feedback status.

**How the hooks enforce:**
- `exit 0` = allow the action
- `exit 2` = **block the action**, stderr message becomes feedback Claude sees and must act on
- `stop_hook_active` field prevents infinite blocking loops on Stop

---

### Task 1: Create `pas-session-start.sh` (SessionStart hook)

**Files:**
- Create: `plugins/pas/hooks/pas-session-start.sh`

**Step 1: Write the script**

The SessionStart hook detects PAS projects and injects lifecycle context into Claude's conversation. stdout from SessionStart becomes context Claude sees.

```bash
#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: injects PAS lifecycle context and records session tracking.
# stdout from this hook becomes context Claude sees in its conversation.
# Also writes current_session to status.yaml so the Stop hook can verify
# feedback was written by THIS session, not a previous one.

INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Guard: only run in PAS repos
PAS_CONFIG="$CWD/pas-config.yaml"
if [ ! -f "$PAS_CONFIG" ]; then
  exit 0
fi

FEEDBACK_STATUS=$(grep -o 'feedback:[[:space:]]*\w*' "$PAS_CONFIG" | head -1 | awk '{print $NF}')

# Derive short session ID (first 8 chars)
SESSION_SHORT=""
if [ -n "$SESSION_ID" ]; then
  SESSION_SHORT=$(echo "$SESSION_ID" | cut -c1-8)
fi

# Check for active workspace
ACTIVE_STATUS=""
WORKSPACE_DIR="$CWD/workspace"
if [ -d "$WORKSPACE_DIR" ]; then
  ACTIVE_STATUS=$(find "$WORKSPACE_DIR" -name "status.yaml" -print 2>/dev/null | while read -r f; do
    echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
  done | sort -rn | head -1 | awk '{print $2}')
fi

# Record session in status.yaml (if active workspace exists)
if [ -n "$ACTIVE_STATUS" ] && [ -n "$SESSION_SHORT" ]; then
  TIMESTAMP=$(date -Iseconds)

  # Write current_session marker
  if grep -q '^current_session:' "$ACTIVE_STATUS" 2>/dev/null; then
    sed -i "s/^current_session:.*/current_session: ${SESSION_SHORT}/" "$ACTIVE_STATUS"
  else
    echo "current_session: ${SESSION_SHORT}" >> "$ACTIVE_STATUS"
  fi

  # Append to sessions list if not already recorded
  if ! grep -q "id: ${SESSION_SHORT}" "$ACTIVE_STATUS" 2>/dev/null; then
    if ! grep -q '^sessions:' "$ACTIVE_STATUS" 2>/dev/null; then
      echo "" >> "$ACTIVE_STATUS"
      echo "sessions:" >> "$ACTIVE_STATUS"
    fi
    cat >> "$ACTIVE_STATUS" <<EOF
  - id: ${SESSION_SHORT}
    started_at: ${TIMESTAMP}
    completed_at: ~
    feedback_collected: false
EOF
  fi
fi

# Build context message
if [ -n "$SESSION_SHORT" ]; then
  SESSION_CONTEXT="Session ID: ${SESSION_SHORT}"
else
  SESSION_CONTEXT="Session ID: unknown"
fi

cat <<EOF
PAS Framework Active (feedback: ${FEEDBACK_STATUS})
${SESSION_CONTEXT}

When running a PAS process, you MUST follow this lifecycle:

STARTUP (before any work):
1. Create workspace: mkdir -p workspace/{process}/{slug}/{discovery,planning,execution/changes,validation,feedback}
2. Write status.yaml with all phases as pending
3. Create Claude Code tasks for each phase AND for shutdown steps:
   - One task per phase from process.md
   - Task: "[PAS] Self-evaluation" — write feedback/orchestrator-{session_id}.md
   - Task: "[PAS] Route framework signals" — file framework:pas signals as GitHub issues
   - Task: "[PAS] Finalize status" — set status.yaml to completed

SHUTDOWN (after all phases complete):
1. Write self-evaluation to workspace/{process}/{slug}/feedback/orchestrator-${SESSION_SHORT:-SESSION_ID}.md
2. Route any framework:pas signals as GitHub issues
3. Update status.yaml: set status to completed with completed_at timestamp
4. Mark all shutdown tasks as completed

ENFORCEMENT: Hooks will block you from stopping or completing tasks if deliverables are missing.
Feedback files MUST include your session ID (${SESSION_SHORT:-unknown}) in the filename.
EOF

# If there's an active workspace, show its status
if [ -n "$ACTIVE_STATUS" ]; then
  ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
  TOP_STATUS=$(grep '^status:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}')
  PROCESS_NAME=$(grep '^process:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}')
  INSTANCE=$(grep '^instance:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}')

  echo ""
  echo "Active workspace: ${PROCESS_NAME}/${INSTANCE} (status: ${TOP_STATUS})"
  echo "Path: ${ACTIVE_WORKSPACE}"

  if [ "$TOP_STATUS" = "in_progress" ]; then
    echo "This session may be a continuation. Read status.yaml to determine where to resume."
  fi
fi

exit 0
```

**Step 2: Make it executable**

Run: `chmod +x plugins/pas/hooks/pas-session-start.sh`

**Step 3: Commit**

```bash
git add plugins/pas/hooks/pas-session-start.sh
git commit -m "Add pas-session-start.sh: injects PAS lifecycle context at session start"
```

---

### Task 2: Create `verify-completion-gate.sh` (Stop hook)

**Files:**
- Create: `plugins/pas/hooks/verify-completion-gate.sh`

**Step 1: Write the script**

The Stop hook fires when Claude finishes any response. It only blocks when all phases are completed but feedback is missing. `stop_hook_active` prevents infinite loops.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Stop hook: blocks Claude from stopping when work is done but feedback is missing.
# Only blocks when ALL phases are completed and no feedback file exists for the
# current session. Uses session_id from status.yaml (written by SessionStart hook)
# to check for session-specific feedback: feedback/orchestrator-{session_id}.md.
# Uses stop_hook_active to prevent infinite blocking loops.

INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Prevent infinite loops: if we already blocked once, let Claude stop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Guard: only run in PAS repos with feedback enabled
PAS_CONFIG="$CWD/pas-config.yaml"
if [ ! -f "$PAS_CONFIG" ]; then
  exit 0
fi

FEEDBACK_STATUS=$(grep -o 'feedback:[[:space:]]*\w*' "$PAS_CONFIG" | head -1 | awk '{print $NF}')
if [ "$FEEDBACK_STATUS" != "enabled" ]; then
  exit 0
fi

# Find active workspace (most recently modified status.yaml)
WORKSPACE_DIR="$CWD/workspace"
if [ ! -d "$WORKSPACE_DIR" ]; then
  exit 0
fi

ACTIVE_STATUS=$(find "$WORKSPACE_DIR" -name "status.yaml" -print 2>/dev/null | while read -r f; do
  echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
done | sort -rn | head -1 | awk '{print $2}')

if [ -z "$ACTIVE_STATUS" ]; then
  exit 0
fi

ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"

# Check: are there any pending phases?
PENDING_COUNT=$(grep -c '^\s*status: pending' "$ACTIVE_STATUS" 2>/dev/null || echo "0")

# If phases are still pending, work is in progress — don't block
if [ "$PENDING_COUNT" -gt 0 ]; then
  exit 0
fi

# Derive short session ID
SESSION_SHORT=""
if [ -n "$SESSION_ID" ]; then
  SESSION_SHORT=$(echo "$SESSION_ID" | cut -c1-8)
else
  # Fallback: read current_session from status.yaml
  SESSION_SHORT=$(grep '^current_session:' "$ACTIVE_STATUS" 2>/dev/null | awk '{print $2}')
fi

# All phases completed. Check for session-specific feedback.
if [ -n "$SESSION_SHORT" ]; then
  # Session-aware check: look for feedback/orchestrator-{session_id}.md
  SESSION_FEEDBACK="$FEEDBACK_DIR/orchestrator-${SESSION_SHORT}.md"
  if [ -f "$SESSION_FEEDBACK" ]; then
    exit 0
  fi
  EXPECTED_FILE="orchestrator-${SESSION_SHORT}.md"
else
  # No session ID available — fall back to any orchestrator feedback file
  if ls "$FEEDBACK_DIR"/orchestrator*.md 1>/dev/null 2>&1; then
    exit 0
  fi
  EXPECTED_FILE="orchestrator-{session_id}.md"
fi

# BLOCK: All phases completed but no feedback for this session
cat >&2 <<EOF
COMPLETION GATE FAILED

All phases are completed but you have not written your self-evaluation for this session.

Before stopping, you MUST:
1. Write self-evaluation to ${FEEDBACK_DIR}/${EXPECTED_FILE}
   - Use library/self-evaluation/SKILL.md for the format
   - If nothing went wrong, write "No issues detected."
2. Route any framework:pas signals as GitHub issues
3. Update status.yaml: set status to completed and completed_at timestamp

You cannot stop until these steps are done.
EOF
exit 2
```

**Step 2: Make it executable**

Run: `chmod +x plugins/pas/hooks/verify-completion-gate.sh`

**Step 3: Commit**

```bash
git add plugins/pas/hooks/verify-completion-gate.sh
git commit -m "Add verify-completion-gate.sh: blocks session end without feedback"
```

---

### Task 3: Create `verify-task-completion.sh` (TaskCompleted hook)

**Files:**
- Create: `plugins/pas/hooks/verify-task-completion.sh`

**Step 1: Write the script**

The TaskCompleted hook fires when any task is marked complete via TaskUpdate. It checks the task subject for PAS shutdown tasks and verifies deliverables exist on disk before allowing completion.

```bash
#!/usr/bin/env bash
set -euo pipefail

# TaskCompleted hook: blocks PAS shutdown tasks from completing
# until their deliverables exist on disk.
#
# Matched tasks (by subject pattern):
#   "[PAS] Self-evaluation" → feedback/orchestrator.md must exist
#   "[PAS] Finalize status" → status.yaml must have status: completed
#   "[PAS] Route framework signals" → allowed (can't verify GitHub issues from bash)

INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')

# Guard: only run in PAS repos
PAS_CONFIG="$CWD/pas-config.yaml"
if [ ! -f "$PAS_CONFIG" ]; then
  exit 0
fi

# Only act on PAS-prefixed tasks
if ! echo "$TASK_SUBJECT" | grep -q '^\[PAS\]'; then
  exit 0
fi

# Find active workspace
WORKSPACE_DIR="$CWD/workspace"
if [ ! -d "$WORKSPACE_DIR" ]; then
  exit 0
fi

ACTIVE_STATUS=$(find "$WORKSPACE_DIR" -name "status.yaml" -print 2>/dev/null | while read -r f; do
  echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
done | sort -rn | head -1 | awk '{print $2}')

if [ -z "$ACTIVE_STATUS" ]; then
  exit 0
fi

ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"

# Check by task type
case "$TASK_SUBJECT" in
  *"Self-evaluation"*)
    # Check for session-specific feedback file
    CURRENT_SESSION=$(grep '^current_session:' "$ACTIVE_STATUS" 2>/dev/null | awk '{print $2}')
    if [ -n "$CURRENT_SESSION" ]; then
      ORCHESTRATOR_FEEDBACK="$FEEDBACK_DIR/orchestrator-${CURRENT_SESSION}.md"
    else
      # Fallback: accept any orchestrator feedback file
      ORCHESTRATOR_FEEDBACK=$(ls "$FEEDBACK_DIR"/orchestrator*.md 2>/dev/null | head -1)
    fi

    if [ -z "$ORCHESTRATOR_FEEDBACK" ] || [ ! -f "$ORCHESTRATOR_FEEDBACK" ]; then
      EXPECTED="orchestrator-${CURRENT_SESSION:-SESSION_ID}.md"
      cat >&2 <<EOF
Cannot complete "Self-evaluation" task: ${FEEDBACK_DIR}/${EXPECTED} does not exist.

Write your self-evaluation to this file before marking the task complete.
Use library/self-evaluation/SKILL.md for the format.
EOF
      exit 2
    fi
    ;;

  *"Finalize status"*)
    TOP_STATUS=$(grep '^status:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}')
    COMPLETED_AT=$(grep '^completed_at:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}')

    if [ "$TOP_STATUS" != "completed" ] || [ "$COMPLETED_AT" = "~" ] || [ -z "$COMPLETED_AT" ]; then
      cat >&2 <<EOF
Cannot complete "Finalize status" task: status.yaml is not finalized.

Update ${ACTIVE_STATUS}:
- Set top-level status to "completed"
- Set completed_at to current ISO timestamp
EOF
      exit 2
    fi
    ;;

  *"Initialize workspace"*)
    if [ ! -d "$FEEDBACK_DIR" ]; then
      cat >&2 <<EOF
Cannot complete "Initialize workspace" task: workspace feedback directory does not exist.

Create the workspace directory structure:
  mkdir -p ${ACTIVE_WORKSPACE}/{discovery,planning,execution/changes,validation,feedback}
EOF
      exit 2
    fi
    ;;
esac

# All checks passed (or task type not enforced)
exit 0
```

**Step 2: Make it executable**

Run: `chmod +x plugins/pas/hooks/verify-task-completion.sh`

**Step 3: Commit**

```bash
git add plugins/pas/hooks/verify-task-completion.sh
git commit -m "Add verify-task-completion.sh: blocks PAS task completion without deliverables"
```

---

### Task 4: Enhance `check-self-eval.sh` (SubagentStop blocking)

**Files:**
- Modify: `plugins/pas/hooks/check-self-eval.sh:61-66`

**Step 1: Change from warning (exit 0) to blocking (exit 2)**

Replace the final section (lines 61-66):

Old:
```bash
# No self-eval found — log warning with agent_id
WARNINGS_DIR="$CWD/feedback"
mkdir -p "$WARNINGS_DIR"
echo "[$(date -Iseconds)] WARNING: Agent '$AGENT_ID' shutdown without writing self-eval to $FEEDBACK_DIR" >> "$WARNINGS_DIR/warnings.log"

exit 0
```

New:
```bash
# No self-eval found — block subagent from stopping
cat >&2 <<EOF
SELF-EVALUATION MISSING

Agent '${AGENT_ID}' is shutting down without writing self-evaluation.

Before stopping, write your self-evaluation to:
  ${FEEDBACK_DIR}/${AGENT_ID}.md

Use library/self-evaluation/SKILL.md for the format.
If nothing went wrong, write "No issues detected."
EOF
exit 2
```

**Step 2: Commit**

```bash
git add plugins/pas/hooks/check-self-eval.sh
git commit -m "Enhance check-self-eval.sh: exit 2 to block subagent without feedback"
```

---

### Task 5: Update hooks.json — register all enforcement hooks

**Files:**
- Modify: `plugins/pas/hooks/hooks.json`

**Step 1: Replace hooks.json with complete hook registration**

Old structure (2 hooks, both passive):
- SubagentStop → check-self-eval.sh (warning only)
- Stop → route-feedback.sh (routing only)

New structure (5 hook registrations across 4 lifecycle events):
- SessionStart → pas-session-start.sh (context injection)
- SubagentStop → check-self-eval.sh (blocking)
- TaskCompleted → verify-task-completion.sh (blocking)
- Stop → verify-completion-gate.sh (blocking)
- Stop → route-feedback.sh (routing, runs after gate)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pas-session-start.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/check-self-eval.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/verify-task-completion.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/verify-completion-gate.sh",
            "timeout": 10
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/route-feedback.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Step 2: Commit**

```bash
git add plugins/pas/hooks/hooks.json
git commit -m "Register all enforcement hooks: SessionStart, TaskCompleted, Stop gate"
```

---

### Task 6: Update orchestration patterns — task creation at startup

**Files:**
- Modify: `library/orchestration/hub-and-spoke.md`
- Modify: `library/orchestration/solo.md`
- Modify: `library/orchestration/discussion.md`
- Modify: `library/orchestration/sequential-agents.md`
- Mirror all 4 to: `plugins/pas/library/orchestration/`

**Step 1: Add task creation to hub-and-spoke.md startup sequence**

After step 3 (Create workspace) and before step 4 (Load orchestration skills), insert new step 4 and renumber:

```markdown
4. **Create lifecycle tasks** using TaskCreate. These tasks make work visible and are enforced by the `verify-task-completion.sh` hook:

   For each phase in process.md:
   - `[PAS] Phase: {phase-name}` — description: "{agent} processes {input} to produce {output}"

   Shutdown tasks (always created):
   - `[PAS] Self-evaluation` — description: "Write feedback/orchestrator.md using library/self-evaluation/SKILL.md"
   - `[PAS] Route framework signals` — description: "File any framework:pas signals as GitHub issues"
   - `[PAS] Finalize status` — description: "Set status.yaml status to completed with completed_at timestamp"

   Mark each task as completed when its work is done. The `[PAS]` prefix triggers hook enforcement — you cannot mark shutdown tasks complete until their deliverables exist on disk.
```

Also add under the COMPLETION GATE section:

```markdown
**Hook enforcement:** The `verify-completion-gate.sh` Stop hook enforces conditions 1-2 technically. If you try to stop without writing feedback, the hook will block you and tell you what's missing. The hook is a safety net — follow the shutdown sequence above so it never needs to fire.
```

**Step 2: Add same task creation step to solo.md**

After step 2 (Create workspace) and before step 3 (Executes each phase), insert same task creation step, renumber subsequent steps. Also add hook enforcement note under COMPLETION GATE.

**Step 3: Add same task creation step to discussion.md**

After step 3 (Create workspace) and before step 4 (Spawn participants). Also add hook enforcement note.

**Step 4: Add same task creation step to sequential-agents.md**

After step 3 (Create workspace) and before step 4 (Spawn first agent). Also add hook enforcement note.

**Step 5: Mirror all 4 files**

```bash
cp library/orchestration/hub-and-spoke.md plugins/pas/library/orchestration/hub-and-spoke.md
cp library/orchestration/solo.md plugins/pas/library/orchestration/solo.md
cp library/orchestration/discussion.md plugins/pas/library/orchestration/discussion.md
cp library/orchestration/sequential-agents.md plugins/pas/library/orchestration/sequential-agents.md
```

**Step 6: Verify mirrors**

```bash
diff library/orchestration/hub-and-spoke.md plugins/pas/library/orchestration/hub-and-spoke.md
diff library/orchestration/solo.md plugins/pas/library/orchestration/solo.md
diff library/orchestration/discussion.md plugins/pas/library/orchestration/discussion.md
diff library/orchestration/sequential-agents.md plugins/pas/library/orchestration/sequential-agents.md
```

**Step 7: Commit**

```bash
git add library/orchestration/ plugins/pas/library/orchestration/
git commit -m "Add task creation to orchestration patterns for hook enforcement"
```

---

### Task 7: Test all hooks

**Step 1: Test SessionStart hook — context injection + session tracking**

```bash
TESTDIR=$(mktemp -d)
cat > "$TESTDIR/pas-config.yaml" <<'EOF'
feedback: enabled
EOF
echo '{"cwd":"'$TESTDIR'","source":"startup","session_id":"abc12345xyz"}' | bash plugins/pas/hooks/pas-session-start.sh
echo "Exit code: $?"
```

Expected: stdout shows PAS lifecycle context with "Session ID: abc12345", exit code 0.

**Step 2: Test SessionStart writes session tracking to status.yaml**

```bash
mkdir -p "$TESTDIR/workspace/test/session-1/feedback"
cat > "$TESTDIR/workspace/test/session-1/status.yaml" <<'EOF'
process: test
instance: session-1
status: in_progress

phases:
  discovery:
    status: completed
  planning:
    status: pending
EOF
echo '{"cwd":"'$TESTDIR'","source":"startup","session_id":"abc12345xyz"}' | bash plugins/pas/hooks/pas-session-start.sh > /dev/null
grep 'current_session' "$TESTDIR/workspace/test/session-1/status.yaml"
grep 'abc12345' "$TESTDIR/workspace/test/session-1/status.yaml"
```

Expected: `current_session: abc12345` and session entry in sessions list.

**Step 3: Test verify-completion-gate.sh — all phases done, no session feedback → exit 2**

```bash
cat > "$TESTDIR/workspace/test/session-1/status.yaml" <<'EOF'
process: test
instance: session-1
status: in_progress
current_session: abc12345

phases:
  discovery:
    status: completed
  planning:
    status: completed
EOF
echo '{"cwd":"'$TESTDIR'","stop_hook_active":false,"session_id":"abc12345xyz"}' | bash plugins/pas/hooks/verify-completion-gate.sh
echo "Exit code: $?"
```

Expected: stderr shows "COMPLETION GATE FAILED", mentions `orchestrator-abc12345.md`, exit code 2.

**Step 4: Test verify-completion-gate.sh — session-specific feedback exists → exit 0**

```bash
echo "No issues detected." > "$TESTDIR/workspace/test/session-1/feedback/orchestrator-abc12345.md"
echo '{"cwd":"'$TESTDIR'","stop_hook_active":false,"session_id":"abc12345xyz"}' | bash plugins/pas/hooks/verify-completion-gate.sh
echo "Exit code: $?"
```

Expected: exit code 0.

**Step 5: Test verify-completion-gate.sh — feedback from DIFFERENT session doesn't count → exit 2**

```bash
rm "$TESTDIR/workspace/test/session-1/feedback/orchestrator-abc12345.md"
echo "No issues detected." > "$TESTDIR/workspace/test/session-1/feedback/orchestrator-previous.md"
echo '{"cwd":"'$TESTDIR'","stop_hook_active":false,"session_id":"abc12345xyz"}' | bash plugins/pas/hooks/verify-completion-gate.sh
echo "Exit code: $?"
```

Expected: exit code 2 — feedback from a different session doesn't satisfy the gate.

**Step 6: Test verify-completion-gate.sh — stop_hook_active loop prevention → exit 0**

```bash
echo '{"cwd":"'$TESTDIR'","stop_hook_active":true,"session_id":"abc12345xyz"}' | bash plugins/pas/hooks/verify-completion-gate.sh
echo "Exit code: $?"
```

Expected: exit code 0 (loop prevention — don't block twice).

**Step 7: Test verify-completion-gate.sh — pending phases → exit 0**

```bash
cat > "$TESTDIR/workspace/test/session-1/status.yaml" <<'EOF'
process: test
instance: session-1
status: in_progress

phases:
  discovery:
    status: completed
  planning:
    status: pending
EOF
echo '{"cwd":"'$TESTDIR'","stop_hook_active":false,"session_id":"abc12345xyz"}' | bash plugins/pas/hooks/verify-completion-gate.sh
echo "Exit code: $?"
```

Expected: exit code 0 (phases still pending, don't block).

**Step 8: Test verify-task-completion.sh — self-eval task without session feedback → exit 2**

```bash
rm -f "$TESTDIR/workspace/test/session-1/feedback/orchestrator-abc12345.md"
rm -f "$TESTDIR/workspace/test/session-1/feedback/orchestrator-previous.md"
cat > "$TESTDIR/workspace/test/session-1/status.yaml" <<'EOF'
process: test
instance: session-1
status: in_progress
current_session: abc12345

phases:
  discovery:
    status: completed
  planning:
    status: completed
EOF
echo '{"cwd":"'$TESTDIR'","task_subject":"[PAS] Self-evaluation"}' | bash plugins/pas/hooks/verify-task-completion.sh
echo "Exit code: $?"
```

Expected: stderr shows "Cannot complete", exit code 2.

**Step 9: Test verify-task-completion.sh — self-eval task with session feedback → exit 0**

```bash
echo "No issues detected." > "$TESTDIR/workspace/test/session-1/feedback/orchestrator-abc12345.md"
echo '{"cwd":"'$TESTDIR'","task_subject":"[PAS] Self-evaluation"}' | bash plugins/pas/hooks/verify-task-completion.sh
echo "Exit code: $?"
```

Expected: exit code 0.

**Step 9: Test verify-task-completion.sh — finalize task without completed status → exit 2**

```bash
echo '{"cwd":"'$TESTDIR'","task_subject":"[PAS] Finalize status"}' | bash plugins/pas/hooks/verify-task-completion.sh
echo "Exit code: $?"
```

Expected: stderr shows "Cannot complete", exit code 2.

**Step 10: Test verify-task-completion.sh — non-PAS task → exit 0 (no interference)**

```bash
echo '{"cwd":"'$TESTDIR'","task_subject":"Fix the login bug"}' | bash plugins/pas/hooks/verify-task-completion.sh
echo "Exit code: $?"
```

Expected: exit code 0 (not a PAS task, no enforcement).

**Step 12: Test route-feedback.sh — doesn't delete files, uses .routed marker**

```bash
mkdir -p "$TESTDIR/workspace/test/session-1/feedback"
cat > "$TESTDIR/workspace/test/session-1/feedback/orchestrator-abc12345.md" <<'EOF'
[OQI-01]
Target: process:test
Degraded: Test signal
Priority: LOW
EOF
echo '{"cwd":"'$TESTDIR'"}' | bash plugins/pas/hooks/route-feedback.sh
# Feedback file should still exist
test -f "$TESTDIR/workspace/test/session-1/feedback/orchestrator-abc12345.md" && echo "File preserved" || echo "File deleted (BUG)"
# .routed marker should exist
test -f "$TESTDIR/workspace/test/session-1/feedback/orchestrator-abc12345.md.routed" && echo "Routed marker exists" || echo "No marker (BUG)"
# Running again should skip (already routed)
echo '{"cwd":"'$TESTDIR'"}' | bash plugins/pas/hooks/route-feedback.sh
echo "Second run completed without error"
```

Expected: "File preserved", "Routed marker exists", "Second run completed without error".

**Step 13: Test non-PAS project — all hooks exit 0 silently**

```bash
NOPADIR=$(mktemp -d)
echo '{"cwd":"'$NOPADIR'","source":"startup","session_id":"test1234"}' | bash plugins/pas/hooks/pas-session-start.sh
echo "SessionStart exit: $?"
echo '{"cwd":"'$NOPADIR'","stop_hook_active":false,"session_id":"test1234"}' | bash plugins/pas/hooks/verify-completion-gate.sh
echo "Stop exit: $?"
echo '{"cwd":"'$NOPADIR'","task_subject":"[PAS] Self-evaluation"}' | bash plugins/pas/hooks/verify-task-completion.sh
echo "TaskCompleted exit: $?"
rm -rf "$NOPADIR"
```

Expected: All exit code 0, no output (no pas-config.yaml = not a PAS project).

**Step 14: Clean up**

```bash
rm -rf "$TESTDIR"
```

---

### Task 8: Update CHANGELOG.md and orchestration changelog

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `library/orchestration/changelog.md`
- Mirror: `plugins/pas/library/orchestration/changelog.md`

**Step 1: Add "Feedback Enforcement" subsection to CHANGELOG.md 1.3.0**

After the existing "### Self-Evaluation" subsection:

```markdown
### Feedback Enforcement

- **`pas-session-start.sh`** (new SessionStart hook): Injects PAS lifecycle context at session start — workspace creation requirements, task creation requirements, shutdown sequence. Also reports active workspace status for session resumption.
- **`verify-completion-gate.sh`** (new Stop hook): Blocks Claude from stopping (exit 2) when all phases are completed but `feedback/orchestrator.md` is missing. Includes `stop_hook_active` loop prevention.
- **`verify-task-completion.sh`** (new TaskCompleted hook): Blocks `[PAS]`-prefixed tasks from completing until deliverables exist on disk. Enforces self-evaluation, status finalization, and workspace initialization.
- **`check-self-eval.sh`** (enhanced SubagentStop hook): Changed from warning-only (exit 0 + log file) to blocking (exit 2 + stderr feedback). Subagents can no longer stop without writing self-evaluation.
- **hooks.json restructured**: 5 hook registrations across 4 lifecycle events (SessionStart, SubagentStop, TaskCompleted, Stop). Completion gate runs before feedback routing.
- **Task creation in orchestration patterns**: All 4 patterns now create `[PAS]`-prefixed Claude Code tasks at startup for each phase + shutdown steps. Tasks are enforced by hooks.
```

**Step 2: Add entry to orchestration changelog**

```markdown
## 2026-03-07 — Add task creation and hook enforcement references

Triggered by: GitHub issue #7 — orchestrator does not self-enforce process lifecycle
Pattern: Text-level enforcement (HARD REQUIREMENT, COMPLETION GATE) still skipped by orchestrator
Changes:
- All 4 patterns: Add task creation step at startup — [PAS]-prefixed tasks for phases + shutdown
- All 4 patterns: Add hook enforcement note under COMPLETION GATE
```

**Step 3: Mirror orchestration changelog**

```bash
cp library/orchestration/changelog.md plugins/pas/library/orchestration/changelog.md
```

**Step 4: Commit**

```bash
git add CHANGELOG.md library/orchestration/changelog.md plugins/pas/library/orchestration/changelog.md
git commit -m "Add feedback enforcement changelog entries"
```

---

## Dependency Graph

```
Task 1 (SessionStart hook)     ─┐
Task 2 (Stop hook)              ├→ Task 5 (hooks.json) → Task 7 (test all) → Task 8 (changelog)
Task 3 (TaskCompleted hook)     ┤
Task 4 (enhance self-eval)     ─┘
                                          Task 6 (orchestration patterns) → Task 8
```

Tasks 1-4 are independent (different files). Task 5 depends on all four. Task 6 is independent of 1-5 but both feed into Task 8. Task 7 depends on 5.

## Files Modified/Created (Summary)

| File | Action |
|------|--------|
| `plugins/pas/hooks/pas-session-start.sh` | **Create** — SessionStart hook |
| `plugins/pas/hooks/verify-completion-gate.sh` | **Create** — Stop hook |
| `plugins/pas/hooks/verify-task-completion.sh` | **Create** — TaskCompleted hook |
| `plugins/pas/hooks/check-self-eval.sh` | **Modify** — exit 0 → exit 2 |
| `plugins/pas/hooks/hooks.json` | **Modify** — 5 hook registrations |
| `library/orchestration/hub-and-spoke.md` | **Modify** — task creation + hook note |
| `library/orchestration/solo.md` | **Modify** — task creation + hook note |
| `library/orchestration/discussion.md` | **Modify** — task creation + hook note |
| `library/orchestration/sequential-agents.md` | **Modify** — task creation + hook note |
| `plugins/pas/library/orchestration/*.md` | **Mirror** — 4 files |
| `CHANGELOG.md` | **Modify** — enforcement entry |
| `library/orchestration/changelog.md` | **Modify** — new entry |
| `plugins/pas/library/orchestration/changelog.md` | **Mirror** |

Total: 3 new files, 12 modified/mirrored files.

---

### Task 9: Fix `route-feedback.sh` — stop deleting feedback files

**Files:**
- Modify: `plugins/pas/hooks/route-feedback.sh`

**Context:** The `route-feedback.sh` Stop hook currently deletes feedback `.md` files after routing signals to artifact backlogs (line 164: `rm "$feedback_file"`). Since the Stop hook fires on every response, it can consume feedback files mid-conversation. This breaks the completion gate check — `verify-completion-gate.sh` looks for `feedback/orchestrator-{session}.md` on disk, but `route-feedback.sh` already deleted it.

**Step 1: Remove the `rm` call**

Replace:
```bash
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"
      rm "$feedback_file"
```

With:
```bash
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"
      # Do NOT delete feedback files — they must persist for the completion gate check.
      # The verify-completion-gate.sh Stop hook checks for feedback/orchestrator-{session}.md on disk.
```

**Note:** This change was already applied during the current session as an emergency fix. This task ensures it's included in the plan, tested, and committed properly.

**Step 2: Prevent duplicate routing**

Since files aren't deleted, `route-feedback.sh` would re-route the same signals on every Stop event. Add a marker to track which files have been routed:

Replace the feedback file processing loop:
```bash
  if [ -n "$FEEDBACK_FILES" ]; then
    echo "$FEEDBACK_FILES" | while read -r feedback_file; do
      [ -f "$feedback_file" ] || continue
      source_basename=$(basename "$feedback_file" .md)
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"
      # Do NOT delete feedback files — they must persist for the completion gate check.
      # The verify-completion-gate.sh Stop hook checks for feedback/orchestrator-{session}.md on disk.
    done
  fi
```

With:
```bash
  if [ -n "$FEEDBACK_FILES" ]; then
    echo "$FEEDBACK_FILES" | while read -r feedback_file; do
      [ -f "$feedback_file" ] || continue

      # Skip already-routed files (marked by companion .routed file)
      if [ -f "${feedback_file}.routed" ]; then
        continue
      fi

      source_basename=$(basename "$feedback_file" .md)
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"

      # Mark as routed instead of deleting
      touch "${feedback_file}.routed"
    done
  fi
```

**Step 3: Commit**

```bash
git add plugins/pas/hooks/route-feedback.sh
git commit -m "Fix route-feedback.sh: stop deleting feedback files, use .routed marker"
```

---

### Task 10: Update status.yaml format in orchestration patterns

**Files:**
- Modify: `library/orchestration/hub-and-spoke.md` (Status Tracking section)
- Mirror to: `plugins/pas/library/orchestration/hub-and-spoke.md`

**Step 1: Add session tracking fields to the status.yaml format example**

In the Status Tracking section, update the format example to include session tracking:

```yaml
process: {name}
instance: {slug}
started_at: {ISO timestamp}
completed_at: ~
status: in_progress
current_session: {first 8 chars of session_id}

phases:
  {phase-name}:
    status: completed
    agent: {agent-name}
    started_at: {ISO timestamp}
    completed_at: {ISO timestamp}
    duration_seconds: {number}
    attempts: {number}
    output_files:
      - {path relative to workspace}
    quality:
      score: {1-10}
      notes: "{free text assessment}"

sessions:
  - id: {short session_id}
    started_at: {ISO timestamp}
    completed_at: {ISO timestamp or ~}
    feedback_collected: {true or false}
```

Add explanation:

```markdown
**Session tracking:** The `pas-session-start.sh` hook automatically writes `current_session` and appends to the `sessions` list when a session begins. Feedback files are named `feedback/orchestrator-{session_id}.md` so the Stop hook can verify that THIS session (not a previous one) produced feedback.
```

**Step 2: Mirror**

```bash
cp library/orchestration/hub-and-spoke.md plugins/pas/library/orchestration/hub-and-spoke.md
```

**Step 3: Commit**

```bash
git add library/orchestration/hub-and-spoke.md plugins/pas/library/orchestration/hub-and-spoke.md
git commit -m "Add session tracking fields to status.yaml format documentation"
```

---

### Task 11: Update self-evaluation skill — session-specific filenames

**Files:**
- Modify: `library/self-evaluation/SKILL.md`
- Mirror to: `plugins/pas/library/self-evaluation/SKILL.md`

**Step 1: Update the Process section**

Change step 3 from:
```markdown
3. Write signals to `workspace/{process}/{slug}/feedback/{your-agent-name}.md`
```

To:
```markdown
3. Write signals to `workspace/{process}/{slug}/feedback/{your-agent-name}-{session_id}.md`

   The session ID is provided by the SessionStart hook and recorded in `status.yaml` under `current_session`. If no session ID is available, use your agent name without a suffix.
```

**Step 2: Mirror**

```bash
cp library/self-evaluation/SKILL.md plugins/pas/library/self-evaluation/SKILL.md
```

**Step 3: Commit**

```bash
git add library/self-evaluation/SKILL.md plugins/pas/library/self-evaluation/SKILL.md
git commit -m "Update self-evaluation: session-specific feedback filenames"
```

---

## Updated Dependency Graph

```
Task 1 (SessionStart hook)     ─┐
Task 2 (Stop hook)              ├→ Task 5 (hooks.json) → Task 7 (test all) → Task 8 (changelog)
Task 3 (TaskCompleted hook)     ┤
Task 4 (enhance self-eval)     ─┘
Task 9 (route-feedback fix)    ─→ Task 7
Task 6 (orchestration patterns: tasks) ─┐
Task 10 (orchestration patterns: session tracking) ├→ Task 8
Task 11 (self-eval skill: session filenames) ─┘
```

Tasks 1-4, 9 are independent script changes. Task 5 depends on 1-4. Tasks 6, 10, 11 are independent doc changes. Task 7 depends on 5 + 9. Task 8 depends on everything.

## Updated Files Modified/Created (Summary)

| File | Action |
|------|--------|
| `plugins/pas/hooks/pas-session-start.sh` | **Create** — SessionStart hook with session tracking |
| `plugins/pas/hooks/verify-completion-gate.sh` | **Create** — Stop hook, session-aware |
| `plugins/pas/hooks/verify-task-completion.sh` | **Create** — TaskCompleted hook, session-aware |
| `plugins/pas/hooks/check-self-eval.sh` | **Modify** — exit 0 → exit 2 |
| `plugins/pas/hooks/route-feedback.sh` | **Modify** — stop deleting files, use .routed marker |
| `plugins/pas/hooks/hooks.json` | **Modify** — 5 hook registrations |
| `library/orchestration/hub-and-spoke.md` | **Modify** — task creation + hook note + session tracking format |
| `library/orchestration/solo.md` | **Modify** — task creation + hook note |
| `library/orchestration/discussion.md` | **Modify** — task creation + hook note |
| `library/orchestration/sequential-agents.md` | **Modify** — task creation + hook note |
| `library/self-evaluation/SKILL.md` | **Modify** — session-specific filenames |
| `plugins/pas/library/orchestration/*.md` | **Mirror** — 4 files |
| `plugins/pas/library/self-evaluation/SKILL.md` | **Mirror** |
| `CHANGELOG.md` | **Modify** — enforcement entry |
| `library/orchestration/changelog.md` | **Modify** — new entry |
| `plugins/pas/library/orchestration/changelog.md` | **Mirror** |

Total: 3 new files, 15 modified/mirrored files.
