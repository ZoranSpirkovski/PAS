---
name: creating-processes
description: Use when creating a new PAS process from a user's goal description. Invoked by the PAS router, not directly by users.
---

# Creating Processes

Create a complete process definition from a user's goal. A process defines WHAT needs to happen, in WHAT ORDER, to achieve a specific GOAL. It assigns work to agents, defines phase gates, and manages flow.

## Execution Framing

This skill IS the execution framework. When generating plans for process creation:

- Do NOT produce a standalone task list. Every step is a step within THIS skill's workflow.
- If you are in plan mode, exit plan mode first — this skill requires interactive brainstorming with the user via AskUserQuestion, which plan mode prevents.
- If a step requires work not covered by this skill, flag it as a PAS gap rather than a standalone manual step.

## Workflow

### 1. Clarify the Goal

Apply the crystal clarity principle. Never assume you understand what the user wants.

- Ask one question at a time, brainstorming-style
- Probe for: scope, quality expectations, input format, output format, audience
- Continue until you can state the goal back in a single sentence the user confirms
- If the goal maps to an existing process, suggest modifying it instead of creating new

### 2. Prepare Reference Material (if applicable)

If the process requires domain knowledge from raw source material (transcripts, documentation, course content):

1. Create `processes/{name}/reference/` directory
2. Store the original source material in `reference/source/` — this is the authoritative knowledge base
3. Analyze the source material to determine the best reference format:
   - If already well-structured: use directly, no distillation needed
   - If raw/unstructured (e.g., transcripts): distill into a structured methodology doc alongside the source
   - Match the format and depth to the material — do not impose arbitrary length limits
4. Any distilled reference supplements the source material — it does not replace it
5. Skills must trace techniques back to the source. When a reference doc is insufficient, agents consult the original source material directly.

Skip this step if the process is based on general knowledge or user-provided specifications.

### 3. Design Phases

Break the goal into sequential phases. For each phase define:

- **Input**: what files/data this phase needs (from user or previous phases)
- **Output**: what files/data this phase produces
- **Gate**: what review point exists (user approval, orchestrator check, or none)

**Parallelism**: infer from I/O dependencies. Phases sharing the same input but not depending on each other can run in parallel. Phases listing another phase's output as input must wait. No explicit `depends_on` needed. Optional `sequential: true` at process level to force linear.

### 4. Determine Agents

Start with the minimum viable set. Every process needs an orchestrator. Add specialist agents only when:

- A phase requires distinct expertise (research vs writing vs verification)
- Quality feedback suggests a specialist would outperform the orchestrator
- The phase is complex enough to warrant a dedicated agent

For simple processes (1-3 phases, similar skills), the orchestrator handles everything (solo pattern).

### 5. Select Orchestration Pattern

Read the orchestration decision matrix. If `library/orchestration/SKILL.md` doesn't exist in the user's project yet, bootstrap it by copying from the PAS plugin's library (the `library/` directory next to `processes/` in the plugin). Then apply the decision matrix:

| Agents | Discussion needed? | Parallel phases? | Pattern |
|--------|-------------------|-------------------|---------|
| 1 | N/A | N/A | solo |
| 2+ | Yes | N/A | discussion |
| 2+ | No | Yes | hub-and-spoke |
| 2+ | No | No | sequential-agents |

Default to hub-and-spoke when unsure.

### 6. Scaffold Process Directory

Create the directory structure:

```
processes/{name}/
  process.md
  agents/
    orchestrator/
    {specialist-1}/
    {specialist-N}/
  modes/
    supervised.md
    autonomous.md
  config/           # Only if process needs configuration files
  reference/        # Only if process needs reference documents
  tools/            # Only if process needs scripts/tools
  feedback/
    backlog/
  changelog.md
```

### 7. Write process.md

Use this exact YAML frontmatter format:

```yaml
---
name: {process-name}
goal: {one-sentence goal}
version: 1.0
orchestration: {pattern}
sequential: false
modes: [supervised, autonomous]

input:
  - {input-name}: {description}

phases:
  {phase-name}:
    agent: {agent-name}
    input: {file or list of files}
    output: {file or list of files}
    gate: {description of review point}

status_file: workspace/{name}/{slug}/status.yaml
---

# {Process Name}

{Brief description of what this process does and why.}

## Phases

{Prose description of each phase, what it does, and how it contributes to the goal.}
```

### 8. Create Agents

For each agent determined in step 4, invoke the creating-agents skill:

- Read `creating-agents/SKILL.md` from the same skills directory as this skill
- Follow its workflow for each agent
- The orchestrator agent is always created first

### 9. Verify Against Source Material

If Step 2 (Prepare Reference Material) was used, cross-check every created skill against the reference doc:

1. For each skill, list every technique, tactic, metric, and number it contains
2. Verify each one exists in the reference material — flag any that don't as potential fabrication
3. Check each section of the reference doc is covered by at least one skill — flag uncovered sections as omissions
4. Remove fabricated content. Add skills or skill sections for omissions.

This is a mandatory step when source material exists. Do not skip it.

### 10. Create Mode Files

Create `modes/supervised.md` and `modes/autonomous.md`:

**Supervised mode format:**
```yaml
---
name: supervised
description: User reviews and approves at every phase gate
gates: enforced
---

## Behavior

- After each phase completes, STOP and present the output to the user
- Do NOT launch the next phase until the user approves
- Present a summary of what was produced, key findings, and any concerns
- If the user requests changes, route them to the appropriate agent

## Gate Protocol

At each gate:
1. Show phase output summary (not raw files unless asked)
2. Flag any quality concerns or red flags
3. Ask: "Approve and continue, or request changes?"
```

**Autonomous mode:** Same structure, but `gates: advisory`. Log gate results but do not pause. Self-review at each gate point. Flag critical issues even in autonomous mode.

### 11. Create Thin Launcher

Create `.claude/skills/{name}/SKILL.md`:

```yaml
---
name: {process-name}
description: {goal description, starts with action verb}
---

Read `processes/{name}/process.md` for the process definition.
Read the orchestration pattern from `library/orchestration/` as specified in the process.
Execute.
```

### 12. Create Integration Test

Create a test scenario in `processes/{name}/evals/` that verifies:

- Process definition is valid YAML
- All referenced agents exist
- All referenced skills exist within their agents
- Phase I/O dependencies form a valid DAG (no cycles)
- Mode files have correct frontmatter
- Thin launcher points to correct process.md
