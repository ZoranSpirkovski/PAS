# Hook Event Catalog

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
