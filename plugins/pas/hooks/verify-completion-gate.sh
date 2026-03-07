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
PENDING_COUNT=$(grep -c '^\s*status: pending' "$ACTIVE_STATUS" 2>/dev/null) || PENDING_COUNT=0

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
