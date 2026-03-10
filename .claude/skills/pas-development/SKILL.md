---
name: pas-development
description: Evolve the PAS plugin — choose between full multi-agent cycles, quick superpowers-driven cycles, or resume a previous cycle.
---

## Mode Selection

Before loading any process, present these options to the user:

1. **Full cycle** — Multi-agent teams with brainstorming at key touchpoints. Best for complex changes needing diverse perspectives.
2. **Quick cycle** — Solo orchestrator using superpowers skills. Best for focused changes where you know what to do.
3. **Resume** — Continue an interrupted cycle from where it left off.

Ask: "Which mode? (1) Full cycle, (2) Quick cycle, (3) Resume"

If the user passed arguments (a directive), carry them through to whichever mode is chosen.

## Routing

### Full cycle

Ask the user how they want to start discovery:
- **Direct directive** — user already knows what they want to work on
- **Signal-driven** — discover from accumulated feedback and roadmap
- **Brainstorm** — invoke `superpowers:brainstorming` to interactively define the directive, then proceed

Then:
Read `.pas/processes/pas-development/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` as specified in the process.
Execute.

After multi-agent discovery completes, if the findings surface complexity or trade-offs that weren't anticipated, offer a follow-up brainstorming session with the user before proceeding to planning.

### Quick cycle

Read `.pas/processes/pas-development/processes/quick/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` as specified in the process.
Execute.

### Resume

Find the most recent workspace under `.pas/workspace/pas-development/` or `.pas/workspace/pas-development/quick/` with `status: in_progress` in status.yaml.
Read that process's definition and orchestration pattern.
Resume from the last completed phase.
