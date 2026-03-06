---
name: pas
goal: Help users create and manage processes, agents, and skills
version: 1.0
orchestration: solo
sequential: true
modes: [supervised, autonomous]

input:
  - intent: what the user wants to create, modify, or improve

phases:
  understand-intent:
    agent: orchestrator
    input: user message
    output: clarified goal
    gate: user confirms understanding

  execute:
    agent: orchestrator
    input: clarified goal
    output: created/modified PAS artifacts
    gate: user approves result

status_file: workspace/pas/{slug}/status.yaml
---

# PAS Management Process

Help users create and manage processes, agents, and skills. The orchestrator handles everything directly (solo pattern) using its creation and feedback skills.

## Phases

1. **Understand Intent**: Brainstorming-style conversation to clarify what the user wants. Crystal clarity principle: never assume, ask until clear.
2. **Execute**: Route to the appropriate skill (create process, create agent, create skill, apply feedback) and execute.
