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

## Spawning and Shutdown

- Spawn all discussion participants via TeamCreate at discussion start
- All agents stay alive for the full discussion (they need prior round context)
- Shutdown follows the same sequence as hub-and-spoke (downstream feedback, self-eval, shutdown together)

## Gate Protocol

In supervised mode, the moderator presents the synthesis to the user at each gate rather than raw agent outputs. The user can redirect the discussion or approve the synthesis.
