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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/workspace.sh"

# Check for active workspace
ACTIVE_STATUS=""
WORKSPACE_DIR="$CWD/workspace"
if [ -d "$WORKSPACE_DIR" ]; then
  ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR" 2>/dev/null) || true
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
   - Task: "[PAS] Finalize status" — set status.yaml to completed with completed_at timestamp

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
