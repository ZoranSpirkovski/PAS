# pas-clief — design spec

- **date:** 2026-04-29
- **status:** draft (awaiting user review)
- **author:** brainstormed with Zoran in session fd32f6a2
- **scope:** what pas-clief *is*. Implementation plan follows separately via the writing-plans skill.

## 1. What pas-clief is

pas-clief is a script-free reimplementation of the PAS pattern (process / agent / skill) using Jake Van Clief's folder-as-workspace method. It produces a personal workspace — no marketplace concept, no hooks, no enforcement, no `status.yaml`, no bash. The LLM understands what the user is doing because the folder structure encodes it.

It ships as a sibling plugin to PAS (`plugins/pas-clief/`) so users can choose the implementation that suits them. PAS-the-original keeps its full lifecycle machinery; pas-clief offers the same thinking model expressed entirely in folders, markdown, and conventions.

## 2. Goals

- Express process / agent / skill entirely as folders, markdown, and naming conventions.
- Use Claude Code's CLAUDE.md auto-loading for shared context — no scripts needed.
- Library + local pattern: canonical reusable items in the plugin; users build their own in the same shape.
- The init flow's deliverable is **clarity** — the LLM understands what the user wants, and the workspace makes a good first impression.

## 3. Non-goals

- Marketplace distribution of user-authored items.
- Mid-session enforcement (lifecycle gates, self-eval gates, completion gates).
- Auto-routing feedback to GitHub.
- Cross-session state machinery beyond plain markdown.

## 4. Architecture

### 4.1 Plugin layout

```
plugins/pas-clief/
  .claude-plugin/plugin.json    plugin manifest
  skills/
    pas-clief/SKILL.md          main entry / intelligent router
    init/SKILL.md               brainstorm + scaffold a fresh user workspace
    add-agent/SKILL.md          create a local agent
    add-skill/SKILL.md          create a local skill
    add-process/SKILL.md        create a local process
    upgrade/SKILL.md            sync conventions from a newer plugin version
    visualize/SKILL.md          render a process flow as markdown/HTML
    <process-name>/SKILL.md     a library process (slash-invokable)
  library/
    agents/<name>/
      CLAUDE.md                 role, responsibilities, skills referenced
      CONTEXT.md                workspace context for this agent
      changelog.md
      feedback/                 plain markdown drops
    skills/<name>/
      SKILL.md                  capability, called by agents and processes
      changelog.md
      feedback/
```

### 4.2 User project layout (after `/pas-clief:init`)

```
<user-project>/
  CLAUDE.md                     shared map: identity, routing table, naming conventions, isolation rule, feedback rule
  REFERENCES.md                 optional shared background (links, examples, brand voice)
  library/
    agents/<name>/
      CLAUDE.md, CONTEXT.md, changelog.md, feedback/
    skills/<name>/
      SKILL.md, changelog.md, feedback/
  .claude/skills/<process>/
    SKILL.md                    user-authored process, slash-invokable as /<name>
    phases/NN-<step>.md         ordered phase instructions
    changelog.md
    feedback/
  workspace/
    CLAUDE.md                   focused inventory of the workspace folder
    <process-name>/
      <session-id>/
        STATUS.md               current phase, history of transitions
        notes.md                free-form session log
        outputs/                phase outputs from agents
```

Symmetric: plugin and user both expose processes via skill discovery and keep components in `library/{agents,skills}/`. Plugin processes resolve as `/pas-clief:<name>`; user processes as `/<name>`.

## 5. Layered context loading

| Layer | What's in it | How it loads | When |
|---|---|---|---|
| `~/.claude/CLAUDE.md` | User's global preferences | Auto, by Claude Code | Always |
| `<project>/CLAUDE.md` (or `.claude/CLAUDE.md`) | Shared map: routing, naming, isolation, feedback | Auto, by Claude Code | Always (orchestrator + every spawned agent) |
| `library/<kind>/<name>/CLAUDE.md` or `SKILL.md` + `CONTEXT.md` | Agent role / skill capability | Explicit Read on first turn | When agent is spawned or skill is invoked |
| `.claude/skills/<process>/SKILL.md` | Process recipe + orchestration prose | Auto when slash-invoked; explicit Read when sub-invoked | On user invocation or sub-process call |
| `workspace/<process>/<session>/{STATUS.md,notes.md}` | Live session state | Explicit Read by orchestrator | When a session continues |

**Empirical finding from session fd32f6a2:** Claude Code does *not* walk CLAUDE.md upward from the cwd of a subagent or teammate — only the home and project-root CLAUDE.md files inject. Therefore agent-specific instructions cannot rely on cwd-based auto-loading mid-session and must be picked up by explicit Read. A fresh `claude` session started inside an agent folder *does* pick up that folder's CLAUDE.md at session start, which is the documented escape hatch for deep agent work.

## 6. Routing table

Lives in root `CLAUDE.md`. Four columns, pocket-clief style:

