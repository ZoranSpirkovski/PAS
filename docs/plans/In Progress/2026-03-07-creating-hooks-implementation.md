# Creating-Hooks Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `creating-hooks` skill to the PAS orchestrator that produces structurally correct hook configurations, scripts, and PAS feedback infrastructure.

**Architecture:** A new skill at `processes/pas/agents/orchestrator/skills/creating-hooks/` with a SKILL.md workflow and 4 reference files. Integrates with the PAS router, orchestrator agent.md, and creating-processes skill.

**Tech Stack:** Markdown (SKILL.md, references), Shell (script patterns), JSON (hooks schema)

---

### Task 1: Scaffold the creating-hooks skill directory

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/SKILL.md`
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/.gitkeep`
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/feedback/backlog/.gitkeep`
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/changelog.md`

**Step 1: Create directory structure**

```bash
mkdir -p plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references
mkdir -p plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/feedback/backlog
```

**Step 2: Create placeholder files**

Create empty `.gitkeep` in `feedback/backlog/` and `references/`.

Create `changelog.md`:

```markdown
# creating-hooks changelog

## 2026-03-07 — Initial creation

Created as the 5th PAS orchestrator skill. Provides a structured workflow for creating Claude Code hooks with correct schema, event selection, script patterns, and PAS feedback infrastructure setup.

Design doc: `docs/plans/2026-03-07-creating-hooks-skill-design.md`
```

**Step 3: Create SKILL.md placeholder**

Create a minimal SKILL.md with just the frontmatter — full content comes in Task 2:

```yaml
---
name: creating-hooks
description: Use when creating or editing Claude Code hooks for a PAS process, plugin, or component. Invoked by creating-processes or standalone for adding hooks to existing artifacts.
---

# Creating Hooks

(Content in next task)
```

**Step 4: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/
git commit -m "Scaffold creating-hooks skill directory"
```

---

### Task 2: Write SKILL.md workflow

**Files:**
- Modify: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/SKILL.md`

**Step 1: Write the full SKILL.md**

Replace placeholder content with the complete workflow. The SKILL.md should follow the same structural pattern as `creating-skills/SKILL.md` and `creating-processes/SKILL.md`. Content:

```yaml
---
name: creating-hooks
description: Use when creating or editing Claude Code hooks for a PAS process, plugin, or component. Invoked by creating-processes or standalone for adding hooks to existing artifacts.
---
```

Followed by these sections:

**# Creating Hooks**

Opening paragraph: Create Claude Code hooks that automate lifecycle behavior — guards that block bad actions, observers that log and notify, and reactors that take action after events. Hooks are JSON configuration plus optional shell scripts. This skill ensures structurally correct output.

**## When to Use**

- Creating hooks for a new PAS process (invoked by creating-processes)
- Adding hooks to an existing process or plugin
- Setting up PAS feedback infrastructure (check-self-eval, route-feedback)
- Adding lifecycle automation (validation, notification, cleanup) to any artifact
- NOT for modifying existing hooks — use applying-feedback for that

**## Workflow**

### 1. Determine Purpose

Define what the hook does:

- **Behavior**: what should happen automatically at which lifecycle point?
- **Classification**: guard (block bad actions), observer (log/notify), or reactor (do something after an event)?
- **Location**: plugin (`hooks/hooks.json`), project (`.claude/settings.json`), or component (skill/agent frontmatter)?
- **Handler type**: deterministic (command/http) or judgment-based (prompt/agent)?

### 1a. PAS Feedback Hook Setup

If creating hooks for a PAS process and `pas-config.yaml` has `feedback: enabled`:

