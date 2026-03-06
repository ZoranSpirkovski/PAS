---
name: hub-and-spoke
description: Central orchestrator pattern where all agents communicate through the hub
---

# Hub-and-Spoke Orchestration

The default pattern for multi-agent processes. A central orchestrator reads the process definition, spawns team members, delegates phases, manages gates, and tracks status.

## Startup Sequence

1. **Read process.md** to load the process definition (phases, agents, I/O dependencies, gates)
2. **Read mode file** (`modes/{mode}.md`) to determine gate behavior
3. **Check for existing workspace** at `workspace/{process}/{slug}/status.yaml`
   - If status.yaml exists: resume from last completed phase (see Resumability below)
   - If no status.yaml: create workspace, initialize status.yaml with all phases as `pending`
4. **Load orchestration skills**: read this file for execution rules
5. **When feedback is enabled**: carry `library/self-evaluation/SKILL.md` for shutdown
6. **Spawn team members** via TeamCreate for all specialist agents defined in process.md

## Spawning Team Members

Use TeamCreate for each specialist agent. The spawn prompt tells them:

- Their role: "You are the {name}"
- Where to find their definition: "Read your agent.md at `processes/{process}/agents/{name}/agent.md`"
- Where to find their skills: "Read your skills from the `skills/` directory listed in your agent.md"
- Where to write output: "Write output to `workspace/{process}/{slug}/{output-folder}/`"
- Feedback status: whether self-evaluation is active
- Self-evaluation instructions: "Before returning your final result, if feedback is enabled in `pas-config.yaml`, read `library/self-evaluation/SKILL.md` and write feedback to `workspace/{process}/{slug}/feedback/{your-name}.md`"

Team members persist for the full process lifecycle. They retain work context for richer self-evaluation and can receive downstream feedback from later phases. Idle agents cost zero tokens.

Team members CAN spawn their own ephemeral subagents via the Agent tool for parallelizable subtasks. See Intra-Phase Parallel Dispatch below.

## Agent Communication

Team members spawned via TeamCreate are persistent for the process lifecycle:
- **To communicate with team members**: use `SendMessage` (not Agent tool resume)
- **To request team member shutdown**: use `SendMessage` with shutdown instructions
- **Agent tool resume**: only for ephemeral subagents spawned via the `Agent` tool

Using the wrong mechanism will fail silently (e.g., "No transcript found").

## Parallelism Inference

The orchestrator infers execution order from I/O dependencies in process.md. No explicit `depends_on` fields needed.

**Rules:**
- Phases whose inputs are all available (from user input or completed phases) can run in parallel
- Phases listing another phase's output as input must wait for that phase to complete
- `sequential: true` at process level forces strictly linear execution

**Example inference:**
```yaml
phases:
  sourcing:
    output: research/source-analysis.md
  research:
    input: research/source-analysis.md
    output: research/research-brief.md
  internal-links:
    input: research/source-analysis.md
    output: research/internal-links.md
  writing:
    input: [research/research-brief.md, research/internal-links.md]
```
Result: research and internal-links run in parallel after sourcing. Writing waits for both.

## Intra-Phase Parallel Dispatch

When an agent needs to split work within a single phase across multiple parallel subagents (e.g., fixing 6 skills simultaneously, processing independent documents), use this pattern instead of external dispatch skills.

### When to Use

- 2+ independent tasks within a phase that share no state
- Each task can be scoped to a single clear objective
- Tasks don't require coordination during execution

### Spawn Prompt Requirements

Every subagent spawn prompt MUST include:

1. **Verified file paths**: Before dispatching, confirm all referenced paths exist. Do not propagate paths without verification — a wrong path in the spawn prompt will be replicated across all subagent work.
2. **Specific scope**: One clear objective per agent. "Fix link-building skill" not "fix all skills."
3. **Output location**: Exact path for writing results to `workspace/{process}/{slug}/`
4. **Shutdown protocol**: "When your task is complete: 1) Write your self-evaluation, 2) Return your summary. Do not shut down before completing self-evaluation."
5. **Self-evaluation instructions** (when feedback enabled): "Before returning your final result, read `library/self-evaluation/SKILL.md` and write feedback to `workspace/{process}/{slug}/feedback/{your-name}.md`"

### Feedback Rules

**All agents self-evaluate, regardless of persistence.** No exceptions for:
- Ephemeral subagents ("they're temporary" is not a reason to skip)
- Short-lived tasks ("it was quick" is not a reason to skip)
- Ad-hoc agents spawned outside the original process design