```
| Task                          | Go to                       | Read              | Skills           |
|-------------------------------|-----------------------------|-------------------|------------------|
| Draft a Monday newsletter     | /newsletter                 |                   |                  |
| Write a research summary      | library/agents/researcher/  | sources.md        | web-research     |
| Quick edit on existing draft  | (here)                      | drafts/_v2.md     | polish-prose     |
```

For process rows, `Read` and `Skills` are typically empty — the process declares its own deps. For ad-hoc agent rows, `Read` and `Skills` are populated with what the user wants pre-loaded for that session. `(here)` means the orchestrator handles directly.

## 7. Process recipes

A process lives at `library/processes/<name>/SKILL.md` (plugin) or `.claude/skills/<name>/SKILL.md` (user). Frontmatter declares dependencies:

```yaml
---
name: newsletter
description: Draft and publish a weekly newsletter
agents:
  - writer
skills:
  - drafting-style
  - polish-prose
sub_processes:
  - fact-check
phases:
  - 01-research.md
  - 02-draft.md
  - 03-fact-check.md
  - 04-publish.md
---
```

The body of `SKILL.md` is orchestration prose — what to do at each phase, how to use the agents and skills, when to advance. Phase files in `phases/` carry the per-phase detail.

## 8. Path resolution

Plain names in frontmatter; resolver searches in this order:

1. `<user-project>/library/<kind>/<name>/`
2. `<plugin>/library/<kind>/<name>/`

First match wins. To force the plugin version when the user has a local-shadowed item, prefix explicitly: `plugin:writer`. To force a local item by name (rare), `local:writer` is also accepted but redundant.

This mirrors Python's import precedence: local shadows plugin, explicit prefix is the escape hatch.

## 9. Spawn mechanism

Subagents and teammates inherit cwd from the orchestrator but do *not* auto-load CLAUDE.md from that cwd. Therefore:

- **Default (A):** Orchestrator spawns the agent via `Agent` tool with a prompt that includes a Read instruction:
  > "Your role is defined in `<path>/CLAUDE.md`. Your context is `<path>/CONTEXT.md`. Your task is `<phase-content>`. Read the role and context files now, then perform the task. Skills available: `<list>`."
  
  The agent uses Read once to absorb its role; subsequent turns operate from that context.

- **Escape hatch (C):** For long-running, deep, or interactive agent work, the orchestrator instructs the user (or the user explicitly chooses) to open a fresh `claude` session inside the agent's folder. Claude Code's session-start CLAUDE.md walk picks up the agent's CLAUDE.md naturally. Use sparingly — it sacrifices orchestrator autonomy and parallelism.

Routing-table rows can be marked `session-required` to indicate the C path is appropriate for that task.

## 10. Lifecycle

- Phases live as ordered files in the process folder: `phases/01-discovery.md`, `02-planning.md`, etc. Adding a phase = adding a file. Renaming is visible in git.
- Status of an active session lives in `workspace/<process>/<session-id>/STATUS.md`. The orchestrator updates it on phase transitions:

  ```markdown
  # newsletter session 2026-04-29-001

  - phase: 02-draft
  - started: 2026-04-29T10:30:00Z
  - history:
    - 01-research → completed 2026-04-29T10:25:00Z
  - notes: see notes.md
  ```

- No `status.yaml`. No hook gates. No enforcement. Discipline is encoded in process CLAUDE.md instructions ("at end of each phase, update STATUS.md and TaskCreate self-eval task").

## 11. Feedback