- Read `references/pas-feedback-hooks.md`
- Generate enhanced `check-self-eval.sh` and `route-feedback.sh`
- Register hooks in the correct location (see issue #3 guidance in the reference)
- This step is automatic when invoked by creating-processes with feedback enabled

### 2. Select Event & Handler Type

- Read `references/event-catalog.md`
- Use the decision matrix to select the right event based on purpose
- Verify the event supports matchers if a matcher is needed
- Verify the event supports the chosen handler type
- Choose matcher pattern if applicable

### 3. Write Hook Configuration

- Read `references/hooks-schema.md`
- Generate JSON with the correct 3-level nesting: event → matcher group array → hooks handler array
- Use the correct structure for the chosen location (hooks.json vs settings vs frontmatter)
- Use `${CLAUDE_PLUGIN_ROOT}` for plugin hooks, `$CLAUDE_PROJECT_DIR` for project hooks

### 4. Write Hook Scripts (if command type)

- Read `references/script-patterns.md`
- Generate shell script with correct boilerplate:
  - `#!/usr/bin/env bash` + `set -euo pipefail`
  - `INPUT=$(cat)` for stdin
  - Field extraction via `jq` or `grep`/`sed`
  - Correct exit code semantics for the chosen event
  - JSON output format if structured control is needed
- Apply security practices: quote all variables, use absolute paths, validate inputs

### 5. Validate

Before presenting the hook to the user, verify:

- [ ] JSON structure has correct nesting depth (event → matcher group[] → hooks[])
- [ ] Event name is one of the 19 valid events
- [ ] Matcher is only used on events that support matchers
- [ ] Handler type is supported for the chosen event
- [ ] `type` field is present on every handler
- [ ] `command` field is present for command handlers, `url` for http, `prompt` for prompt/agent
- [ ] Script uses `set -euo pipefail` and reads from stdin
- [ ] Exit codes match event semantics (exit 2 only on blocking events)
- [ ] Path references match hook location (`${CLAUDE_PLUGIN_ROOT}` vs `$CLAUDE_PROJECT_DIR`)
- [ ] Scripts are marked executable

**## Output Format**

For each hook created, produce:

1. Hook configuration JSON (for hooks.json, settings, or frontmatter)
2. Hook script file(s) if command type
3. Registration instructions (where to add the config, how to make scripts executable)

**## Quality Checks**

- Does the JSON parse without errors?
- Is the nesting correct? (The #1 source of past errors)
- Does the event match the intended behavior?
- For PAS feedback hooks: do scripts handle missing directories gracefully?

**## Common Mistakes**

- Putting the `hooks` handler array directly under the event instead of inside a matcher group
- Using matchers on events that don't support them (Stop, UserPromptSubmit, TeammateIdle, TaskCompleted, WorktreeCreate, WorktreeRemove)
- Using prompt/agent handler types on events that only support command (SessionStart, SubagentStart, TeammateIdle, etc.)
- Forgetting `mkdir -p` before writing to log files
- Using `-newer` instead of sort-by-mtime for finding recent files
- Not quoting shell variables containing paths

**Step 2: Verify SKILL.md is under 500 lines**

```bash
wc -l plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/SKILL.md
```

Expected: under 500 lines.

**Step 3: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/SKILL.md
git commit -m "Add creating-hooks SKILL.md workflow"
```

---

### Task 3: Write references/hooks-schema.md

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/hooks-schema.md`

**Step 1: Write hooks-schema.md**

This is the primary defense against structural errors. It must encode the exact JSON nesting rules for all three hook locations. Content:

**# Hook Configuration Schema**

## The Critical Nesting Rule

Every hook configuration follows a 3-level nesting pattern. Getting this wrong is the #1 source of errors:

```
event_name → [ matcher_group, ... ] → { hooks: [ handler, ... ] }
```

**Level 1: Event name** (string key) — one of the 19 hook events
**Level 2: Matcher groups** (array of objects) — each has optional `matcher` + required `hooks` array
**Level 3: Hook handlers** (array of objects inside each matcher group's `hooks` field) — the actual commands/prompts/etc.

## Correct Structure Examples

### Plugin hooks.json

```json
{
  "description": "Optional description of what these hooks do",
  "hooks": {
    "EventName": [
      {
        "matcher": "optional-regex-pattern",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/script.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

- Top-level `description` is optional, `hooks` is required
- Use `${CLAUDE_PLUGIN_ROOT}` for script paths (resolved at runtime)
- The `matcher` field is optional — omit it to match all occurrences

### Project/user settings.json

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "optional-regex-pattern",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/script.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

- `hooks` sits alongside other settings fields
- Use `$CLAUDE_PROJECT_DIR` for script paths (wrap in quotes for spaces)
- Global settings (`~/.claude/settings.json`) use the same structure

### Skill/agent frontmatter

```yaml
---
name: my-skill
description: Use when...
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
  Stop:
    - hooks:
        - type: prompt
          prompt: "Check if tasks are complete. $ARGUMENTS"
---
```

- `hooks` is a YAML key in the frontmatter alongside `name` and `description`
- Same nesting structure as JSON but in YAML format
- Component hooks only fire while the skill/agent is active
- `once: true` supported on skill hooks (fires once then removed)
- For agents, `Stop` hooks are auto-converted to `SubagentStop`

## Wrong vs Right

**WRONG — handlers directly under event:**
```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "script.sh"
      }
    ]
  }
}
```

**RIGHT — handlers inside matcher group's hooks array:**
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "script.sh"
          }
        ]
      }
    ]
  }
}
```

