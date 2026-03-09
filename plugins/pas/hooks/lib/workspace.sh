#!/usr/bin/env bash
# Shared workspace detection utility for PAS hooks.

find_active_workspace_status() {
  local workspace_dir="$1"
  if [ ! -d "$workspace_dir" ]; then
    return 1
  fi

  local result=""

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
