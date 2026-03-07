# Design: `creating-hooks` Orchestrator Skill

**Date:** 2026-03-07
**Status:** Approved

## Problem

PAS has had recurring structural errors when creating hooks — wrong `hooks.json` schema, incorrect nesting of matcher groups and handler arrays. There is no dedicated skill for hook creation. The orchestrator has skills for creating processes, agents, skills, and applying feedback, but hooks are created ad-hoc without guidance.

Additionally, the PAS feedback infrastructure hooks (`check-self-eval.sh`, `route-feedback.sh`) need improvements identified in [issue #3](https://github.com/ZoranSpirkovski/PAS/issues/3) and the P1/P2 specs from Claude Code hook changelog analysis.

## Position in PAS Hierarchy

`creating-hooks` is a **5th orchestrator skill** at `processes/pas/agents/orchestrator/skills/creating-hooks/`, parallel to:

- `creating-processes`
- `creating-agents`
- `creating-skills`
- `applying-feedback`

It is invoked by:

- **`creating-processes`** — as a new step when a process needs lifecycle hooks
- **Standalone** — when adding hooks to an existing process or plugin
- **PAS router** — when user intent is hook-related

## Directory Structure

```
creating-hooks/
  SKILL.md                              # Workflow orchestration
  references/
    hooks-schema.md                     # JSON structures for hooks.json, settings, and frontmatter
    event-catalog.md                    # All 19 events, matchers, input/output schemas, handler types
    script-patterns.md                  # Shell script boilerplate, stdin, exit codes, JSON output
    pas-feedback-hooks.md               # PAS-specific feedback hook patterns (check-self-eval, route-feedback)
  feedback/
    backlog/
      .gitkeep
  changelog.md
```

## SKILL.md Workflow

### 1. Determine Purpose

- What lifecycle behavior needs automation?
- Classification: **guard** (block bad actions), **observer** (log/notify), or **reactor** (take action after something happens)?
- Which artifact is this hook for — a plugin (`hooks/hooks.json`), a project (`.claude/settings.json`), or a component (skill/agent frontmatter)?

### 1a. PAS Feedback Hook Setup (when applicable)

- Check `pas-config.yaml` for `feedback: enabled`
- Generate `check-self-eval.sh` (SubagentStop) — verifies agents wrote self-evaluation
- Generate `route-feedback.sh` (Stop) — routes feedback signals to artifact backlogs
- Register hooks in the correct location — per issue #3, plugin `hooks/hooks.json` alone may not fire; hooks also need to be in project `.claude/settings.json` or global `~/.claude/settings.json` until the plugin system supports native hook discovery
- Scripts incorporate issue #3 fixes: `mkdir -p` before warning log writes, sort-by-mtime instead of `-newer`

### 2. Select Event & Handler Type

- Read `references/event-catalog.md`
- Match purpose to the right event using the decision matrix
- Determine if a matcher is needed (and whether the event supports matchers)
- Choose handler type based on whether the decision needs judgment (prompt/agent) or is deterministic (command/http)

### 3. Determine Hook Location

- Plugin hooks: `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` for script paths
- Project hooks: `.claude/settings.json` using `$CLAUDE_PROJECT_DIR` for script paths
- Component hooks: skill/agent YAML frontmatter (scoped to component lifecycle)
- Global hooks: `~/.claude/settings.json` (use sparingly, scripts must guard against non-applicable repos)

### 4. Write Hook Configuration

- Read `references/hooks-schema.md`
- Generate structurally correct JSON with the exact nesting: event → matcher group array → hooks handler array
- The schema reference encodes the nesting rules that have caused structural errors

### 5. Write Hook Scripts (if command type)

- Read `references/script-patterns.md`
- Generate shell scripts following correct patterns:
  - `set -euo pipefail`
  - Read JSON from stdin with `INPUT=$(cat)`
  - Parse with `jq` or `grep`/`sed` for jq-free environments
  - Correct exit code semantics (0 = allow, 2 = block, other = non-blocking error)
  - JSON output format for structured control
- Security: quote variables, validate paths, use absolute paths

### 6. Validate

- Verify JSON structure matches the schema (correct nesting depth, required fields)
- Verify event/matcher combinations are valid (e.g., Stop, UserPromptSubmit, TeammateIdle, TaskCompleted, WorktreeCreate, WorktreeRemove don't support matchers)
- Verify handler types are supported for the chosen event (SessionStart, SubagentStart, TeammateIdle, etc. only support `type: "command"`)
- Verify scripts are marked executable (`chmod +x`)
- Verify path references (`${CLAUDE_PLUGIN_ROOT}` vs `$CLAUDE_PROJECT_DIR`) match the hook location

## Reference Files

### `references/hooks-schema.md`

Encodes the correct JSON structures for all three hook locations:

- **Plugin `hooks/hooks.json`**: top-level `description` (optional) + `hooks` object
- **Settings files**: `hooks` object within settings JSON
- **Skill/agent frontmatter**: `hooks` key in YAML frontmatter

For each: the exact nesting pattern (event → matcher group array → hooks handler array), all four handler types with their required and optional fields, and the common fields (`type`, `timeout`, `statusMessage`, `once`).

Includes agent-level hook declarations (P2): agents can declare hooks in YAML frontmatter for defense-in-depth alongside plugin-level hooks. Guidance on when to use agent-level vs plugin-level hooks.

### `references/event-catalog.md`

All 19 hook events with:

- When the event fires
- Matcher support and values
- Handler type support (command/http/prompt/agent)
- Input schema (common fields + event-specific fields)
- Decision control options
- Exit code 2 behavior (can block vs informational)

Decision matrix for event selection based on purpose.

### `references/script-patterns.md`

Correct shell script patterns including:

- Standard boilerplate (shebang, `set -euo pipefail`, stdin reading)
- Extracting fields from JSON input (`jq` and jq-free approaches)
- Exit code semantics per event type
- JSON output patterns (decision control, `hookSpecificOutput`, `additionalContext`)
- Enhanced patterns using `agent_id`, `agent_transcript_path`, `last_assistant_message` (P1)
- Transcript scanning for signal patterns as secondary detection
- Security best practices (quote variables, absolute paths, avoid `.env`/`.git/`)
- `${CLAUDE_PLUGIN_ROOT}` and `$CLAUDE_PROJECT_DIR` usage

### `references/pas-feedback-hooks.md`

The standard PAS feedback hook patterns:

- **`check-self-eval.sh`** (SubagentStop): enhanced version that extracts `agent_id` for identifying which agent skipped self-eval, checks `agent_transcript_path` for inline signal patterns as secondary detection, keeps file-count check as fallback, uses sort-by-mtime instead of `-newer`
- **`route-feedback.sh`** (Stop): enhanced version that extracts `last_assistant_message` and parses it for signal blocks alongside the existing `.md` file parsing, includes `mkdir -p` fix from issue #3
- When to set up feedback hooks (feedback enabled in `pas-config.yaml`)
- Hook registration location guidance per issue #3 findings
- Known pitfalls and their fixes

## Integration Points

### PAS Router (`skills/pas/SKILL.md`)

Add routing rule:

- **Creating hooks** (hook, lifecycle automation, guard, when something happens): read `creating-hooks/SKILL.md`

### `creating-processes` Skill

Add new step after agent creation:

- **Step 8.5: Determine Hooks** — Does this process need lifecycle hooks? If feedback is enabled, invoke `creating-hooks` for PAS feedback infrastructure. If the process has specific lifecycle needs (validation, notification, cleanup), invoke `creating-hooks` for those.

### Orchestrator (`agent.md`)

Add `creating-hooks/SKILL.md` to the skills list.

## Structural Convention

All orchestrator skills now have `references/` directories (added as part of this design). The standard skill directory structure is:

```
{skill-name}/
  SKILL.md
  references/          # Deep knowledge, read on demand
    .gitkeep           # or actual reference files
  feedback/
    backlog/
      .gitkeep
  changelog.md
```
