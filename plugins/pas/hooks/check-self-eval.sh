#!/usr/bin/env bash
set -euo pipefail

# SubagentStop safety net
# Checks if agent wrote self-eval to workspace feedback inbox.
# If missing: log warning. If present or no workspace context: exit 0.
# No LLM calls, pure file operations.

# Read hook event JSON from stdin
INPUT=$(cat)

# Extract working directory
CWD=$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$CWD" ]; then
  exit 0
fi

# Check if feedback is enabled
PAS_CONFIG="$CWD/pas-config.yaml"
if [ ! -f "$PAS_CONFIG" ]; then
  exit 0
fi

FEEDBACK_STATUS=$(grep -o 'feedback:[[:space:]]*\w*' "$PAS_CONFIG" | head -1 | awk '{print $NF}')
if [ "$FEEDBACK_STATUS" != "enabled" ]; then
  exit 0
fi

# Find workspace feedback directories (look for active workspaces)
# We check workspace/ for any directory containing a status.yaml with status: in_progress
WORKSPACE_DIR="$CWD/workspace"
if [ ! -d "$WORKSPACE_DIR" ]; then
  exit 0
fi

# Find the most recently modified status.yaml that shows in_progress
ACTIVE_STATUS=$(find "$WORKSPACE_DIR" -name "status.yaml" -newer "$WORKSPACE_DIR" -print 2>/dev/null | head -1)
if [ -z "$ACTIVE_STATUS" ]; then
  exit 0
fi

ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"

if [ ! -d "$FEEDBACK_DIR" ]; then
  exit 0
fi

# Count feedback files (excluding .gitkeep)
FEEDBACK_COUNT=$(find "$FEEDBACK_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)

if [ "$FEEDBACK_COUNT" -eq 0 ]; then
  # No self-eval files found, log warning
  WARNINGS_DIR="$CWD/feedback"
  mkdir -p "$WARNINGS_DIR"
  echo "[$(date -Iseconds)] WARNING: Agent shutdown without writing self-eval to $FEEDBACK_DIR" >> "$WARNINGS_DIR/warnings.log"
fi

exit 0
