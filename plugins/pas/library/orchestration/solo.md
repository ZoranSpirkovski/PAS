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
2. Checks for existing workspace (resumability, same as hub-and-spoke)
3. Executes each phase by reading the relevant skill from its own `skills/` directory
4. Writes output to workspace
5. Handles gates (if supervised mode)
6. Updates status.yaml after each phase

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

1. All phases complete
2. Orchestrator writes self-evaluation (if feedback enabled)
3. Finalize status.yaml