The difference: the event's array contains **matcher group objects**, not handler objects. Each matcher group has its own `hooks` array containing handlers.

## Handler Type Fields

### Command handler (type: "command")

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | `"command"` |
| `command` | yes | Shell command to execute |
| `timeout` | no | Seconds before canceling (default: 600) |
| `statusMessage` | no | Custom spinner message |
| `once` | no | If true, runs once per session then removed (skills only) |
| `async` | no | If true, runs in background without blocking |

### HTTP handler (type: "http")

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | `"http"` |
| `url` | yes | URL to POST to |
| `timeout` | no | Seconds (default: 600) |
| `headers` | no | Key-value pairs, supports `$VAR_NAME` interpolation |
| `allowedEnvVars` | no | List of env var names allowed in header interpolation |
| `statusMessage` | no | Custom spinner message |

### Prompt handler (type: "prompt")

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | `"prompt"` |
| `prompt` | yes | Prompt text. `$ARGUMENTS` placeholder for hook input JSON |
| `model` | no | Model to use (default: fast model) |
| `timeout` | no | Seconds (default: 30) |
| `statusMessage` | no | Custom spinner message |

### Agent handler (type: "agent")

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | `"agent"` |
| `prompt` | yes | Prompt text. `$ARGUMENTS` placeholder for hook input JSON |
| `model` | no | Model to use (default: fast model) |
| `timeout` | no | Seconds (default: 60) |
| `statusMessage` | no | Custom spinner message |

## Agent-Level Hook Declarations (P2)

Agents can declare hooks in their YAML frontmatter for defense-in-depth:

```yaml
---
name: researcher
description: Research agent
hooks:
  PostToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-output.sh"
---
```

**When to use agent-level hooks vs plugin-level hooks:**

- Plugin-level: broad concerns that apply to all sessions (feedback infrastructure)
- Agent-level: domain-specific concerns scoped to one agent's lifecycle
- Both can coexist — agent hooks fire alongside plugin hooks

**Step 2: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/hooks-schema.md
git commit -m "Add hooks-schema.md reference for creating-hooks"
```

---

### Task 4: Write references/event-catalog.md

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/event-catalog.md`

**Step 1: Write event-catalog.md**

This is the comprehensive event reference. Content:

**# Hook Event Catalog**

## Event Selection Decision Matrix

| I want to... | Use event | Handler types |
|--------------|-----------|---------------|
| Block dangerous commands before they run | PreToolUse | command, http, prompt, agent |
| Auto-approve or deny permissions | PermissionRequest | command, http, prompt, agent |
| Format/lint files after edits | PostToolUse | command, http, prompt, agent |
| React to tool failures | PostToolUseFailure | command, http, prompt, agent |
| Validate/transform user prompts | UserPromptSubmit | command, http, prompt, agent |
| Prevent Claude from stopping prematurely | Stop | command, http, prompt, agent |
| Check subagent output before it finishes | SubagentStop | command, http, prompt, agent |
| Enforce task completion criteria | TaskCompleted | command, http, prompt, agent |
| Load context at session start | SessionStart | command only |
| Clean up at session end | SessionEnd | command only |
| Inject context into subagents | SubagentStart | command only |
| Enforce teammate quality gates | TeammateIdle | command only |
| Audit config changes | ConfigChange | command only |
| Re-inject context after compaction | PreCompact | command only |
| Custom worktree creation (non-git VCS) | WorktreeCreate | command only |
| Custom worktree cleanup | WorktreeRemove | command only |
| Send desktop notifications | Notification | command only |
| Track instruction file loading | InstructionsLoaded | command only |

## Events That Support Matchers

| Event | Matcher filters | Example values |
|-------|----------------|----------------|
| PreToolUse | tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| PostToolUse | tool name | same as PreToolUse |
| PostToolUseFailure | tool name | same as PreToolUse |
| PermissionRequest | tool name | same as PreToolUse |
| SessionStart | how session started | `startup`, `resume`, `clear`, `compact` |
| SessionEnd | why session ended | `clear`, `logout`, `prompt_input_exit`, `other` |
| Notification | notification type | `permission_prompt`, `idle_prompt`, `auth_success` |
| SubagentStart | agent type | `Bash`, `Explore`, `Plan`, custom names |
| SubagentStop | agent type | same as SubagentStart |
| PreCompact | compaction trigger | `manual`, `auto` |
| ConfigChange | config source | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |

