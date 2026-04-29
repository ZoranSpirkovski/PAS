---
name: pas-clief
description: Use when creating, managing, or running processes, agents, and skills using the script-free folder-as-workspace method. Single entry point for pas-clief — routes to the right shortcut based on user intent.
---

# pas-clief

This is the main entry point for pas-clief. Pas-clief is a script-free implementation of the PAS pattern (process / agent / skill) using Jake Van Clief's folder-as-workspace method. There are no hooks, no scripts, no enforcement — pure markdown discipline.

## How to route

Read the user's intent and route to the appropriate shortcut skill:

- **"set up a workspace" / "I'm starting a project" / "init" / "scaffold"** → invoke `pas-clief:init`. Do not improvise scaffolding.
- **"add an agent" / "create a writer agent"** → invoke `pas-clief:add-agent`.
- **"add a skill" / "create a capability"** → invoke `pas-clief:add-skill`.
- **"add a process" / "new pipeline" / "new workflow"** → invoke `pas-clief:add-process`.
- **"upgrade" / "what's new in pas-clief"** → invoke `pas-clief:upgrade`.
- **"show me this process" / "visualize"** → invoke `pas-clief:visualize`.
- **"run X" / "execute X"** where X is a process → if `<user-project>/.claude/skills/<x>/` or `plugins/pas-clief/skills/<x>/` exists, invoke that slash command directly. The user can also run it themselves: `/<x>`.

If the user's intent is ambiguous, ask one clarifying question. Do not assume.

## Workspace gate

Pas-clief works inside a workspace folder — typically the project root where the user keeps their `library/` and `.claude/skills/` content. Before running a creation or management skill, verify a `CLAUDE.md` exists at the cwd root of this workspace. If not, suggest `pas-clief:init` first.

## What pas-clief is

- Personal workspace, no marketplace concept.
- Library + local pattern: canonical reusable items live in this plugin (`plugins/pas-clief/library/`); users create their own in `<user-project>/library/`. Local shadows plugin via search order.
- Processes are slash-invokable: plugin processes as `/pas-clief:<name>`, user processes as `/<name>`.
- Lifecycle, feedback, and self-eval are pure conventions: phases as ordered files, status in workspace session folders, feedback as plain markdown drops, self-eval as Claude Code tasks.

## Conversation style

- Brainstorming mode: clarify intent before scaffolding.
- One question at a time.
- No PAS jargon unless the user uses it first. Speak in goals and tasks.
