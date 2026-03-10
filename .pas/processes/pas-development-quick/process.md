---
name: pas-development-quick
goal: Evolve the PAS framework using superpowers skills for fast iteration without multi-agent teams
version: 1.0
orchestration: solo
sequential: true
modes: [supervised, autonomous]

input:
  - directive: optional owner directive for what to work on this cycle

phases:
  discovery:
    agent: orchestrator
    input: directive OR roadmap
    output: workspace/pas-development-quick/{slug}/discovery/priorities.md
    gate: product owner approves priorities
  planning:
    agent: orchestrator
    input: discovery/priorities.md
    output: workspace/pas-development-quick/{slug}/planning/implementation-plan.md
    gate: product owner approves plan
  execution:
    agent: orchestrator
    input: planning/implementation-plan.md
    output: workspace/pas-development-quick/{slug}/execution/changes/
    gate: product owner reviews changes
  validation:
    agent: orchestrator
    input: execution/changes/
    output: workspace/pas-development-quick/{slug}/validation/report.md
    gate: product owner approves release
  release:
    agent: orchestrator
    input: validation/report.md
    output: PR URL
    gate: product owner confirms merge

status_file: .pas/workspace/pas-development-quick/{slug}/status.yaml
---

# Pas Development Quick

A lightweight version of pas-development that uses superpowers skills instead of multi-agent teams. Same 5 phases, solo orchestrator, faster iteration.

## Phases

**Discovery**: Agent `orchestrator` takes `directive OR roadmap` and produces `workspace/pas-development-quick/{slug}/discovery/priorities.md`. Gate: product owner approves priorities.

**Planning**: Agent `orchestrator` takes `discovery/priorities.md` and produces `workspace/pas-development-quick/{slug}/planning/implementation-plan.md`. Gate: product owner approves plan.

**Execution**: Agent `orchestrator` takes `planning/implementation-plan.md` and produces `workspace/pas-development-quick/{slug}/execution/changes/`. Gate: product owner reviews changes.

**Validation**: Agent `orchestrator` takes `execution/changes/` and produces `workspace/pas-development-quick/{slug}/validation/report.md`. Gate: product owner approves release.

**Release**: Agent `orchestrator` takes `validation/report.md` and produces `PR URL`. Gate: product owner confirms merge.

## Superpowers Skill Mapping

Each phase uses a specific superpowers skill instead of spawning agent teams:

| Phase | Superpowers Skill | What It Does |
|-------|------------------|--------------|
| Discovery | `superpowers:brainstorming` | Interactive session with user to define directive |
| Planning | `superpowers:writing-plans` | Produce scoped implementation plan |
| Execution | `superpowers:dispatching-parallel-agents` or `superpowers:subagent-driven-development` | Dispatch work items from plan |
| Validation | `superpowers:verification-before-completion` | Verify changes against plan |
| Release | `superpowers:finishing-a-development-branch` | Commit, branch, PR via pr-management |

## Lifecycle

This process follows the shared lifecycle protocol. Read `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md` for:

- Workspace creation and status tracking
- Task creation (required — create a Claude Code task for each phase)
- Shutdown sequence and completion gate
- Ready handshake for multi-agent patterns

