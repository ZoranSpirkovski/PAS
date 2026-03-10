# Hook Script Patterns

## Standard Boilerplate

Every command hook script starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Read hook event JSON from stdin
INPUT=$(cat)
```

## Extracting Fields

### With jq (preferred)

```bash
CWD=$(echo "$INPUT" | jq -r '.cwd')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
AGENT_TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')
LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
```

### Without jq (grep/sed fallback)

```bash
CWD=$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
```

Use jq when available. The grep/sed approach is fragile with nested JSON but works for top-level string fields.

## Exit Code Semantics

| Exit code | Meaning |
|-----------|---------|
| 0 | Success. Action proceeds. Stdout parsed for JSON output. |
| 2 | Blocking error. Action blocked (on events that support blocking). Stderr fed to Claude. |
| Other | Non-blocking error. Stderr logged in verbose mode. Action proceeds. |

**Critical:** Exit 2 only blocks on events that support it (see event-catalog.md). On non-blocking events, exit 2 just logs stderr.

## JSON Output Patterns

### Allow with no output (most common)

```bash
exit 0
```

### Block with stderr message

```bash
echo "Reason for blocking" >&2
exit 2
```

### Structured decision (PreToolUse)

```bash
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Reason here"
  }
}'
exit 0
```

PreToolUse supports three decisions:
- `"allow"` — bypasses the permission system
- `"deny"` — prevents the tool call, reason shown to Claude
- `"ask"` — prompts the user to confirm

### Structured decision (Stop/SubagentStop/PostToolUse)

```bash
jq -n '{
  decision: "block",
  reason: "Reason to continue working"
}'
exit 0
```

### Stop processing entirely

```bash
jq -n '{
  continue: false,
  stopReason: "Build failed, fix errors before continuing"
}'
exit 0
```

### Add context (SessionStart/UserPromptSubmit)

Plain text to stdout is added as context:

```bash
echo "Reminder: use bun, not npm."
exit 0
```

Or structured:

```bash
jq -n '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: "Context string here"
  }
}'
exit 0
```

## Stop Hook Infinite Loop Prevention

**Every Stop/SubagentStop hook MUST check `stop_hook_active`:**

```bash
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0  # Already continuing from a stop hook, allow stop
fi
```

Without this, a Stop hook that returns `decision: "block"` will fire again when Claude finishes responding to the block, creating an infinite loop.

## PAS Guard Pattern

For hooks that should only fire in PAS-enabled repos:

```bash
PAS_CONFIG="$CWD/.pas/config.yaml"
if [ ! -f "$PAS_CONFIG" ]; then
  exit 0  # Not a PAS repo, skip
fi
```

## Enhanced Field Extraction (P1)

### Using agent_id for identification

```bash
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
# Include in warnings so we know WHICH agent had the issue
echo "WARNING: Agent $AGENT_ID shutdown without self-eval" >> "$WARNINGS_DIR/warnings.log"
```

### Using agent_transcript_path for secondary detection

```bash
AGENT_TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')
if [ -n "$AGENT_TRANSCRIPT" ] && [ -f "$AGENT_TRANSCRIPT" ]; then
  # Scan transcript for signal patterns as secondary check
  SIGNAL_COUNT=$(grep -cE '\[(PPU|OQI|GATE|STA)-[0-9]+\]' "$AGENT_TRANSCRIPT" 2>/dev/null || echo 0)
  if [ "$SIGNAL_COUNT" -gt 0 ]; then
    # Found inline signals in transcript — agent did self-eval even without a file
    exit 0
  fi
fi
```

### Using last_assistant_message for signal extraction

```bash
LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
if [ -n "$LAST_MESSAGE" ]; then
  # Parse signal blocks from final message (catches feedback not saved to file)
  echo "$LAST_MESSAGE" | grep -oE '\[(PPU|OQI|GATE|STA)-[0-9]+\]' | while read -r signal_header; do
    # Extract and route signal...
  done
fi
```

## Finding Active Workspace (sort-by-mtime)

**Correct approach** (not `-newer` which is fragile):

```bash
find_active_workspace() {
  local workspace_dir="$CWD/.pas/workspace"
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
```

Note: includes both Linux (`stat -c %Y`) and macOS (`stat -f %m`) fallback.

## Safe Directory Creation

**Always `mkdir -p` before writing logs:**

```bash
mkdir -p "$CWD/.pas/feedback"
echo "[$(date -Iseconds)] WARNING: ..." >> "$CWD/.pas/feedback/warnings.log"
```

## Path References

| Hook location | Script path prefix | Example |
|--------------|-------------------|---------|
| Plugin `hooks/hooks.json` | `${CLAUDE_PLUGIN_ROOT}` | `${CLAUDE_PLUGIN_ROOT}/hooks/script.sh` |
| Project `.claude/settings.json` | `$CLAUDE_PROJECT_DIR` | `"$CLAUDE_PROJECT_DIR"/.claude/hooks/script.sh` |
| Global `~/.claude/settings.json` | Absolute path | `/home/user/.claude/hooks/script.sh` |
| Frontmatter | Relative to project | `./scripts/validate.sh` |

## Security Checklist

- [ ] Always quote shell variables: `"$VAR"` not `$VAR`
- [ ] Use absolute paths or `$CLAUDE_PROJECT_DIR`/`${CLAUDE_PLUGIN_ROOT}`
- [ ] Check for path traversal (`..`) in file paths from input
- [ ] Skip sensitive files (`.env`, `.git/`, keys)
- [ ] Validate and sanitize inputs from stdin
- [ ] Redirect non-output to stderr to avoid corrupting JSON output
