#!/usr/bin/env bash
set -euo pipefail

# TaskCompleted hook: blocks PAS shutdown tasks from completing
# until their deliverables exist on disk.
#
# Matched tasks (by subject pattern):
#   "[PAS] Self-evaluation" → feedback/orchestrator.md must exist
#   "[PAS] Finalize status" → status.yaml must have status: completed
#   "[PAS] Route framework signals" → allowed (can't verify GitHub issues from bash)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/guards.sh"
resolve_claude_plugin_root || exit 1

guard_parse_input || exit 0

TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')

guard_pas_project || exit 0

# Only act on PAS-prefixed tasks
if ! echo "$TASK_SUBJECT" | grep -q '^\[PAS\]'; then
  exit 0
fi

guard_active_workspace "$SCRIPT_DIR" || exit 0

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
Use \${CLAUDE_PLUGIN_ROOT}/library/self-evaluation/SKILL.md for the format.
EOF
      pas_version_footer >&2
      exit 2
    fi
    ;;

  *"Finalize status"*)
    TOP_STATUS=$(grep '^status:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}' || true)
    COMPLETED_AT=$(grep '^completed_at:' "$ACTIVE_STATUS" | head -1 | awk '{print $2}' || true)

    if [ "$TOP_STATUS" != "completed" ] || [ "$COMPLETED_AT" = "~" ] || [ -z "$COMPLETED_AT" ]; then
      cat >&2 <<EOF
Cannot complete "Finalize status" task: status.yaml is not finalized.

Update ${ACTIVE_STATUS}:
- Set top-level status to "completed"
- Set completed_at to current ISO timestamp
EOF
      pas_version_footer >&2
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
      pas_version_footer >&2
      exit 2
    fi
    ;;

  *"Phase: "*)
    # Phase deliverable enforcement (#49). status.yaml schema is key-based:
    #   phases:
    #     <phase-name>:
    #       output_files:
    #         - path/relative/to/workspace
    # Find the phase block, then extract output_files entries until the next
    # field at the same indent level. Phase with no output_files block → no-op.
    PHASE_NAME=$(echo "$TASK_SUBJECT" | sed 's/^\[PAS\] Phase: //')

    OUTPUT_FILES=$(awk -v phase="$PHASE_NAME" '
      # Detect the start of the named phase: "  <phase>:" at exactly 2-space indent
      $0 ~ "^  " phase ":[[:space:]]*$" { in_phase=1; next }
      # Inside phase: detect a sibling phase or top-level field — exit
      in_phase && /^[a-zA-Z_]/ { in_phase=0; in_outputs=0 }
      in_phase && /^  [a-zA-Z_]/ { in_phase=0; in_outputs=0 }
      # Inside phase: detect output_files: header
      in_phase && /^    output_files:/ { in_outputs=1; next }
      # Once inside output_files, capture "      - path" entries
      in_outputs && /^      - / { sub(/^      - /, ""); print; next }
      # Anything else inside phase ends the output_files capture
      in_outputs && !/^      - / { in_outputs=0 }
    ' "$ACTIVE_STATUS")

    if [ -n "$OUTPUT_FILES" ]; then
      MISSING=""
      while IFS= read -r path; do
        [ -z "$path" ] && continue
        # Strip surrounding quotes if any
        path=$(echo "$path" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        if [ ! -e "$ACTIVE_WORKSPACE/$path" ]; then
          MISSING="${MISSING:+$MISSING, }$path"
        fi
      done <<< "$OUTPUT_FILES"

      if [ -n "$MISSING" ]; then
        cat >&2 <<EOF
Cannot complete "${TASK_SUBJECT}": phase deliverables missing.
  Workspace: ${ACTIVE_WORKSPACE}
  Missing output_files: ${MISSING}

Each path under the phase's output_files: list in status.yaml must exist
on disk before this task can be marked complete. See:
  library/orchestration/lifecycle.md (phase output_files contract)
EOF
        pas_version_footer >&2
        exit 2
      fi
    fi
    ;;
esac

# All checks passed (or task type not enforced)
exit 0
