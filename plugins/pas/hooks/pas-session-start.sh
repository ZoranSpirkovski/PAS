#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: injects PAS lifecycle context and records session tracking.
# stdout from this hook becomes context Claude sees in its conversation.
# Also writes current_session to status.yaml so the Stop hook can verify
# feedback was written by THIS session, not a previous one.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/guards.sh"

guard_parse_input || exit 0
guard_pas_project || exit 0

# Subagent guard (#38, #68): when SessionStart fires inside a subagent
# context, skip the lifecycle injection. The heredoc's "MUST follow this
# lifecycle / hooks will block you" text was making generic Explore /
# general-purpose subagents short-circuit into the PAS shutdown ritual
# instead of doing their actual task. CC v2.1.69+ exposes agent_id in
# subagent SessionStart events; absence means orchestrator session.
HOOK_AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
if [ -n "$HOOK_AGENT_ID" ] && [ "$HOOK_AGENT_ID" != "null" ]; then
  exit 0  # Subagent context — do not inject PAS lifecycle text
fi

FEEDBACK_STATUS=$(grep -o 'feedback:[[:space:]]*\w*' "$PAS_CONFIG" | head -1 | awk '{print $NF}')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Derive short session ID (first 8 chars)
SESSION_SHORT=""
if [ -n "$SESSION_ID" ]; then
  SESSION_SHORT=$(echo "$SESSION_ID" | cut -c1-8)
fi

# Check for active workspace
ACTIVE_STATUS=""
if guard_active_workspace "$SCRIPT_DIR"; then
  true
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
1. Create workspace: mkdir -p .pas/workspace/{process}/{slug}/{discovery,planning,execution/changes,validation,feedback}
2. Write status.yaml with all phases as pending
3. Create Claude Code tasks for each phase AND for shutdown steps:
   - One task per phase from process.md
   - Task: "[PAS] Self-evaluation" — write feedback/orchestrator-{session_id}.md
   - Task: "[PAS] Route framework signals" — file framework:pas signals as GitHub issues
   - Task: "[PAS] Finalize status" — set status.yaml to completed with completed_at timestamp

SHUTDOWN (after all phases complete):
1. Write self-evaluation to .pas/workspace/{process}/{slug}/feedback/orchestrator-${SESSION_SHORT:-SESSION_ID}.md
2. Route any framework:pas signals as GitHub issues
3. Update status.yaml: set status to completed with completed_at timestamp
4. Mark all shutdown tasks as completed

ENFORCEMENT: Hooks will block you from stopping or completing tasks if deliverables are missing.
CREATION ROUTING: When the user wants to create a process, agent, skill, or workflow, offer /pas:pas as the tool to do it. PAS provides structured creation with brainstorming, proper scaffolding, and feedback integration.
Feedback files MUST include your session ID (${SESSION_SHORT:-unknown}) in the filename.
EOF

# If there's an active workspace, show its status
if [ -n "$ACTIVE_STATUS" ]; then
  ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")

  # Use safe_grep_field (from lib/guards.sh) so missing fields don't crash
  # the script under set -euo pipefail.
  TOP_STATUS=$(safe_grep_field "$ACTIVE_STATUS" status)
  PROCESS_NAME=$(safe_grep_field "$ACTIVE_STATUS" process)
  INSTANCE=$(safe_grep_field "$ACTIVE_STATUS" instance)

  # Accumulate missing-field warnings; default to useful values so the
  # display is never just "Active workspace: / (status: )".
  MISSING_FIELDS=""
  if [ -z "$TOP_STATUS" ]; then
    MISSING_FIELDS="status"
    TOP_STATUS="unknown"
  fi
  if [ -z "$PROCESS_NAME" ]; then
    MISSING_FIELDS="${MISSING_FIELDS:+$MISSING_FIELDS, }process"
  fi
  if [ -z "$INSTANCE" ]; then
    INSTANCE=$(basename "$ACTIVE_WORKSPACE")
    MISSING_FIELDS="${MISSING_FIELDS:+$MISSING_FIELDS, }instance"
  fi

  echo ""
  if [ -n "$MISSING_FIELDS" ]; then
    echo "PAS workspace detected at: ${ACTIVE_WORKSPACE}"
    echo "  Status file: ${ACTIVE_STATUS}"
    echo "  Missing required fields: ${MISSING_FIELDS}"
    echo "  See: library/orchestration/lifecycle.md (status.yaml schema)"
    echo "  Continuing with derived values — fix status.yaml to silence this warning."
    echo ""
  fi
  echo "Active workspace: ${PROCESS_NAME}/${INSTANCE} (status: ${TOP_STATUS})"
  echo "Path: ${ACTIVE_WORKSPACE}"

  if [ "$TOP_STATUS" = "in_progress" ]; then
    echo "This session may be a continuation. Read status.yaml to determine where to resume."
  fi
fi

exit 0
