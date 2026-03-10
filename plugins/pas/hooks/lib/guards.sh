#!/usr/bin/env bash
# Shared guard functions for PAS hooks.
# Eliminates duplicated jq/config/feedback checks across hook scripts.

# All PAS project-level artifacts live under this directory.
PAS_ROOT=".pas"

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

# Migrate old-style root-level PAS artifacts into .pas/ directory.
# Idempotent: skips each item if target already exists.
migrate_to_pas_dir() {
  local pas_dir="$CWD/$PAS_ROOT"
  mkdir -p "$pas_dir"

  # Move config (rename)
  if [ -f "$CWD/pas-config.yaml" ] && [ ! -f "$pas_dir/config.yaml" ]; then
    mv "$CWD/pas-config.yaml" "$pas_dir/config.yaml"
  fi

  # Move directories
  for dir in workspace library processes feedback; do
    if [ -d "$CWD/$dir" ] && [ ! -d "$pas_dir/$dir" ]; then
      mv "$CWD/$dir" "$pas_dir/$dir"
    fi
  done
}

# Check that this is a PAS project (.pas/config.yaml exists).
# Auto-migrates old-style layout if detected.
# Returns 1 if not a PAS project.
guard_pas_project() {
  PAS_CONFIG="$CWD/$PAS_ROOT/config.yaml"
  if [ -f "$PAS_CONFIG" ]; then
    return 0
  fi

  # Backward compatibility: migrate old-style root layout
  if [ -f "$CWD/pas-config.yaml" ]; then
    migrate_to_pas_dir
    PAS_CONFIG="$CWD/$PAS_ROOT/config.yaml"
    if [ -f "$PAS_CONFIG" ]; then
      return 0
    fi
  fi

  return 1
}

# Check that feedback is enabled in config.yaml.
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

  WORKSPACE_DIR="$CWD/$PAS_ROOT/workspace"
  if [ ! -d "$WORKSPACE_DIR" ]; then
    return 1
  fi

  ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR") || return 1
  ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
  FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"
}
