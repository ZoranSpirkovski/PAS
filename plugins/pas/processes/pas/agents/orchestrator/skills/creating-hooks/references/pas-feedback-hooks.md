# PAS Feedback Hook Patterns

## When to Set Up Feedback Hooks

Set up PAS feedback hooks when ALL of these are true:

1. The project has `pas-config.yaml` with `feedback: enabled`
2. The process uses agents (not solo orchestrator-only)
3. Agents carry `library/self-evaluation/SKILL.md`

## The Two Standard Hooks

### check-self-eval.sh (SubagentStop)

**Purpose:** Blocks an agent from shutting down unless it has written its own self-evaluation file.

**Event:** SubagentStop
**Handler:** command
**Timeout:** 10 seconds

**Script (agent-specific check, blocking):**

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

# No self-eval found — block subagent from stopping
cat >&2 <<EOF
SELF-EVALUATION MISSING

Agent '${AGENT_ID}' is shutting down without writing self-evaluation.

Before stopping, write your self-evaluation to:
  ${FEEDBACK_DIR}/${AGENT_ID}.md

Use library/self-evaluation/SKILL.md for the format.
If nothing went wrong, write "No issues detected."
EOF
exit 2
```

### route-feedback.sh (Stop)

**Purpose:** Routes feedback signals from workspace feedback inbox to artifact backlogs. Framework signals (`Target: framework:pas` with `Route: github-issue`) are filed as GitHub issues automatically.

**Event:** Stop
**Handler:** command
**Timeout:** 30 seconds

**Script (with plugins/ fallback, framework routing, .routed markers):**

The canonical version lives at `plugins/pas/hooks/route-feedback.sh`. Key features:

- `resolve_target_path()` searches `$CWD/processes/`, then `$CWD/plugins/` as fallback for process/agent/skill targets
- `framework)` case returns sentinel `__framework__` which triggers `route_framework_signal()`
- `route_framework_signal()` files GitHub issues via `gh issue create` for signals marked `Route: github-issue`
- Guards: checks `gh auth status` before attempting; logs to `$CWD/feedback/framework-routing.log`
- Processed feedback files are marked with `.routed` companion file instead of deleted

Refer to the deployed script at `${CLAUDE_PLUGIN_ROOT}/hooks/route-feedback.sh` for the full implementation.

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