- Per-artifact `feedback/` folders. Files use the convention `YYYY-MM-DD-<source>-<topic>.md`. Anyone (orchestrator, agent, user) can drop a file. Triage is manual: the user reads the folder.
- **Self-evaluation as tasks.** Process CLAUDE.md instructs the orchestrator to `TaskCreate` self-eval tasks at phase boundaries (e.g., "Self-eval: Phase 2 draft quality"). Tasks sit in Claude Code's task list as reminders. The orchestrator clears them by writing the eval to the artifact's `feedback/` folder.
- No GitHub routing. No hooks. If feedback warrants becoming a GitHub issue, the user (or the orchestrator on the user's instruction) files it manually via `gh`.

## 12. Sub-processes

A sub-process is "an agent whose job is to run another process." Mechanism is identical to spawning an agent — the difference is only the bootstrap prompt:

- Agent spawn: *"Your role is defined in `library/agents/writer/CLAUDE.md`. Read it and do the task."*
- Sub-process spawn: *"You are running the process at `library/processes/fact-check/SKILL.md`. Read the recipe, execute its phases as a sub-process, and report back when done."*

Same `Agent` tool, same path resolution, same return mechanism. Frontmatter declares `sub_processes:` alongside `agents:`. Nested orchestration falls out for free.

Cost: each sub-process invocation re-reads its recipe. Mitigate by keeping sub-processes scoped tight.

## 13. Skill shape: `/pas-clief` and shortcuts

Hybrid (option C from brainstorming):

- **`/pas-clief`** — main entry, intelligent router. The user describes intent ("I want to add a new process"); the skill routes to the right shortcut.
- **Shortcuts** for the common operations (one slash command each):
  - `/pas-clief:init` — brainstorm and scaffold a fresh workspace.
  - `/pas-clief:add-agent` — create a local agent.
  - `/pas-clief:add-skill` — create a local skill.
  - `/pas-clief:add-process` — create a local process.
  - `/pas-clief:upgrade` — sync conventions from a newer plugin version.
  - `/pas-clief:visualize` — render a process flow.
  - `/pas-clief:<process-name>` — invoke a library process directly.

User-authored processes get their own slash command (`/<name>`) automatically, since they live at `.claude/skills/<name>/SKILL.md` and Claude Code discovers them.

## 14. Init flow

`/pas-clief:init` is a brainstorming skill in miniature. Its deliverable is **clarity**: by the end of the conversation, the LLM understands what the user wants, and the root CLAUDE.md plus any seed CONTEXT.md files reflect that understanding specifically (not as generic placeholders).

Flow:

1. Open with: *"What are you trying to build with pas-clief? (a) I have a use case in mind. (b) I'm not sure yet — let's figure it out together."*
2. **Branch (a):** Walk through naming the workspace, the first process or two, picking from library agents, drafting the recipe. Write tailored CLAUDE.md and CONTEXT.md content.
3. **Branch (b):** Brainstorm — what tasks recur, who/what does them, what good looks like. As clarity emerges, surface a candidate process. The user can stop at any point with whatever they have. The conversation itself is the deliverable; structure follows.
4. **Either way, minimum on-disk:** root `CLAUDE.md` (with empty-or-seeded routing table), `library/{agents,skills}/`, `workspace/`, `REFERENCES.md` (omitted unless the user has material). Optionally: a first process and one or two agents.
5. Close with: *"You have what you need to begin. When a new kind of work shows up, run `/pas-clief:add-process`. Improvements are normal — the workspace evolves with you."*

The teaching: starting matters more than starting perfectly, but the first impression matters because it sets the LLM's expectations of you and you of it.

## 15. Worked example: newsletter

User runs `/newsletter` (their local process):

1. Claude Code loads `<user-project>/.claude/skills/newsletter/SKILL.md`.
2. Frontmatter declares: `agents: [writer]`, `skills: [drafting-style, polish-prose]`, `phases: [01-research.md, 02-draft.md, 03-publish.md]`.
3. Orchestrator (current session) reads the recipe, creates `workspace/newsletter/2026-04-29-001/STATUS.md`, marks phase 01 in progress.
4. Phase 01 (research):
   - Orchestrator reads `phases/01-research.md`.
   - Spawns subagent `writer` via `Agent` tool. Prompt: *"Read `library/agents/writer/CLAUDE.md` and `library/agents/writer/CONTEXT.md` for your role. Skills available: `web-research` (Read it from `library/skills/web-research/SKILL.md`). Task: gather sources for this week's topic (X). Write findings to `workspace/newsletter/2026-04-29-001/outputs/01-research.md`."*
   - Writer returns with the findings file written.
   - Orchestrator updates STATUS.md, advances to phase 02.
5. Phase 02 (draft) — same pattern, writer spawned with phase-02 task.
6. Phase 03 (publish) — same pattern, possibly with a different agent or sub-process for the publish step.
7. At each phase boundary the orchestrator `TaskCreate`s a self-eval task and writes the eval to `workspace/newsletter/2026-04-29-001/feedback/` when done.
8. Final: STATUS.md marked complete, all outputs in `outputs/`, eval in `feedback/`.

## 16. Open questions / deferred

- **Concurrency.** Can phases of one process run in parallel? Recipe says no (phases are ordered) but inside a phase, can multiple agents run concurrently via teammates? Likely yes; documented when needed.
- **Versioning of library items.** Each item has `changelog.md`. No formal version field yet. If users fork an old library agent, they may diverge silently. Punt to a future cycle.
- **Visualize.** A `/pas-clief:visualize` skill is listed but its output format isn't specified yet — likely markdown flowchart of phases + agents. Define when first implemented.
- **Cross-process feedback aggregation.** Currently each artifact's `feedback/` is local. A "harvest" workflow that summarizes open feedback across all artifacts could be a future shortcut.
- **Library updates.** When the plugin's library evolves, users running off `local:` items don't get changes. A `/pas-clief:upgrade` skill is in scope but its diff/merge story isn't designed yet.

## 17. Self-review notes

Reviewed for placeholders / contradictions / scope / ambiguity 2026-04-29:

- **Placeholders:** none. All sections concrete.
- **Internal consistency:** routing table rows for processes use slash commands; rows for agents/ad-hoc use folder paths — consistent with section 9. Path resolution (section 8) and spawn mechanism (section 9) align.
- **Scope:** focused on a single implementation plan. No subsystem decomposition needed.
- **Ambiguity:** "explicit Read" in section 9 is not a tool name — it means the orchestrator instructs the agent to use the `Read` tool on its CLAUDE.md/CONTEXT.md. Clarified inline.

## 18. Open decisions for the user before implementation

(None blocking. Spec is complete. Items in section 16 are deferrable; implementation can proceed.)
