---
name: add-process
description: Use when creating a local process for a pas-clief workspace — a recipe that composes agents, skills, and phases into a slash-invokable workflow. The process lands in `.claude/skills/<name>/` so it becomes invocable as `/<name>`.
---

# pas-clief:add-process

Goal: a new local process at `<user-project>/.claude/skills/<name>/` that the user can run as `/<name>`.

## Flow

### 1. Name and goal

Ask:
- "What is the process's name? (Short, lowercase, hyphenated. Example: `newsletter`, `triage-tickets`, `weekly-review`.)"
- "In one line, what does this process do? (This becomes the slash command's description; specificity matters.)"
- "Describe the goal in a paragraph: what does the user get when this process is done?"

### 2. Composition

Ask:
- "Which agents does this process use? You can pick from `library/agents/` (this project) or `plugins/pas-clief/library/agents/` (the plugin). For new agents we'll invoke `pas-clief:add-agent` after this."
- "Which skills are needed beyond what each agent already declares?"
- "Are there sub-processes — other processes this one calls? (Optional.)"

### 3. Phases

Ask:
- "Walk me through the phases. Three to five is typical. For each phase: name, which agent (or sub-process), what the phase produces."

### 4. Write the files

Create directory: `.claude/skills/<name>/phases/`
Create directory: `.claude/skills/<name>/feedback/` (empty)

Read template `plugins/pas-clief/templates/process-skill-md.md`. Substitute:
- `{{process_name}}`, `{{one_line_what_this_does}}`, `{{goal_paragraph}}`
- `{{agents_list}}` — YAML list, one `- <name>` per agent
- `{{skills_list}}` — YAML list, one `- <name>` per skill
- `{{sub_processes_list_or_empty}}` — YAML list, or `[]`
- `{{phase_files_list}}` — YAML list of phase filenames in order
- `{{authoring_notes}}` — any extra notes

Write to `.claude/skills/<name>/SKILL.md`.

For each phase, read template `plugins/pas-clief/templates/process-phase-md.md`. Substitute:
- `{{NN}}` — two-digit phase number (`01`, `02`, ...)
- `{{phase_name}}`, `{{agent_or_sub_process_name}}`, `{{inputs_list}}`, `{{outputs_list_with_paths}}`, `{{detailed_instructions}}`, `{{eval_criteria_list}}`

Write each phase to `.claude/skills/<name>/phases/NN-<slug>.md`.

Read template `plugins/pas-clief/templates/changelog-md.md` and write to `.claude/skills/<name>/changelog.md` with an initial entry.

### 5. Update the routing table

Open `<cwd>/CLAUDE.md`, find the routing table, append a row:

```
| <task description> | /<name> |  |  |
```

### 6. Close

Tell the user:

> "Process `<name>` is ready at `.claude/skills/<name>/`. You can invoke it as `/<name>` from anywhere in this workspace. The routing table now lists it. Run a test session when you're ready — the orchestrator will create `workspace/<name>/<session-id>/` automatically."

If any agents or skills the user named don't exist yet, follow up with the relevant scaffolding skill.

## Anti-patterns

- Don't draft phases without knowing what each phase produces. "Phase 2: thinking" is not a phase; "Phase 2: outline draft → outline.md" is.
- Don't reference agents that don't exist. Either scaffold them first or note them as a follow-up.
- Don't put a process in `library/processes/` — pas-clief processes live in `.claude/skills/` (user) or `plugins/pas-clief/skills/` (plugin) so they're slash-invokable. The library is for components only.
