---
name: newsletter
description: Use when drafting and publishing a newsletter issue. Walks research → draft → publish phases, using the writer agent. Example library process for pas-clief — copy or extend it for your own use.
agents:
  - writer
skills:
  - web-research
  - drafting-style
  - polish-prose
sub_processes: []
phases:
  - 01-research.md
  - 02-draft.md
  - 03-publish.md
---

# newsletter

## Goal

Produce a publish-ready newsletter issue from a topic. The deliverable is a markdown file at `workspace/newsletter/<session>/outputs/03-final.md` plus a session log.

## How this process runs

When invoked via `/pas-clief:newsletter`:

1. Ask the user for the topic, target length, and desired tone (or read from a brief if one was provided).
2. Create `workspace/newsletter/<session-id>/` and initialize `STATUS.md` with `phase: 01-research`.
3. Walk the phases in order:
   - **Phase 01 (research):** spawn the `writer` agent. Pass the brief; instruct it to use `web-research` to gather sources. Output: `outputs/01-sources.md`. Update `STATUS.md`.
   - **Phase 02 (draft):** spawn the `writer` agent. Hand it `01-sources.md`. Instruct it to draft, then apply `drafting-style`, then `polish-prose`. Output: `outputs/02-polished-draft.md`. Update `STATUS.md`.
   - **Phase 03 (publish):** ask the user to review `02-polished-draft.md`. Once approved, copy to `outputs/03-final.md` and surface for the user's chosen channel.
4. After each phase, `TaskCreate` a self-eval task ("Self-eval: Phase NN of newsletter session <id>"). Clear it by writing the eval to `feedback/YYYY-MM-DD-self-eval-phase-NN.md`.
5. When all phases complete, mark `STATUS.md` complete and summarize for the user.

## Spawn pattern (writer)

```
Read your role at library/agents/writer/CLAUDE.md and your context at library/agents/writer/CONTEXT.md. Skills available: web-research, drafting-style, polish-prose. Task for this phase: <content from phases/NN-name.md>. Write output to workspace/newsletter/<session>/outputs/<NN-name>.md. Append progress to workspace/newsletter/<session>/notes.md.
```

## Notes

- This is an example process. Customize phases, agents, and skills for your own newsletter workflow. Run `/pas-clief:add-process` to create your own version locally — your local version will shadow this plugin process via search order.
