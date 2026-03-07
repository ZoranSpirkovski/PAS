---
name: sequential-agents
description: One agent at a time with explicit handoff between phases
---

# Sequential-Agents Orchestration

Agents execute one at a time in strict order. The orchestrator manages handoff between agents, ensuring each phase completes before the next begins. No parallelism.

## When to Use

- Strict ordering is required (each phase depends entirely on the previous)
- Resource constraints prevent running multiple agents simultaneously
- Assembly-line workflows where each agent transforms the previous agent's output
- Processes where context from phase N is critical to phase N+1 and must be passed explicitly

## Startup Sequence

1. **Read process.md** to load the process definition (phases, agents, handoff requirements)
2. **Read mode file** (`modes/{mode}.md`) to determine gate behavior
3. **Create workspace** — this is a HARD REQUIREMENT, not optional

   ```bash
   mkdir -p workspace/{process}/{slug}/discovery
   mkdir -p workspace/{process}/{slug}/planning
   mkdir -p workspace/{process}/{slug}/execution/changes
   mkdir -p workspace/{process}/{slug}/validation
   mkdir -p workspace/{process}/{slug}/feedback
   ```

   Write `workspace/{process}/{slug}/status.yaml` with all phases as `pending`, `started_at` timestamp, and `status: in_progress`.

   Do NOT proceed to step 4 until the workspace directory and status.yaml exist on disk.

   3a. **If status.yaml already exists**: this is a resumed session. Read it and resume from the last completed phase. Do not re-create the workspace.

4. **Create lifecycle tasks** using TaskCreate. These tasks make work visible and are enforced by the `verify-task-completion.sh` hook:

   For each phase in process.md:
   - `[PAS] Phase: {phase-name}` — description: "{agent} processes {input} to produce {output}"

   Shutdown tasks (always created):
   - `[PAS] Self-evaluation` — description: "Write feedback/orchestrator.md using library/self-evaluation/SKILL.md"
   - `[PAS] Route framework signals` — description: "File any framework:pas signals as GitHub issues"
   - `[PAS] Finalize status` — description: "Set status.yaml status to completed with completed_at timestamp"

   Mark each task as completed when its work is done. The `[PAS]` prefix triggers hook enforcement — you cannot mark shutdown tasks complete until their deliverables exist on disk.

5. **Spawn first agent** via TeamCreate with handoff context

## Shutdown Sequence

When all phases are complete:

1. **Verify all output files** exist for all phases
2. **Send downstream feedback** to agents still alive: share relevant quality notes from later phases
3. **Each agent writes self-evaluation** using `library/self-evaluation/SKILL.md` (when feedback is enabled). Output to `workspace/{process}/{slug}/feedback/{agent-name}.md`
4. **All remaining agents shut down** after self-evaluation completes
5. **Orchestrator writes own self-evaluation** to `workspace/{process}/{slug}/feedback/orchestrator.md`
6. **Route framework signals**: Any signal with target `framework:pas` must be filed as a GitHub issue on the PAS repository
7. **Verify all feedback signals** have been routed to their destinations
8. **Orchestrator finalizes status.yaml**: mark process as `completed`, record final timestamps

### COMPLETION GATE

Before declaring the session complete, ALL of the following MUST be true:

1. All phases have `status: completed` in status.yaml
2. All feedback files exist in `workspace/{process}/{slug}/feedback/` (one per agent + orchestrator)
3. All signals with target `framework:pas` have been filed as GitHub issues
4. `status.yaml` has `completed_at` timestamp and `status: completed`

If any condition is not met, the session is NOT complete. Go back and satisfy the missing condition.

**Hook enforcement:** The `verify-completion-gate.sh` Stop hook enforces conditions 1-2 technically. If you try to stop without writing feedback, the hook will block you and tell you what's missing. The hook is a safety net — follow the shutdown sequence above so it never needs to fire.

## Handoff Protocol

When one agent completes and the next begins:

1. **Current agent completes phase**: writes all output files, updates status.yaml
2. **Orchestrator verifies output**: checks output files exist and are non-empty
3. **Orchestrator prepares handoff**: summarizes what the previous agent produced and any quality notes
4. **Orchestrator spawns next agent**: via TeamCreate with handoff context in the spawn prompt
5. **Next agent reads input files** and the handoff summary, then begins work

**Handoff summary includes:**
- What was produced (file list with brief descriptions)
- Quality assessment from the orchestrator
- Any flags or concerns from the previous phase
- Specific instructions for the current phase (from process.md)

## Agent Lifecycle

Unlike hub-and-spoke where all agents persist for the full process, sequential-agents can optionally shut down agents after their phase completes. This is useful for very long processes where keeping all agents alive wastes context.

**Default behavior**: keep agents alive (same as hub-and-spoke) for downstream feedback at shutdown.

**Optional `eager_shutdown: true`** in process.md: shut down each agent immediately after their phase. Agents write self-evaluation at phase completion rather than at process end. Trade-off: no downstream feedback, but lower resource usage.

## Status Tracking

Same format as hub-and-spoke. The `attempts` field is important here since retries involve spawning a fresh agent.

## Error Handling

Same chain as hub-and-spoke (self-recover, orchestrator retry, escalate). On retry:
- Previous agent's output moves to `partial/`
- Fresh agent is spawned with the same handoff context
- Fresh agent can reference `partial/` for recovery hints

## Gate Protocol

Same as hub-and-spoke. Gates naturally align with handoff points between agents.
