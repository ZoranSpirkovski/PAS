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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/workspace.sh"

# Find active workspace (sort-by-mtime approach)
WORKSPACE_DIR="$CWD/workspace"
if [ ! -d "$WORKSPACE_DIR" ]; then
  exit 0
fi

ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR") || exit 0

ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"

if [ ! -d "$FEEDBACK_DIR" ]; then
  exit 0
fi

# Primary check: agent-specific feedback file
if [ "$AGENT_ID" != "unknown" ] && [ -n "$AGENT_ID" ]; then
  # Look for files matching this agent's name pattern
  if find "$FEEDBACK_DIR" -maxdepth 1 \( -name "${AGENT_ID}.md" -o -name "${AGENT_ID}-*.md" \) 2>/dev/null | grep -q .; then
    exit 0  # Agent-specific self-eval found
  fi
else
  # Unknown agent — fall back to any .md file
  if find "$FEEDBACK_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | grep -q .; then
    exit 0  # Self-eval found (agent unknown, accepting any)
  fi
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
