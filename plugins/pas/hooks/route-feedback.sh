#!/usr/bin/env bash
set -euo pipefail

# Stop hook: routes feedback signals to artifact backlogs.
# Enhanced: also extracts signals from last_assistant_message,
# mkdir -p before all log writes, sort-by-mtime for workspace detection.

INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd')
LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

if [ -z "$CWD" ]; then
  exit 0
fi

# --- Functions ---

find_active_workspace() {
  local workspace_dir="$CWD/workspace"
  if [ ! -d "$workspace_dir" ]; then
    return 1
  fi

  local active_status
  active_status=$(find "$workspace_dir" -name "status.yaml" -print 2>/dev/null | while read -r f; do
    echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
  done | sort -rn | head -1 | awk '{print $2}')

  if [ -z "$active_status" ]; then
    return 1
  fi

  dirname "$active_status"
}

resolve_target_path() {
  local target="$1"
  local type value

  type=$(echo "$target" | cut -d: -f1)
  value=$(echo "$target" | cut -d: -f2-)

  case "$type" in
    process)
      local path="$CWD/processes/$value/feedback/backlog"
      if [ ! -d "$path" ]; then
        # Fallback: search in plugins/ for plugin-owned processes
        path=$(find "$CWD/plugins" -path "*/processes/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      fi
      echo "${path:-}"
      ;;
    agent)
      local found
      found=$(find "$CWD/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      if [ -z "$found" ]; then
        # Fallback: search in plugins/ for plugin-owned agents
        found=$(find "$CWD/plugins" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      fi
      echo "${found:-}"
      ;;
    skill)
      local found
      found=$(find "$CWD/processes" -path "*/skills/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      if [ -z "$found" ]; then
        found=$(find "$CWD/library" -path "*/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      fi
      if [ -z "$found" ]; then
        # Fallback: search in plugins/ for plugin-owned skills
        found=$(find "$CWD/plugins" -path "*/skills/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      fi
      echo "${found:-}"
      ;;
    framework)
      # Framework feedback is routed to GitHub issues by the orchestrator at shutdown.
      # Return empty — the hook does not handle GitHub issue creation.
      echo ""
      ;;
    *)
      echo ""
      ;;
  esac
}

route_signal() {
  local signal_block="$1"
  local signal_id="$2"
  local source_basename="$3"
  local target_path="$4"
  local today

  today=$(date +%Y-%m-%d)
  local dest_file="$target_path/${today}-${source_basename}-${signal_id}.md"

  mkdir -p "$target_path"
  echo "$signal_block" > "$dest_file"
}

parse_and_route_signals() {
  local text="$1"
  local source_name="$2"

  local current_signal=""
  local current_id=""
  local current_target=""

  while IFS= read -r line || [ -n "$line" ]; do
    if echo "$line" | grep -qE '^\[(PPU|OQI|GATE|STA)-[0-9]+\]'; then
      # Route previous signal
      if [ -n "$current_signal" ] && [ -n "$current_target" ]; then
        local target_path
        target_path=$(resolve_target_path "$current_target")
        if [ -n "$target_path" ]; then
          route_signal "$current_signal" "$current_id" "$source_name" "$target_path"
        else
          mkdir -p "$CWD/feedback"
          echo "[$(date -Iseconds)] WARNING: Unknown target '$current_target'" >> "$CWD/feedback/warnings.log" 2>/dev/null || true
        fi
      fi

      current_id=$(echo "$line" | grep -oE '(PPU|OQI|GATE|STA)-[0-9]+')
      current_signal="$line"
      current_target=""
    else
      if [ -n "$current_id" ]; then
        current_signal="$current_signal
$line"
      fi
      if echo "$line" | grep -qE '^Target:'; then
        current_target=$(echo "$line" | sed 's/^Target:[[:space:]]*//')
      fi
    fi
  done <<< "$text"

  # Route last signal
  if [ -n "$current_signal" ] && [ -n "$current_target" ]; then
    local target_path
    target_path=$(resolve_target_path "$current_target")
    if [ -n "$target_path" ]; then
      route_signal "$current_signal" "$current_id" "$source_name" "$target_path"
    else
      mkdir -p "$CWD/feedback"
      echo "[$(date -Iseconds)] WARNING: Unknown target '$current_target'" >> "$CWD/feedback/warnings.log" 2>/dev/null || true
    fi
  fi
}

# --- Main ---

# Find active workspace
ACTIVE_WORKSPACE=$(find_active_workspace) || exit 0
FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"

# Route from .md files (primary mechanism)
if [ -d "$FEEDBACK_DIR" ]; then
  FEEDBACK_FILES=$(find "$FEEDBACK_DIR" -maxdepth 1 -name "*.md" 2>/dev/null)

  if [ -n "$FEEDBACK_FILES" ]; then
    echo "$FEEDBACK_FILES" | while read -r feedback_file; do
      [ -f "$feedback_file" ] || continue

      # Skip already-routed files (marked by companion .routed file)
      if [ -f "${feedback_file}.routed" ]; then
        continue
      fi

      source_basename=$(basename "$feedback_file" .md)
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"

      # Mark as routed instead of deleting
      touch "${feedback_file}.routed"
    done
  fi
fi

# Route from last_assistant_message (P1 — catches inline feedback)
if [ -n "$LAST_MESSAGE" ]; then
  if echo "$LAST_MESSAGE" | grep -qE '\[(PPU|OQI|GATE|STA)-[0-9]+\]'; then
    parse_and_route_signals "$LAST_MESSAGE" "inline-final-message"
  fi
fi

exit 0
