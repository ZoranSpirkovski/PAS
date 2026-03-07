# Hook Configuration Schema

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

## Agent-Level Hook Declarations

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
