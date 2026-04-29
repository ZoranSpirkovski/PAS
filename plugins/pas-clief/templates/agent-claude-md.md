---
name: {{agent_name}}
description: {{one_line_role}}
skills:
{{skill_list_or_empty}}
---

# {{agent_name}}

## Role

{{role_paragraph}}

## Responsibilities

{{responsibilities_list}}

## Skills available

{{skills_explanation}}

## How to operate

When you are spawned as this agent:
1. Read your `CONTEXT.md` for the workspace details specific to this agent.
2. Read any phase-specific instructions handed to you by the orchestrator.
3. Use the skills listed above; read each skill's `SKILL.md` if you need its full procedure.
4. Write your output to the path the orchestrator names (typically `workspace/<process>/<session>/outputs/`).
5. Append a brief progress note to `workspace/<process>/<session>/notes.md` so the orchestrator can pick up where you left off.
