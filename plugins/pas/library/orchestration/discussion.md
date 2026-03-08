---
name: discussion
description: Multi-agent discussion pattern where the orchestrator facilitates rather than directs
---

# Discussion Orchestration

The orchestrator acts as a **moderator**, facilitating multi-agent discussion rather than directing work. Agents communicate their perspectives, debate, and synthesize toward a shared conclusion.

## When to Use

- Brainstorming sessions requiring diverse perspectives
- Design review where multiple specialists evaluate the same artifact
- Multi-perspective analysis (risk assessment, editorial review panels)
- Any situation where the goal is synthesis from debate, not assembly from parts

## Moderator Behavior

The orchestrator does NOT assign tasks or direct output. Instead:

1. **Frame the discussion**: present the topic, constraints, and expected output format
2. **Manage turns**: ensure each agent contributes before moving to synthesis
3. **Prevent dominance**: if one agent's perspective is drowning others, explicitly invite quieter agents
4. **Probe disagreements**: when agents disagree, ask each to articulate the specific evidence behind their position
5. **Synthesize**: after all perspectives are heard, summarize areas of agreement and remaining disagreements
6. **Drive to conclusion**: the moderator proposes a synthesis and asks for final objections

## Turn-Taking Protocol

1. Moderator poses the question or presents the artifact
2. Each agent responds with their assessment (order doesn't matter, can be parallel)
3. Moderator identifies points of agreement and disagreement
4. Agents respond to each other's points (directed by moderator)
5. Moderator synthesizes and proposes conclusion
6. Agents confirm or raise final objections
7. Moderator records the outcome
8. Moderator verifies key claims against source code (read referenced files, check line numbers, confirm behavior) before recording the outcome. Treat agent reports as leads to investigate, not established facts.

## Status Tracking

Same format as hub-and-spoke, but phases map to discussion rounds rather than production stages:

```yaml
phases:
  round-1-initial:
    status: completed
    notes: "All 3 agents contributed. Key disagreement on risk level."
  round-2-debate:
    status: completed
    notes: "Researcher provided evidence that shifted consensus."
  synthesis:
    status: completed
    notes: "Consensus reached on moderate risk with mitigation."
```

## Startup Sequence

1. **Read process.md** to load the discussion topic, participants, and expected output format
2. **Read mode file** (`modes/{mode}.md`) to determine gate behavior
3. **Create workspace** — this is a HARD REQUIREMENT, not optional

   ```bash
   mkdir -p workspace/{process}/{slug}/discovery
   mkdir -p workspace/{process}/{slug}/planning
   mkdir -p workspace/{process}/{slug}/execution/changes
   mkdir -p workspace/{process}/{slug}/validation
   mkdir -p workspace/{process}/{slug}/feedback
   ```

   Write `workspace/{process}/{slug}/status.yaml` with all discussion rounds as `pending`, `started_at` timestamp, and `status: in_progress`.

   Do NOT proceed to step 4 until the workspace directory and status.yaml exist on disk.

   3a. **If status.yaml already exists**: this is a resumed session. Read it and resume from the last completed round. Do not re-create the workspace.

4. **Create lifecycle tasks** using TaskCreate. These tasks make work visible and are enforced by the `verify-task-completion.sh` hook:

   For each phase in process.md:
   - `[PAS] Phase: {phase-name}` — description: "{agent} processes {input} to produce {output}"

   Shutdown tasks (always created):
   - `[PAS] Self-evaluation` — description: "Write feedback/orchestrator.md using library/self-evaluation/SKILL.md"
   - `[PAS] Route framework signals` — description: "File any framework:pas signals as GitHub issues"
   - `[PAS] Finalize status` — description: "Set status.yaml status to completed with completed_at timestamp"

   Mark each task as completed when its work is done. The `[PAS]` prefix triggers hook enforcement — you cannot mark shutdown tasks complete until their deliverables exist on disk.

5. **Spawn all discussion participants** via TeamCreate

## Shutdown Sequence

When the discussion is complete:

1. **Verify synthesis** and all output files exist
2. **Send downstream feedback** to each participant: share how their contributions were used in the final synthesis
3. **Each agent writes self-evaluation** using `library/self-evaluation/SKILL.md` (when feedback is enabled). Output to `workspace/{process}/{slug}/feedback/{agent-name}.md`
4. **All agents shut down together** after self-evaluation completes
5. **Orchestrator writes own self-evaluation** to `workspace/{process}/{slug}/feedback/orchestrator.md`
6. **Route framework signals**: Any signal with target `framework:pas` must be filed as a GitHub issue on the PAS repository
7. **Verify all feedback signals** have been routed to their destinations
8. **Orchestrator finalizes status.yaml**: mark process as `completed`, record final timestamps

### COMPLETION GATE

Before declaring the session complete, ALL of the following MUST be true:

1. All rounds/phases have `status: completed` in status.yaml
2. All feedback files exist in `workspace/{process}/{slug}/feedback/` (one per agent + orchestrator)
3. All signals with target `framework:pas` have been filed as GitHub issues
4. `status.yaml` has `completed_at` timestamp and `status: completed`

If any condition is not met, the session is NOT complete. Go back and satisfy the missing condition.

**Hook enforcement:** The `verify-completion-gate.sh` Stop hook enforces conditions 1-2 technically. If you try to stop without writing feedback, the hook will block you and tell you what's missing. The hook is a safety net — follow the shutdown sequence above so it never needs to fire.

## Gate Protocol

In supervised mode, the moderator presents the synthesis to the user at each gate rather than raw agent outputs. The user can redirect the discussion or approve the synthesis.
