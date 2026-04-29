---
name: add-agent
description: Use when creating a local agent for a pas-clief workspace. Walks the user through naming the agent, defining its role, listing its skills, and writing CLAUDE.md and CONTEXT.md from templates. The agent lands in `library/agents/<name>/`.
---

# pas-clief:add-agent

Goal: a new local agent in `<user-project>/library/agents/<name>/` that mirrors the shape of plugin library agents.

## Flow

### 1. Name and role

Ask:
- "What is the agent's name? (Short, lowercase, hyphenated. Example: `writer`, `code-reviewer`, `support-responder`.)"
- "In one line, what is this agent's role?"
- "What kind of work does it do? Describe it in 2–3 sentences."

If the user picks a name that already exists at `library/agents/<name>/` (local) or in the plugin library, ask:
- "An agent named `<name>` already exists. Replace, extend (shadow), or rename?"

### 2. Responsibilities

Ask:
- "What is this agent responsible for? List 2–5 bullets."

### 3. Skills

Ask:
- "Which skills does this agent use? You can pick from `library/skills/` (this project) or `plugins/pas-clief/library/skills/` (the plugin). You can also list new skills to create afterwards."

If a named skill doesn't exist anywhere, note it and offer to invoke `pas-clief:add-skill` after this.

### 4. Workspace context

Ask:
- "What files does this agent typically work with?"
- "What should it avoid? Anti-patterns, common mistakes, naming traps."

### 5. Write the files

Create directory: `library/agents/<name>/`
Read template `plugins/pas-clief/templates/agent-claude-md.md` and substitute placeholders. Write to `library/agents/<name>/CLAUDE.md`.
Read template `plugins/pas-clief/templates/agent-context-md.md` and substitute placeholders. Write to `library/agents/<name>/CONTEXT.md`.
Read template `plugins/pas-clief/templates/changelog-md.md` and write to `library/agents/<name>/changelog.md` with an initial entry: `## 2026-04-29\n\n- Created agent.`
Create directory: `library/agents/<name>/feedback/` (empty).

### 6. Close

Tell the user:

> "Agent `<name>` is ready at `library/agents/<name>/`. Reference it in process recipes by name (search-order resolves to your local version automatically). Use `pas-clief:add-skill` if any of its skills don't exist yet."

If the user named skills that don't exist, follow up: "Want me to scaffold those skills now?"

## Anti-patterns

- Don't write the agent without a real conversation about what it does. Templates with placeholder text defeat the purpose.
- Don't use vague descriptions. The agent's role description is what the orchestrator reads when it spawns this agent — specificity matters.
