---
name: {{process_name}}
description: {{one_line_what_this_does}}
agents:
{{agents_list}}
skills:
{{skills_list}}
sub_processes:
{{sub_processes_list_or_empty}}
phases:
{{phase_files_list}}
---

# {{process_name}}

## Goal

{{goal_paragraph}}

## How this process runs

When the orchestrator (you) is invoked via `/{{process_name}}`:

1. Create a session workspace at `workspace/{{process_name}}/<session-id>/` and initialize `STATUS.md`.
2. Walk the phases in order. For each phase:
   - Read the phase file in `phases/`.
   - Spawn the agent named in the phase (or invoke the sub-process) using the spawn pattern below.
   - Update `STATUS.md` with the phase transition.
   - `TaskCreate` a self-eval task for this phase. Clear it by writing the eval to `feedback/`.
3. When all phases are complete, mark `STATUS.md` complete and summarize for the user.

## Spawn pattern (agent)

```
Read your role at library/agents/<agent>/CLAUDE.md and your context at library/agents/<agent>/CONTEXT.md. Skills available: <list>. Task for this phase: <content from phases/NN-name.md>. Write output to workspace/{{process_name}}/<session>/outputs/<NN-name>.<ext>. Append progress to workspace/{{process_name}}/<session>/notes.md.
```

## Spawn pattern (sub-process)

```
You are running the process at <library or skills path>/<sub>/SKILL.md. Read the recipe and execute its phases as a sub-process; report back when done.
```

## Notes

{{authoring_notes}}
