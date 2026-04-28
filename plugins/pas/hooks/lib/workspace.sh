#!/usr/bin/env bash
# Shared workspace detection utility for PAS hooks.

# Resolve the active workspace's status.yaml.
# Args:
#   $1 — workspace dir (e.g. $PAS_PROJECT_ROOT/.pas/workspace)
#   $2 — session_id (optional, short form). When non-empty, prefer the
#        workspace whose current_session: matches this id. This protects
#        against the multi-instance bug (#52) where mtime would pick a
#        sibling workspace that an unrelated session was working on.
# Echoes the path to status.yaml; returns non-zero if nothing matches.
find_active_workspace_status() {
  local workspace_dir="$1"
  local session_id="${2:-}"
  if [ ! -d "$workspace_dir" ]; then
    return 1
  fi

  local result=""

  # Pass 0: when a session id is provided, find the workspace whose binding
  # field matches. Matches either `current_session:` (PAS canonical) or
  # `session_id:` (the natural field name many process docs reach for —
  # e.g. v2-agency-delivery). Wins over mtime/in_progress passes.
  # Cross-field matching (#155) closes the multi-worktree mtime-misroute
  # bug for processes that don't use the canonical field name.
  if [ -n "$session_id" ]; then
    result=$(find "$workspace_dir" -name "status.yaml" -print 2>/dev/null | while read -r f; do
      if grep -qE "^(current_session|session_id):[[:space:]]*${session_id}\b" "$f" 2>/dev/null; then
        echo "$f"
        break
      fi
    done | head -1)
    if [ -n "$result" ]; then
      echo "$result"
      return 0
    fi
  fi

  # Pass 1: prefer status.yaml files with status: in_progress (most recent by mtime)
  result=$(find "$workspace_dir" -name "status.yaml" -print 2>/dev/null | while read -r f; do
    if grep -q '^status:[[:space:]]*in_progress' "$f" 2>/dev/null; then
      echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
    fi
  done | sort -rn | head -1 | awk '{print $2}')

  # Pass 2: fallback to any status.yaml (most recent by mtime)
  if [ -z "$result" ]; then
    result=$(find "$workspace_dir" -name "status.yaml" -print 2>/dev/null | while read -r f; do
      echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
    done | sort -rn | head -1 | awk '{print $2}')
  fi

  if [ -z "$result" ]; then
    return 1
  fi

  echo "$result"
}
