---
name: solo
description: Single-agent operation where the orchestrator handles everything directly
---

# Solo Orchestration

The simplest pattern. The orchestrator is the only agent and handles all phases using its own skills. No delegation, no team members.

## When to Use

- Simple processes with a single skill or a few closely related skills
- Tasks where spawning specialist agents would be overhead without benefit
- Prototyping a new process before adding specialist agents
- Processes with 1-3 phases that one agent can handle well

## Operator Behavior

The orchestrator reads process.md and executes phases sequentially using its own skills. It:

1. Reads the process definition and mode file
2. **Create workspace** — this is a HARD REQUIREMENT, not optional

   ```bash
   mkdir -p workspace/{process}/{slug}/discovery
   mkdir -p workspace/{process}/{slug}/planning
   mkdir -p workspace/{process}/{slug}/execution/changes
   mkdir -p workspace/{process}/{slug}/validation
   mkdir -p workspace/{process}/{slug}/feedback
   ```

   Write `workspace/{process}/{slug}/status.yaml` with all phases as `pending`, `started_at` timestamp, and `status: in_progress`.

   Do NOT proceed to step 3 until the workspace directory and status.yaml exist on disk.

   2a. **If status.yaml already exists**: this is a resumed session. Read it and resume from the last completed phase. Do not re-create the workspace.

3. **Create lifecycle tasks** using TaskCreate. These tasks make work visible and are enforced by the `verify-task-completion.sh` hook:

   For each phase in process.md:
   - `[PAS] Phase: {phase-name}` — description: "{agent} processes {input} to produce {output}"

   Shutdown tasks (always created):
   - `[PAS] Self-evaluation` — description: "Write feedback/orchestrator.md using library/self-evaluation/SKILL.md"
   - `[PAS] Route framework signals` — description: "File any framework:pas signals as GitHub issues"
   - `[PAS] Finalize status` — description: "Set status.yaml status to completed with completed_at timestamp"

   Mark each task as completed when its work is done. The `[PAS]` prefix triggers hook enforcement — you cannot mark shutdown tasks complete until their deliverables exist on disk.

4. Executes each phase by reading the relevant skill from its own `skills/` directory
5. Writes output to workspace
6. Handles gates (if supervised mode)
7. Updates status.yaml after each phase

No TeamCreate calls. No Agent tool delegation. If the orchestrator needs parallel subtask execution, it can spawn ephemeral subagents via the Agent tool, but these are fire-and-forget helpers, not team members.

## When to Upgrade

Consider upgrading to hub-and-spoke when:
- A phase consistently takes too long for one agent
- Quality feedback suggests a specialist would do better
- The process grows beyond 3-4 phases with distinct skill requirements
- Token budget becomes a concern (specialist agents have smaller context)

## Status Tracking

Same format as hub-and-spoke. The `agent` field for every phase is `orchestrator`.

## Shutdown

1. All phases complete — verify all output files exist
2. **Mandatory self-evaluation checkpoint**: If feedback is enabled in `pas-config.yaml`, read `library/self-evaluation/SKILL.md` and write feedback to `workspace/{process}/{slug}/feedback/orchestrator.md`. Do NOT skip this step. Do NOT declare the session complete until self-evaluation is written.
3. **Route framework signals**: Any signal with target `framework:pas` must be filed as a GitHub issue on the PAS repository. Do not leave framework signals in local feedback files only.
4. Verify all feedback signals have been routed to their destinations (GitHub issues, artifact backlogs, etc.) before declaring session complete
5. Finalize status.yaml

### COMPLETION GATE

Before declaring the session complete, ALL of the following MUST be true:

1. All phases have `status: completed` in status.yaml
2. Feedback file exists at `workspace/{process}/{slug}/feedback/orchestrator.md`
3. All signals with target `framework:pas` have been filed as GitHub issues
4. `status.yaml` has `completed_at` timestamp and `status: completed`

If any condition is not met, the session is NOT complete. Go back and satisfy the missing condition.

**Hook enforcement:** The `verify-completion-gate.sh` Stop hook enforces conditions 1-2 technically. If you try to stop without writing feedback, the hook will block you and tell you what's missing. The hook is a safety net — follow the shutdown sequence above so it never needs to fire.
