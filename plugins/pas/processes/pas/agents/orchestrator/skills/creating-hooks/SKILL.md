---
name: creating-hooks
description: Use when creating or editing Claude Code hooks for a PAS process, plugin, or component. Invoked by creating-processes or standalone for adding hooks to existing artifacts.
---

# Creating Hooks

Create Claude Code hooks that automate lifecycle behavior — guards that block bad actions, observers that log and notify, and reactors that take action after events. Hooks are JSON configuration plus optional shell scripts. This skill ensures structurally correct output by encoding the exact schema rules and patterns that prevent common errors.

## When to Use

- Creating hooks for a new PAS process (invoked by creating-processes step 8.5)
- Adding hooks to an existing process or plugin
- Setting up PAS feedback infrastructure (check-self-eval, route-feedback)
- Adding lifecycle automation (validation, notification, cleanup) to any artifact
- NOT for modifying existing hooks — use applying-feedback for that

## Workflow

### 1. Determine Purpose

Define what the hook does:

- **Behavior**: what should happen automatically at which lifecycle point?
- **Classification**: guard (block bad actions), observer (log/notify), or reactor (do something after an event)?
- **Location**: plugin (`hooks/hooks.json`), project (`.claude/settings.json`), or component (skill/agent frontmatter)?
- **Handler type**: deterministic (command/http) or judgment-based (prompt/agent)?

### 1a. PAS Feedback Hook Setup

If creating hooks for a PAS process and `pas-config.yaml` has `feedback: enabled`:

- Read `references/pas-feedback-hooks.md`
- Generate enhanced `check-self-eval.sh` (SubagentStop) and `route-feedback.sh` (Stop)
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

## Output Format

For each hook created, produce:

1. Hook configuration JSON (for hooks.json, settings, or frontmatter)
2. Hook script file(s) if command type
3. Registration instructions (where to add the config, how to make scripts executable)

## Quality Checks

- Does the JSON parse without errors?
- Is the nesting correct? (The #1 source of past errors)
- Does the event match the intended behavior?
- For PAS feedback hooks: do scripts handle missing directories gracefully?

## Common Mistakes

- Putting the `hooks` handler array directly under the event instead of inside a matcher group
- Using matchers on events that don't support them (Stop, UserPromptSubmit, TeammateIdle, TaskCompleted, WorktreeCreate, WorktreeRemove)
- Using prompt/agent handler types on events that only support command (SessionStart, SubagentStart, TeammateIdle, etc.)
- Forgetting `mkdir -p` before writing to log files
- Using `-newer` instead of sort-by-mtime for finding recent files
- Not quoting shell variables containing paths