## Events That Do NOT Support Matchers

These always fire on every occurrence. Adding `matcher` is silently ignored:

- UserPromptSubmit
- Stop
- TeammateIdle
- TaskCompleted
- WorktreeCreate
- WorktreeRemove
- InstructionsLoaded

## Events That Can Block (exit code 2)

| Event | What exit 2 does |
|-------|-----------------|
| PreToolUse | Blocks the tool call |
| PermissionRequest | Denies the permission |
| UserPromptSubmit | Blocks prompt processing, erases prompt |
| Stop | Prevents Claude from stopping, continues conversation |
| SubagentStop | Prevents subagent from stopping |
| TeammateIdle | Prevents teammate from going idle |
| TaskCompleted | Prevents task from being marked complete |
| ConfigChange | Blocks config change (except policy_settings) |
| WorktreeCreate | Any non-zero fails creation |

## Events That Cannot Block (exit 2 = informational only)

- PostToolUse — tool already ran, stderr shown to Claude
- PostToolUseFailure — tool already failed, stderr shown to Claude
- Notification — stderr shown to user only
- SubagentStart — stderr shown to user only
- SessionStart — stderr shown to user only
- SessionEnd — stderr shown to user only
- PreCompact — stderr shown to user only
- WorktreeRemove — failures logged in debug only
- InstructionsLoaded — exit code ignored

## Common Input Fields (all events)

| Field | Description |
|-------|-------------|
| `session_id` | Current session identifier |
| `transcript_path` | Path to conversation JSON |
| `cwd` | Current working directory |
| `permission_mode` | Current permission mode |
| `hook_event_name` | Name of the event that fired |
| `agent_id` | Unique subagent identifier (when in subagent) |
| `agent_type` | Agent name (when in subagent or --agent mode) |

## Event-Specific Input Fields

### PreToolUse / PostToolUse / PostToolUseFailure / PermissionRequest

- `tool_name`: name of the tool (Bash, Edit, Write, Read, etc.)
- `tool_input`: tool arguments (varies by tool)
- `tool_use_id`: unique ID for this tool call (not on PermissionRequest)
- PostToolUse adds `tool_response`
- PostToolUseFailure adds `error` and `is_interrupt`

### Stop / SubagentStop

- `stop_hook_active`: boolean — true if already continuing from a stop hook (CHECK THIS to prevent infinite loops)
- `last_assistant_message`: text of Claude's final response
- SubagentStop adds: `agent_id`, `agent_type`, `agent_transcript_path`

### SessionStart

- `source`: `"startup"`, `"resume"`, `"clear"`, or `"compact"`
- `model`: model identifier
- Has access to `CLAUDE_ENV_FILE` for persisting env vars

### UserPromptSubmit

- `prompt`: the text the user submitted

### SubagentStart

- `agent_id`, `agent_type`

### TeammateIdle

- `teammate_name`, `team_name`

### TaskCompleted

- `task_id`, `task_subject`, `task_description` (optional), `teammate_name` (optional), `team_name` (optional)

### ConfigChange

- `source`: which config type changed
- `file_path`: path to changed file

### Notification

- `message`, `title` (optional), `notification_type`

### WorktreeCreate

- `name`: slug identifier for the worktree

### WorktreeRemove

- `worktree_path`: absolute path to worktree being removed

### PreCompact

- `trigger`: `"manual"` or `"auto"`
- `custom_instructions`: user's compact instructions (manual only)

### SessionEnd

- `reason`: `"clear"`, `"logout"`, `"prompt_input_exit"`, `"bypass_permissions_disabled"`, `"other"`

### InstructionsLoaded

- `file_path`, `memory_type`, `load_reason`, `globs` (optional), `trigger_file_path` (optional), `parent_file_path` (optional)

**Step 2: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/event-catalog.md
git commit -m "Add event-catalog.md reference for creating-hooks"
```

---

### Task 5: Write references/script-patterns.md

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/script-patterns.md`

**Step 1: Write script-patterns.md**

This encodes correct shell script patterns including P1 enhancements. Content:

