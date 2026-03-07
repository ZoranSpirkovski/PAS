---
name: orchestration-patterns
description: Decision guide for selecting the right orchestration pattern for a process
---

# Orchestration Pattern Selection

Every process declares an `orchestration:` field in its process.md. This guide helps you choose the right pattern.

## Available Patterns

| Pattern | File | Orchestrator Role | Best For |
|---------|------|-------------------|----------|
| hub-and-spoke | `hub-and-spoke.md` | Central orchestrator, all agents communicate through hub | Multi-agent pipelines with clear phases |
| discussion | `discussion.md` | Moderator, facilitates multi-agent discussion | Brainstorming, design review, multi-perspective analysis |
| solo | `solo.md` | Operator, single agent handles everything | Simple processes, single-skill tasks |
| sequential-agents | `sequential-agents.md` | Coordinator, explicit handoff between agents | Strict ordering, resource constraints, assembly-line work |

## Decision Matrix

**Start here:**

1. **How many agents does the process need?**
   - One agent: use **solo**
   - Multiple agents: continue to question 2

2. **Do agents need to discuss or debate?**
   - Yes, agents need multi-perspective synthesis: use **discussion**
   - No, agents work on distinct phases: continue to question 3

3. **Can phases run in parallel?**
   - Yes, I/O dependencies allow parallelism: use **hub-and-spoke** (default)
   - No, strict linear ordering required: use **sequential-agents**

4. **Still unsure?**
   - Default to **hub-and-spoke**. It handles both parallel and sequential phases, and the orchestrator can infer execution order from I/O dependencies.

## Pattern Details

Read the individual pattern file for execution rules:

- `hub-and-spoke.md` — Spawn order, parallelism inference, status tracking, error chain, shutdown sequence, gate protocol, resumability
- `discussion.md` — Moderator behavior, turn-taking, synthesis rules
- `solo.md` — Single-agent operation, when to upgrade to multi-agent
- `sequential-agents.md` — Handoff protocol, status updates between agents

## Overriding Defaults

A process can override pattern defaults in its process.md:
- `sequential: true` forces linear execution even in hub-and-spoke
- Mode files (`modes/supervised.md`, `modes/autonomous.md`) control gate behavior
- Error policy can be customized per-process (default is in hub-and-spoke.md)
