#!/usr/bin/env bash
# Shared workspace detection utility for PAS hooks.

find_active_workspace_status() {
  local workspace_dir="$1"
  if [ ! -d "$workspace_dir" ]; then
    return 1
  fi

  local result
  result=$(find "$workspace_dir" -name "status.yaml" -print 2>/dev/null | while read -r f; do
    echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
  done | sort -rn | head -1 | awk '{print $2}')

  if [ -z "$result" ]; then
    return 1
  fi

  echo "$result"
}
