#!/usr/bin/env bash
set -euo pipefail

# SubagentStop safety net — checks if agent wrote self-eval.
# Enhanced: uses agent_id for identification, agent_transcript_path
# for secondary detection, sort-by-mtime instead of -newer.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/guards.sh"

guard_parse_input || exit 0

AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
AGENT_TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

guard_feedback_enabled || exit 0

# Scope this hook to PAS-process agents only. Generic Explore / Plan /
# general-purpose subagents get spawned all the time during PAS sessions
# and must not be blocked or have their work treated as PAS feedback
# (#38, #67, #68). guard_agent_in_active_process is safe-fail (returns 0)
# when agent_type is empty/unknown or the workspace allowlist is
# unresolvable, preserving over-blocking on older CC versions.
if ! guard_agent_in_active_process "$AGENT_TYPE" "$SCRIPT_DIR"; then
  exit 0  # Not a PAS-process agent — silently skip
fi

guard_active_workspace "$SCRIPT_DIR" || exit 0

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

# Secondary check (P1): scan transcript for inline signal patterns.
# Note: `grep -c` writes "0" to stdout AND exits 1 on zero matches, so the
# old `|| echo 0` captured a two-line "0\n0" that broke the integer test.
if [ -n "$AGENT_TRANSCRIPT" ] && [ -f "$AGENT_TRANSCRIPT" ]; then
  SIGNAL_COUNT=$(grep -cE '\[(PPU|OQI|GATE|STA)-[0-9]+\]' "$AGENT_TRANSCRIPT" 2>/dev/null) || SIGNAL_COUNT=0
  if [ "$SIGNAL_COUNT" -gt 0 ]; then
    exit 0  # Found inline signals — agent did self-eval in conversation
  fi
fi

# Tertiary check (#71): substantive plain-text response detected.
# The bug we're fixing: parents were receiving a hook-injected "Self-
# evaluation written" summary INSTEAD of the agent's actual review/
# exploration text. If the agent's last_assistant_message is long AND not
# a known summary boilerplate, treat it as substantive — bypass the gate
# and emit an audit line so the bypass is visible.
LAST_MSG_LEN=$(echo -n "$LAST_MSG" | wc -c | tr -d ' ')
if [ -n "$LAST_MSG" ] && [ "$LAST_MSG_LEN" -gt 200 ]; then
  # Known summary boilerplates that should NOT count as substantive.
  # Match the exact strings observed in #71 / #68 / #38 reports.
  if ! echo "$LAST_MSG" | head -c 400 | grep -qiE 'self-evaluation written|self-evaluation has been written|no issues detected|written to the requested location|feedback file written|written\. (no issues|task tracking)'; then
    echo "PAS feedback hook INFO: substantive response detected (${LAST_MSG_LEN} chars), gate bypassed for agent '${AGENT_ID}'" >&2
    exit 0
  fi
fi

# No self-eval found — block subagent from stopping.
cat >&2 <<EOF
PAS feedback hook: agent '${AGENT_ID}' is shutting down without writing self-evaluation.

This is required when feedback is enabled in .pas/config.yaml.

To resolve, write your evaluation to:
  ${FEEDBACK_DIR}/${AGENT_ID}.md

If nothing went wrong, the file may contain just: "No issues detected."

Format reference: .pas/library/self-evaluation/SKILL.md
To disable feedback for this project: edit .pas/config.yaml → feedback: disabled
EOF
exit 2
