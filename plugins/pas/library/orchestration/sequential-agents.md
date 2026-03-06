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