**# Hook Script Patterns**

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
PAS_CONFIG="$CWD/pas-config.yaml"
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
```

Note: includes both Linux (`stat -c %Y`) and macOS (`stat -f %m`) fallback.

## Safe Directory Creation

**Always `mkdir -p` before writing logs:**

```bash
mkdir -p "$CWD/feedback"
echo "[$(date -Iseconds)] WARNING: ..." >> "$CWD/feedback/warnings.log"
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

**Step 2: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/script-patterns.md
git commit -m "Add script-patterns.md reference for creating-hooks"
```

---

### Task 6: Write references/pas-feedback-hooks.md

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md`

**Step 1: Write pas-feedback-hooks.md**

This documents the PAS-specific feedback hooks with all P1 enhancements and issue #3 fixes baked in. Content:

**# PAS Feedback Hook Patterns**

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

**Step 2: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md
git commit -m "Add pas-feedback-hooks.md reference for creating-hooks"
```

---

### Task 7: Update orchestrator agent.md

**Files:**
- Modify: `plugins/pas/processes/pas/agents/orchestrator/agent.md:8` (skills list)
- Modify: `plugins/pas/processes/pas/agents/orchestrator/agent.md:27` (routing rules)
- Modify: `plugins/pas/processes/pas/agents/orchestrator/agent.md:34` (deliverables)

**Step 1: Add creating-hooks to skills list**

In the YAML frontmatter `skills:` array at line 8, add:

```yaml
  - skills/creating-hooks/SKILL.md
```

After `skills/applying-feedback/SKILL.md`.

**Step 2: Add routing rule**

In the Behavior section, add to the routing rules after "Creating something new":

```markdown
  - Creating hooks or lifecycle automation: use creating-hooks
```

**Step 3: Add deliverable**

In the Deliverables section, add:

```markdown
- Created or modified hooks (`hooks.json`, settings hooks, frontmatter hooks, hook scripts)
```

**Step 4: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/agent.md
git commit -m "Add creating-hooks skill to orchestrator agent"
```

---

### Task 8: Update PAS router

**Files:**
- Modify: `plugins/pas/skills/pas/SKILL.md:13` (routing section)

**Step 1: Add routing rule for hooks**

In the Quick Routing section, add after the "Creating something new" rule:

```markdown
- **Creating hooks** (hook, lifecycle, guard, automation, when something happens): read `creating-hooks/SKILL.md`
```

**Step 2: Commit**

```bash
git add plugins/pas/skills/pas/SKILL.md
git commit -m "Add hooks routing rule to PAS router"
```

---

### Task 9: Update creating-processes skill

**Files:**
- Modify: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md`

**Step 1: Add hooks step**

After Step 8 (Create Agents) and before Step 9 (Verify Against Source Material), add:

```markdown
### 8.5. Determine Hooks

Does this process need lifecycle hooks?

- If `pas-config.yaml` has `feedback: enabled` and the process uses agents: invoke `creating-hooks/SKILL.md` step 1a for PAS feedback infrastructure
- If the process has specific lifecycle needs (validation before tool use, cleanup at session end, notification on completion): invoke `creating-hooks/SKILL.md` with the specific requirements
- If neither applies: skip this step

Read `creating-hooks/SKILL.md` from the same skills directory as this skill.
```

**Step 2: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md
git commit -m "Add hooks step to creating-processes workflow"
```

---

### Task 10: Remove .gitkeep from references/ and final commit

**Files:**
- Delete: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/.gitkeep`

**Step 1: Remove .gitkeep since references/ now has real files**

```bash
rm plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/.gitkeep
```

**Step 2: Verify complete directory structure**

```bash
find plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/ -type f | sort
```

Expected:
```
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/SKILL.md
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/changelog.md
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/feedback/backlog/.gitkeep
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/event-catalog.md
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/hooks-schema.md
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/script-patterns.md
```

**Step 3: Final verification — all modified files parse correctly**

```bash
# Verify YAML frontmatter in SKILL.md
head -5 plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/SKILL.md

# Verify orchestrator agent.md lists creating-hooks
grep "creating-hooks" plugins/pas/processes/pas/agents/orchestrator/agent.md

# Verify PAS router has hooks routing
grep -i "hook" plugins/pas/skills/pas/SKILL.md

# Verify creating-processes has hooks step
grep -i "hook" plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md
```

**Step 4: Clean up .gitkeep and commit**

```bash
git add -A plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/
git commit -m "Remove .gitkeep from creating-hooks references (replaced by real files)"
```
