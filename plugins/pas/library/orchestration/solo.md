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
2. **Create workspace** -- follow `lifecycle.md` > Workspace Creation
3. **Create lifecycle tasks** -- follow `lifecycle.md` > Lifecycle Task Creation
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

Same format as `lifecycle.md` > Status Tracking. The `agent` field for every phase is `orchestrator`.

## Shutdown, Completion Gate, Session Continuity, Resumability

Follow `lifecycle.md` for:
- **Shutdown Sequence** (steps 1-8; steps 2-4 are skipped since there are no team members)
- **Completion Gate** (4 conditions + hook enforcement; condition 2 requires only `feedback/orchestrator.md`)
- **Session Continuity** (offer next cycle)
- **Resumability** (resume from status.yaml)
