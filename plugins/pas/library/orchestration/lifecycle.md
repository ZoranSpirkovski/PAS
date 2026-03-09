---
name: lifecycle
description: Shared lifecycle protocol for all orchestration patterns. Covers workspace, tasks, status, shutdown, completion gate, resumability, and agent ready-handshake.
---

# Lifecycle Protocol

Every orchestration pattern shares this lifecycle protocol. Pattern-specific files (hub-and-spoke, discussion, solo, sequential-agents) define only their unique behavior and reference this file for shared protocol.

## Workspace Creation

This is a **HARD REQUIREMENT**, not optional. Do NOT proceed to any subsequent startup step until the workspace directory and status.yaml exist on disk.

```bash
mkdir -p workspace/{process}/{slug}/discovery
mkdir -p workspace/{process}/{slug}/planning
mkdir -p workspace/{process}/{slug}/execution/changes
mkdir -p workspace/{process}/{slug}/validation
mkdir -p workspace/{process}/{slug}/feedback
```

Write `workspace/{process}/{slug}/status.yaml` with all phases as `pending`, `started_at` timestamp, and `status: in_progress`.

**If status.yaml already exists**: this is a resumed session. Read it and resume from the last completed phase (see Resumability below). Do not re-create the workspace.

## Lifecycle Task Creation

Create lifecycle tasks using TaskCreate immediately after workspace creation. These tasks make work visible and are enforced by the `verify-task-completion.sh` hook.

For each phase in process.md:
- `[PAS] Phase: {phase-name}` -- description: "{agent} processes {input} to produce {output}"

Shutdown tasks (always created):
- `[PAS] Self-evaluation` -- description: "Write feedback/orchestrator.md using library/self-evaluation/SKILL.md"
- `[PAS] Route framework signals` -- description: "File any framework:pas signals as GitHub issues"
- `[PAS] Finalize status` -- description: "Set status.yaml status to completed with completed_at timestamp"

Mark each task as completed when its work is done. The `[PAS]` prefix triggers hook enforcement -- you cannot mark shutdown tasks complete until their deliverables exist on disk.

## Ready Handshake

When spawning agents via TeamCreate (hub-and-spoke, discussion, sequential-agents patterns), use this protocol to prevent the agent spawn timing race condition where messages sent during spawn are lost.

### Protocol

1. **Include in every spawn prompt**: "After reading your agent.md and skills, send a message to the orchestrator containing only: `READY: {agent-name}`"
2. **Orchestrator waits** for READY messages from all spawned agents before sending any work instructions
3. **Probe on timeout**: if an agent does not send READY within a reasonable period, orchestrator sends a probe message: "Confirm you are ready by responding with `READY: {agent-name}`"
4. **Dispatch only after confirmation**: only after all agents confirm READY does the orchestrator begin phase dispatch or discussion facilitation

### Why This Exists

Agents spawned via TeamCreate read their agent.md before processing their mailbox. Messages sent during spawn are lost. This has been observed in cycle 7, cycle 8, and cycle 9. The ready-handshake ensures the orchestrator does not send work instructions until agents are actually listening.

The solo pattern does not use this protocol since it does not spawn agents.

## Status Tracking

Write `workspace/{process}/{slug}/status.yaml` continuously at every state change. Status is a performance log, not just state.

**Valid states:** `pending`, `in_progress`, `completed`. Add process-specific states only when the user requests them.

**Format:**
```yaml
process: {name}
instance: {slug}
started_at: {ISO timestamp}
completed_at: ~
status: in_progress
current_session: {first 8 chars of session_id}

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

sessions:
  - id: {short session_id}
    started_at: {ISO timestamp}
    completed_at: {ISO timestamp or ~}
    feedback_collected: {true or false}
```

**Session tracking:** The `pas-session-start.sh` hook automatically writes `current_session` and appends to the `sessions` list when a session begins. Feedback files are named `feedback/orchestrator-{session_id}.md` so the Stop hook can verify that THIS session (not a previous one) produced feedback.

Sub-processes write their own status.yaml. Parent references via `subprocess: {path}/status.yaml`.

## Shutdown Sequence

When all phases are complete:

1. **Verify all output files** exist for all phases
2. **Send downstream feedback** to each team member (if any): share relevant quality notes from later phases
3. **Each agent writes self-evaluation** using `library/self-evaluation/SKILL.md` (when feedback is enabled). This is mandatory -- do NOT proceed to step 4 until all agents have written their feedback. Output to `workspace/{process}/{slug}/feedback/{agent-name}.md`. The `check-self-eval.sh` SubagentStop hook blocks agents from stopping without feedback, and the `verify-completion-gate.sh` Stop hook verifies ALL agents have feedback files before the orchestrator can stop.
4. **All agents shut down together** after self-evaluation completes. The orchestrator MUST NOT instruct agents to skip self-evaluation — hook enforcement will block the session if any agent feedback is missing.
5. **Orchestrator writes own self-evaluation** to `workspace/{process}/{slug}/feedback/orchestrator.md`. The orchestrator is an agent too -- it observes issues that team members cannot (coordination failures, gate misjudgments, process-level problems). Do NOT skip this step.
6. **Route framework signals**: Any signal with target `framework:pas` must be filed as a GitHub issue on the PAS repository. Do not leave framework signals in local feedback files only.
7. **Verify all feedback signals** have been routed to their destinations (GitHub issues, artifact backlogs, etc.) before declaring session complete
8. **Orchestrator finalizes status.yaml**: mark process as `completed`, record final timestamps and quality scores

For solo pattern: steps 2-4 are skipped (no team members). The orchestrator writes its own self-evaluation at step 5.

## Completion Gate

Before declaring the session complete, ALL of the following MUST be true:

1. All phases have `status: completed` in status.yaml
2. All feedback files exist in `workspace/{process}/{slug}/feedback/` (one per agent + orchestrator)
3. All signals with target `framework:pas` have been filed as GitHub issues
4. `status.yaml` has `completed_at` timestamp and `status: completed`

If any condition is not met, the session is NOT complete. Go back and satisfy the missing condition.

**Hook enforcement:** The `verify-completion-gate.sh` Stop hook enforces conditions 1-2 technically. If you try to stop without writing feedback, the hook will block you and tell you what's missing. The hook is a safety net -- follow the shutdown sequence above so it never needs to fire.

## Ad-Hoc Execution

When the product owner provides a pre-built plan or directs work outside a formal process invocation, the shutdown sequence still applies. Specifically:

1. If a workspace exists for the current cycle, use it — do not create a new one
2. Create lifecycle tasks for shutdown steps (`[PAS] Self-evaluation`, `[PAS] Route framework signals`, `[PAS] Finalize status`)
3. After all work is done, follow the full Shutdown Sequence above

The hooks enforce this regardless of how the work was initiated. Skipping shutdown because "this wasn't a formal process run" is not acceptable — the feedback system only works if every session contributes signals.

## Session Continuity

After the completion gate is satisfied, **always offer the product owner the option to start another cycle.** Ask whether they have a directive for the next cycle or want signal-driven discovery. Do not end the conversation without this offer -- the product owner may want to chain cycles while context is fresh.

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