A smooth task with no issues produces "No issues detected." — which is still valuable confirmation.

### Completion Gate

The dispatching agent (orchestrator or team member) must:

1. Wait for ALL subagents to return results AND self-evaluation
2. Do not declare the dispatch complete until every subagent has written feedback
3. Review results for conflicts (did agents edit the same files?)
4. Run verification (tests, cross-checks) after integrating all results

## Status Tracking

Write `workspace/{process}/{slug}/status.yaml` continuously at every state change. Status is a performance log, not just state.

**Valid states:** `pending`, `in_progress`, `completed`. Add process-specific states only when the user requests them.

**Format per phase:**
```yaml
process: {name}
instance: {slug}
started_at: {ISO timestamp}
completed_at: ~
status: in_progress

phases:
  {phase-name}:
    status: completed
    agent: {agent-name}
    started_at: {ISO timestamp}
    completed_at: {ISO timestamp}
    duration_seconds: {number}
    attempts: {number}
    output_files:
      - {path relative to workspace}
    quality:
      score: {1-10}
      notes: "{free text assessment}"
```

Sub-processes write their own status.yaml. Parent references via `subprocess: {path}/status.yaml`.

## Error Handling Chain

1. **Agent self-recovers first**: retries failed steps, works around issues internally
2. **Orchestrator monitors for hangs**: compare elapsed time against historical duration data from status.yaml across instances. Detection accuracy improves over time.
3. **Orchestrator retries once**: spawn a fresh agent if self-recovery fails
4. **Escalate to user**: if retry also fails, present full context and ask for guidance

**Failure scenarios:**
- **Partial output**: quarantine to `partial/` subfolder. Retry starts clean but can reference quarantined output for recovery.
- **Token budget exceeded**: phase/skill too complex, needs splitting. This is a design-time fix via the feedback system.
- **External dependency failure**: agent tries alternatives first, then reports error with workaround suggestions. Collaborate with user.
- **Non-responsive agent**: critical incident. Orchestrator writes feedback on their behalf flagging non-responsiveness as HIGH severity OQI.

**Error policy**: these defaults can be overridden per-process in process.md.

## Gate Protocol

Gates are checkpoints where the process pauses for review. Behavior depends on the active mode file.

**When `gates: enforced` (supervised mode):**
1. Phase completes, orchestrator presents output summary (not raw files unless asked)
2. Flag any quality concerns or red flags
3. Ask: "Approve and continue, or request changes?"
4. Classify the user's response using `library/message-routing/SKILL.md`:
   - Approval: proceed to next phase
   - Feedback: fix in session + queue signal for permanent improvement
   - Question: answer, then re-present gate
   - Instruction: incorporate, then continue

**When `gates: advisory` (autonomous mode):**
- Log gate results to status.yaml but do not pause
- Orchestrator self-reviews at each gate point
- Flag critical issues for user attention even in autonomous mode

## Shutdown Sequence

When all phases are complete:

1. **Complete all phases** and verify all output files exist
2. **Send downstream feedback** to each team member: share relevant quality notes from later phases (e.g., tell researcher what the journalist struggled with)
3. **Each agent writes self-evaluation** using `library/self-evaluation/SKILL.md` (when feedback is enabled). This is mandatory — do NOT proceed to step 4 until all agents have written their feedback. Self-evaluation instructions must be included in every agent spawn prompt (see Spawning Team Members above). Agents have full work context at this point, making evaluations rich and specific. Output to `workspace/{process}/{slug}/feedback/{agent-name}.md`
4. **All agents shut down together** after self-evaluation completes
5. **Verify all feedback signals** have been routed to their destinations (GitHub issues, artifact backlogs, etc.) before declaring session complete
6. **Orchestrator finalizes status.yaml**: mark process as `completed`, record final timestamps and quality scores

## Resumability

If a session is interrupted (context limits, user leaves, crash):

1. On next session start, read `workspace/{process}/{slug}/status.yaml`
2. Identify last completed phase and current in_progress phase
3. For in_progress phases: check if output files exist and are complete
   - If complete but not marked: mark as completed, proceed
   - If partial: move to `partial/`, restart the phase
4. Resume from next pending phase
5. Re-spawn team members as needed (they don't persist across sessions)

The orchestrator is responsible for completing the process to a high degree of quality regardless of how many sessions it takes.
