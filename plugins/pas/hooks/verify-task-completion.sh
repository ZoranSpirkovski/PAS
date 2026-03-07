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
