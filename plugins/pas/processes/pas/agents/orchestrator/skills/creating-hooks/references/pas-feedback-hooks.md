# PAS Feedback Hook Patterns

## When to Set Up Feedback Hooks

Set up PAS feedback hooks when ALL of these are true:

1. The project has `pas-config.yaml` with `feedback: enabled`
2. The process uses agents (not solo orchestrator-only)
3. Agents carry `library/self-evaluation/SKILL.md`

## The Two Standard Hooks

### check-self-eval.sh (SubagentStop)

**Purpose:** Safety net that warns when an agent shuts down without writing self-evaluation.

**Event:** SubagentStop
**Handler:** command
**Timeout:** 10 seconds

**Enhanced script (with P1 improvements):**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop safety net — checks if agent wrote self-eval.
# Enhanced: uses agent_id for identification, agent_transcript_path
# for secondary detection, sort-by-mtime instead of -newer.

INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
AGENT_TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

# Guard: only run in PAS repos with feedback enabled
PAS_CONFIG="$CWD/pas-config.yaml"
if [ ! -f "$PAS_CONFIG" ]; then
  exit 0
fi

FEEDBACK_STATUS=$(grep -o 'feedback:[[:space:]]*\w*' "$PAS_CONFIG" | head -1 | awk '{print $NF}')
if [ "$FEEDBACK_STATUS" != "enabled" ]; then
  exit 0
fi

# Find active workspace (sort-by-mtime approach)
WORKSPACE_DIR="$CWD/workspace"
if [ ! -d "$WORKSPACE_DIR" ]; then
  exit 0
fi

ACTIVE_STATUS=$(find "$WORKSPACE_DIR" -name "status.yaml" -print 2>/dev/null | while read -r f; do
  echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0) $f"
done | sort -rn | head -1 | awk '{print $2}')

if [ -z "$ACTIVE_STATUS" ]; then
  exit 0
fi

ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"

if [ ! -d "$FEEDBACK_DIR" ]; then
  exit 0
fi

# Primary check: feedback .md files in workspace
FEEDBACK_COUNT=$(find "$FEEDBACK_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)

if [ "$FEEDBACK_COUNT" -gt 0 ]; then
  exit 0  # Self-eval found
fi

# Secondary check (P1): scan transcript for inline signal patterns
if [ -n "$AGENT_TRANSCRIPT" ] && [ -f "$AGENT_TRANSCRIPT" ]; then
  SIGNAL_COUNT=$(grep -cE '\[(PPU|OQI|GATE|STA)-[0-9]+\]' "$AGENT_TRANSCRIPT" 2>/dev/null || echo 0)
  if [ "$SIGNAL_COUNT" -gt 0 ]; then
    exit 0  # Found inline signals — agent did self-eval in conversation
  fi
fi

# No self-eval found — log warning with agent_id
WARNINGS_DIR="$CWD/feedback"
mkdir -p "$WARNINGS_DIR"
echo "[$(date -Iseconds)] WARNING: Agent '$AGENT_ID' shutdown without writing self-eval to $FEEDBACK_DIR" >> "$WARNINGS_DIR/warnings.log"

exit 0
```

### route-feedback.sh (Stop)

**Purpose:** Routes feedback signals from workspace feedback inbox to artifact backlogs.

**Event:** Stop
**Handler:** command
**Timeout:** 30 seconds

**Enhanced script (with P1 improvements and issue #3 fixes):**

```bash
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
      source_basename=$(basename "$feedback_file" .md)
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"
      rm "$feedback_file"
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
```

## Hook Registration

### For plugins (hooks/hooks.json)

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/check-self-eval.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/route-feedback.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### For projects (.claude/settings.json)

Per issue #3: plugin hooks.json may not fire reliably. As a fallback, register in project settings:

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/hooks/check-self-eval.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/hooks/route-feedback.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

## Known Pitfalls (from issue #3)

1. **Plugin hooks may not fire** — `hooks/hooks.json` in plugins requires Claude Code plugin system support. Verify hooks fire after registration; if not, fall back to project/global settings.
2. **Missing directories** — always `mkdir -p` before writing to log files or backlog directories.
3. **`-newer` is fragile** — use sort-by-mtime approach to find most recent status.yaml.
4. **Missing backlog targets** — if a signal targets `skill:creating-processes` but the skill doesn't exist in the live process tree, the signal is lost. The routing script logs a warning but the signal is not preserved. Consider creating the target directory or routing to the process-level backlog as fallback.
