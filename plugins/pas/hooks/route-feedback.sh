#!/usr/bin/env bash
set -euo pipefail

# Stop hook: routes feedback signals from workspace feedback inbox to artifact backlogs.
# Guard: if no feedback files exist, exit 0 immediately.
# For each .md file: parse signal blocks, extract Target fields, route to artifact backlogs.

# Read hook event JSON from stdin
INPUT=$(cat)

# Extract working directory
CWD=$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$CWD" ]; then
  exit 0
fi

# --- Functions ---

find_active_workspace() {
  local workspace_dir="$CWD/workspace"
  if [ ! -d "$workspace_dir" ]; then
    return 1
  fi

  # Find the most recently modified status.yaml
  local active_status
  active_status=$(find "$workspace_dir" -name "status.yaml" -print 2>/dev/null | while read -r f; do
    echo "$(stat -c %Y "$f" 2>/dev/null || echo 0) $f"
  done | sort -rn | head -1 | awk '{print $2}')

  if [ -z "$active_status" ]; then
    return 1
  fi

  dirname "$active_status"
}

resolve_target_path() {
  # Map a Target: field to a filesystem backlog path
  # Target format examples:
  #   skill:writing (in context of process:article/agent:journalist)
  #   agent:researcher (in context of process:article)
  #   process:article
  local target="$1"
  local source_file="$2"
  local type value

  type=$(echo "$target" | cut -d: -f1)
  value=$(echo "$target" | cut -d: -f2-)

  case "$type" in
    process)
      echo "$CWD/processes/$value/feedback/backlog"
      ;;
    agent)
      # Search for the agent in all processes
      local found
      found=$(find "$CWD/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      if [ -n "$found" ]; then
        echo "$found"
      else
        echo ""
      fi
      ;;
    skill)
      # Search for the skill in all agent skill directories, then library
      local found
      found=$(find "$CWD/processes" -path "*/skills/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      if [ -n "$found" ]; then
        echo "$found"
      else
        found=$(find "$CWD/library" -path "*/$value/feedback/backlog" -type d 2>/dev/null | head -1)
        if [ -n "$found" ]; then
          echo "$found"
        else
          echo ""
        fi
      fi
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

# --- Main ---

# Find active workspace
ACTIVE_WORKSPACE=$(find_active_workspace) || exit 0
FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"

if [ ! -d "$FEEDBACK_DIR" ]; then
  exit 0
fi

# Find feedback .md files
FEEDBACK_FILES=$(find "$FEEDBACK_DIR" -maxdepth 1 -name "*.md" 2>/dev/null)

if [ -z "$FEEDBACK_FILES" ]; then
  exit 0
fi

# Process each feedback file
echo "$FEEDBACK_FILES" | while read -r feedback_file; do
  [ -f "$feedback_file" ] || continue

  source_basename=$(basename "$feedback_file" .md)

  # Extract signal blocks: each starts with [TYPE-NN] and ends before the next [TYPE-NN] or EOF
  current_signal=""
  current_id=""
  current_target=""

  while IFS= read -r line || [ -n "$line" ]; do
    # Check if this line starts a new signal block
    if echo "$line" | grep -qE '^\[(PPU|OQI|GATE|STA)-[0-9]+\]'; then
      # Route the previous signal if we have one
      if [ -n "$current_signal" ] && [ -n "$current_target" ]; then
        target_path=$(resolve_target_path "$current_target" "$feedback_file")
        if [ -n "$target_path" ]; then
          route_signal "$current_signal" "$current_id" "$source_basename" "$target_path"
        else
          echo "[$(date -Iseconds)] WARNING: Unknown target '$current_target' in $feedback_file" >> "$CWD/feedback/warnings.log" 2>/dev/null || true
        fi
      fi

      # Start new signal block
      current_id=$(echo "$line" | grep -oE '(PPU|OQI|GATE|STA)-[0-9]+')
      current_signal="$line"
      current_target=""
    else
      # Append to current signal block
      if [ -n "$current_id" ]; then
        current_signal="$current_signal
$line"
      fi

      # Extract Target field
      if echo "$line" | grep -qE '^Target:'; then
        current_target=$(echo "$line" | sed 's/^Target:[[:space:]]*//')
      fi
    fi
  done < "$feedback_file"

  # Route the last signal block
  if [ -n "$current_signal" ] && [ -n "$current_target" ]; then
    target_path=$(resolve_target_path "$current_target" "$feedback_file")
    if [ -n "$target_path" ]; then
      route_signal "$current_signal" "$current_id" "$source_basename" "$target_path"
    else
      mkdir -p "$CWD/feedback"
      echo "[$(date -Iseconds)] WARNING: Unknown target '$current_target' in $feedback_file" >> "$CWD/feedback/warnings.log" 2>/dev/null || true
    fi
  fi

  # Clean up the processed feedback file
  rm "$feedback_file"
done

exit 0
