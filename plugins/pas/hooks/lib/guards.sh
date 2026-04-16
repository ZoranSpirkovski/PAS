#!/usr/bin/env bash
# Shared guard functions for PAS hooks.
# Eliminates duplicated jq/config/feedback checks across hook scripts.

# All PAS project-level artifacts live under this directory.
PAS_ROOT=".pas"

# Defensive default for CLAUDE_PLUGIN_ROOT — the harness substitutes this in
# hooks.json command paths but does not always export it as an env var.
# Falls back to two-levels-up from this lib file (i.e. plugins/pas/).
: "${CLAUDE_PLUGIN_ROOT:=$(cd "${BASH_SOURCE[0]%/*}/../.." 2>/dev/null && pwd || echo "")}"
export CLAUDE_PLUGIN_ROOT

# Resolve the PAS project root by walking up from a candidate cwd until
# .pas/config.yaml is found, then falling back to git's worktree root.
# Echoes the resolved root on stdout; returns non-zero if nothing matches.
resolve_pas_project_root() {
  local candidate="${1:-${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}}"

  # Walk up from candidate
  local dir="$candidate"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/$PAS_ROOT/config.yaml" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  # Worktree fallback: when running inside a worktree, .pas/ may live at the
  # main worktree root. --show-toplevel returns the worktree's working tree,
  # not the shared .git dir (which would be wrong for hosting .pas/).
  if command -v git >/dev/null 2>&1; then
    local worktree_root
    worktree_root=$(cd "$candidate" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || return 1
    if [ -n "$worktree_root" ] && [ -f "$worktree_root/$PAS_ROOT/config.yaml" ]; then
      echo "$worktree_root"
      return 0
    fi
  fi

  return 1
}

# Crash-resistant `grep | head | awk` field extractor for status.yaml.
# Returns empty string on missing field instead of failing under set -e/pipefail.
safe_grep_field() {
  local file="$1"
  local key="$2"
  grep "^${key}:" "$file" 2>/dev/null | head -1 | awk '{print $2}' || true
}

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
# Auto-migrates old-style layout if detected. Also handles worktrees and
# subdirectory invocations by walking up and falling back to git-worktree-root.
# Sets PAS_PROJECT_ROOT to the resolved project root (may differ from CWD).
# Returns 1 if not a PAS project.
guard_pas_project() {
  # Fast path: $CWD itself is a PAS root
  PAS_CONFIG="$CWD/$PAS_ROOT/config.yaml"
  if [ -f "$PAS_CONFIG" ]; then
    PAS_PROJECT_ROOT="$CWD"
    export PAS_PROJECT_ROOT
    return 0
  fi

  # Backward compatibility: migrate old-style root layout
  if [ -f "$CWD/pas-config.yaml" ]; then
    migrate_to_pas_dir
    PAS_CONFIG="$CWD/$PAS_ROOT/config.yaml"
    if [ -f "$PAS_CONFIG" ]; then
      PAS_PROJECT_ROOT="$CWD"
      export PAS_PROJECT_ROOT
      return 0
    fi
  fi

  # Worktree / subdirectory fallback: walk up and try git-worktree resolver.
  local resolved
  resolved=$(resolve_pas_project_root "$CWD") || return 1
  if [ -n "$resolved" ] && [ -f "$resolved/$PAS_ROOT/config.yaml" ]; then
    PAS_PROJECT_ROOT="$resolved"
    PAS_CONFIG="$resolved/$PAS_ROOT/config.yaml"
    export PAS_PROJECT_ROOT
    return 0
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
# Uses PAS_PROJECT_ROOT (set by guard_pas_project) so worktree-cwd sessions
# resolve to the main checkout's .pas/workspace/.
# Returns 1 if no workspace found.
guard_active_workspace() {
  local script_dir="$1"
  source "$script_dir/lib/workspace.sh"

  # Ensure PAS_PROJECT_ROOT is resolved (may be unset if caller skipped guard_pas_project).
  if [ -z "${PAS_PROJECT_ROOT:-}" ]; then
    guard_pas_project || return 1
  fi

  WORKSPACE_DIR="$PAS_PROJECT_ROOT/$PAS_ROOT/workspace"
  if [ ! -d "$WORKSPACE_DIR" ]; then
    return 1
  fi

  ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR") || return 1
  ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
  FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"
}
