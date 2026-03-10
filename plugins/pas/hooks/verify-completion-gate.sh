#!/usr/bin/env bash
set -euo pipefail

# Stop hook: blocks Claude from stopping when work is done but feedback is missing.
# Only blocks when ALL phases are completed and no feedback file exists for the
# current session. Uses session_id from status.yaml (written by SessionStart hook)
# to check for session-specific feedback: feedback/orchestrator-{session_id}.md.
# Uses stop_hook_active to prevent infinite blocking loops.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/guards.sh"

guard_parse_input || exit 0

STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Prevent infinite loops: if we already blocked once, let Claude stop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

guard_feedback_enabled || exit 0
guard_active_workspace "$SCRIPT_DIR" || exit 0

# Defense-in-depth: if workspace is already completed, don't block (Issue #23)
TOP_STATUS=$(grep '^status:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}')
if [ "$TOP_STATUS" = "completed" ]; then
  exit 0
fi

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

# All phases completed. Check for session-specific orchestrator feedback.
ORCHESTRATOR_OK=false
if [ -n "$SESSION_SHORT" ]; then
  SESSION_FEEDBACK="$FEEDBACK_DIR/orchestrator-${SESSION_SHORT}.md"
  if [ -f "$SESSION_FEEDBACK" ]; then
    ORCHESTRATOR_OK=true
  fi
  EXPECTED_FILE="orchestrator-${SESSION_SHORT}.md"
else
  if ls "$FEEDBACK_DIR"/orchestrator*.md 1>/dev/null 2>&1; then
    ORCHESTRATOR_OK=true
  fi
  EXPECTED_FILE="orchestrator-{session_id}.md"
fi

# Check agent feedback (Issue #19): extract unique agent names from phases, verify each has feedback
MISSING_AGENTS=""
AGENT_NAMES=$(grep '^\s*agent:' "$ACTIVE_STATUS" 2>/dev/null | awk '{print $2}' | sort -u || true)
if [ -n "$AGENT_NAMES" ]; then
  while read -r agent_name; do
    [ -z "$agent_name" ] && continue
    [ "$agent_name" = "orchestrator" ] && continue
    # Look for any feedback file matching this agent name
    if ! find "$FEEDBACK_DIR" -maxdepth 1 \( -name "${agent_name}.md" -o -name "${agent_name}-*.md" \) 2>/dev/null | grep -q .; then
      MISSING_AGENTS="${MISSING_AGENTS:+$MISSING_AGENTS, }$agent_name"
    fi
  done <<< "$AGENT_NAMES"
fi

# If orchestrator feedback exists and no agents are missing feedback, allow stop
if [ "$ORCHESTRATOR_OK" = true ] && [ -z "$MISSING_AGENTS" ]; then
  exit 0
fi

# BLOCK: build failure message
{
  echo "COMPLETION GATE FAILED"
  echo ""
  if [ "$ORCHESTRATOR_OK" != true ]; then
    echo "Orchestrator self-evaluation missing: ${FEEDBACK_DIR}/${EXPECTED_FILE}"
  fi
  if [ -n "$MISSING_AGENTS" ]; then
    echo "Agent self-evaluation missing for: ${MISSING_AGENTS}"
    echo "Each agent must write feedback to ${FEEDBACK_DIR}/{agent-name}.md before shutdown."
  fi
  echo ""
  echo "Before stopping, you MUST:"
  echo "1. Write self-evaluation to ${FEEDBACK_DIR}/${EXPECTED_FILE}"
  echo "   - Use .pas/library/self-evaluation/SKILL.md for the format"
  echo "   - If nothing went wrong, write \"No issues detected.\""
  if [ -n "$MISSING_AGENTS" ]; then
    echo "2. Ensure all agents have written their feedback files"
    echo "3. Route any framework:pas signals as GitHub issues"
    echo "4. Update status.yaml: set status to completed and completed_at timestamp"
  else
    echo "2. Route any framework:pas signals as GitHub issues"
    echo "3. Update status.yaml: set status to completed and completed_at timestamp"
  fi
  echo ""
  echo "You cannot stop until these steps are done."
} >&2
exit 2
