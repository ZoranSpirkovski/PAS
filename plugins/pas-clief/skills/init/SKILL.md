---
name: init
description: Use when scaffolding a new pas-clief workspace. Brainstorms with the user about what they're building (or what they want to figure out), then writes a tailored `CLAUDE.md` and minimum-viable structure. The deliverable is shared understanding — by the end of the conversation, the LLM understands what the user wants and the workspace reflects it.
---

# pas-clief:init

Goal: a brand-new workspace where the next session opened in this folder responds with awareness of what's going on. Starting matters more than starting perfectly, but the first impression matters.

## Flow

### 1. Confirm the workspace folder

Verify the cwd is the intended workspace root (where `CLAUDE.md`, `library/`, `workspace/`, and `.claude/skills/` will live). Ask the user to confirm. If a `CLAUDE.md` already exists, refuse to overwrite — offer `pas-clief:upgrade` instead.

### 2. Ask the framing question

> "What are you trying to build with pas-clief?
> (a) I have a use case in mind — let me describe it.
> (b) I'm not sure yet — let's figure it out together."

### 3a. Branch (a) — clear use case

Walk through:
1. Workspace name (free text).
2. The first kind of work this workspace does. Phrase it as a task: e.g., "draft a weekly newsletter," "respond to support tickets," "review pull requests."
3. The agents involved. Start with one if possible. Pick from the plugin library (`library/agents/writer` is included as a starter) or sketch a new local agent.
4. The skills the agent uses. Pick from plugin library (`library/skills/web-research`, `library/skills/drafting-style`, `library/skills/polish-prose`) or note new ones to create.
5. The phases of the process. Three to five typical.
6. Naming conventions the user already uses for files.

As the conversation produces clarity, draft the `CLAUDE.md` content in your head. Show the user the routing table once before writing it.

### 3b. Branch (b) — unclear

Open-ended brainstorm. Ask, in order:
1. What kinds of work recur in your life or job?
2. Which of those would benefit from a repeatable process?
3. Who or what currently does each piece — you, a tool, a person, a habit?
4. What does "done well" look like for that work?
5. Is there one of these we can start with today?

When a candidate process emerges, switch to branch (a) for that one. The user can stop with whatever they have.

### 4. Scaffold

Read the template at `plugins/pas-clief/templates/user-claude-md.md`. Substitute placeholders with the conversation's results:

- `{{workspace_name}}` — the workspace name.
- `{{one_to_three_line_identity}}` — what this workspace is.
- `{{routing_rows}}` — one row per task identified, columns `Task | Go to | Read | Skills`.

Write to `<cwd>/CLAUDE.md`.

Create directories:

```
mkdir -p library/agents library/skills .claude/skills workspace
```

Write `workspace/CLAUDE.md` from `plugins/pas-clief/templates/workspace-claude-md.md` (no substitutions needed for this file).

If the user has reference material (links, examples), write `REFERENCES.md` from `plugins/pas-clief/templates/user-references-md.md`. Otherwise skip.

If the user named a first process during the conversation, immediately invoke `pas-clief:add-process` to create it. Pass the agreed-upon name and structure.

### 5. Close

Tell the user:

> "You have what you need to begin. Open this folder in a fresh `claude` session to feel the difference — your routing table is now part of every prompt. When a new kind of work shows up, run `/pas-clief:add-process`. Improvements are normal — the workspace evolves with you."

## Anti-patterns

- Do not scaffold without conversation. Generic placeholder content defeats the purpose.
- Do not refuse to start. The user's "I don't know" branch is a real branch.
- Do not write hooks, status files, or any script. Pas-clief is convention all the way down.
