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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/workspace.sh"

# --- Functions ---

find_active_workspace() {
  local status_path
  status_path=$(find_active_workspace_status "$CWD/workspace") || return 1
  dirname "$status_path"
}

resolve_target_path() {
  local target="$1"
  local type value

  type=$(echo "$target" | cut -d: -f1)
  value=$(echo "$target" | cut -d: -f2-)

  case "$type" in
    process)
      echo "$CWD/processes/$value/feedback/backlog"
      ;;
    agent)
      local found
      found=$(find "$CWD/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      echo "${found:-}"
      ;;
    skill)
      local found
      found=$(find "$CWD/processes" -path "*/skills/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      if [ -z "$found" ]; then
        found=$(find "$CWD/library" -path "*/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      fi
      echo "${found:-}"
      ;;
    framework)
      # Sentinel value — caller handles framework routing via route_framework_signal()
      echo "__framework__"
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

route_framework_signal() {
  local signal_block="$1"
  local signal_id="$2"
  local log_dir="$CWD/feedback"
  mkdir -p "$log_dir"

  # Guard: only route signals marked for GitHub issue creation
  if ! echo "$signal_block" | grep -q 'Route: github-issue'; then
    echo "[$(date -Iseconds)] INFO: Framework signal ${signal_id} not marked 'Route: github-issue', skipping" >> "$log_dir/framework-routing.log" 2>/dev/null || true
    return 0
  fi

  # Guard: check gh CLI is available and authenticated
  if ! command -v gh >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] WARNING: gh CLI not found, cannot route ${signal_id} to GitHub" >> "$log_dir/framework-routing.log" 2>/dev/null || true
    return 0
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] WARNING: gh not authenticated, cannot route ${signal_id} to GitHub" >> "$log_dir/framework-routing.log" 2>/dev/null || true
    return 0
  fi

  # Extract a one-line summary from the signal block
  local summary
  summary=$(echo "$signal_block" | grep -E '^(Degraded:|Preference:|Rejected Change:|Behavior:)' | head -1 | sed 's/^[^:]*:[[:space:]]*//')
  if [ -z "$summary" ]; then
    # Fallback: use the second line (first line after the signal ID header)
    summary=$(echo "$signal_block" | sed -n '2p' | sed 's/^[[:space:]]*//')
  fi
  # Truncate summary to 80 chars
  summary=$(echo "$summary" | cut -c1-80)

  # File as GitHub issue
  if gh issue create --repo ZoranSpirkovski/PAS \
    --title "[Feedback] ${signal_id}: ${summary}" \
    --body "$signal_block" >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] OK: Filed ${signal_id} as GitHub issue" >> "$log_dir/framework-routing.log" 2>/dev/null || true
  else
    echo "[$(date -Iseconds)] ERROR: Failed to file ${signal_id} as GitHub issue" >> "$log_dir/framework-routing.log" 2>/dev/null || true
  fi
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
        if [ "$target_path" = "__framework__" ]; then
          route_framework_signal "$current_signal" "$current_id"
        elif [ -n "$target_path" ]; then
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
    if [ "$target_path" = "__framework__" ]; then
      route_framework_signal "$current_signal" "$current_id"
    elif [ -n "$target_path" ]; then
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
      # Skip already-routed files
      [ -f "${feedback_file}.routed" ] && continue
      source_basename=$(basename "$feedback_file" .md)
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"
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
