#!/usr/bin/env bash
# Shared guard functions for PAS hooks.
# Eliminates duplicated jq/config/feedback checks across hook scripts.

# Parse JSON input from stdin. Sets CWD and exposes raw INPUT.
# Returns 1 if jq is missing or JSON is invalid.
guard_parse_input() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "PAS hook: jq not found, skipping" >&2
    return 1
  fi

  INPUT=$(cat)

  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  if [ -z "$CWD" ]; then
    return 1
  fi
}

# Check that this is a PAS project (pas-config.yaml exists).
# Returns 1 if not a PAS project.
guard_pas_project() {
  PAS_CONFIG="$CWD/pas-config.yaml"
  if [ ! -f "$PAS_CONFIG" ]; then
    return 1
  fi
}

# Check that feedback is enabled in pas-config.yaml.
# Returns 1 if feedback is not enabled.
guard_feedback_enabled() {
  guard_pas_project || return 1

  FEEDBACK_STATUS=$(grep -o 'feedback:[[:space:]]*\w*' "$PAS_CONFIG" | head -1 | awk '{print $NF}')
  if [ "$FEEDBACK_STATUS" != "enabled" ]; then
    return 1
  fi
}

# Find active workspace using the shared workspace resolution function.
# Sets ACTIVE_STATUS, ACTIVE_WORKSPACE, FEEDBACK_DIR.
# Returns 1 if no workspace found.
guard_active_workspace() {
  local script_dir="$1"
  source "$script_dir/lib/workspace.sh"

  WORKSPACE_DIR="$CWD/workspace"
  if [ ! -d "$WORKSPACE_DIR" ]; then
    return 1
  fi

  ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR") || return 1
  ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
  FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"
}
