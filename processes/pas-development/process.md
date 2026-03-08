---
name: pas-development
goal: Evolve the PAS framework into the de-facto best way to build agentic workflows in Claude Code
version: 1.0
orchestration: hub-and-spoke
sequential: true
modes: [supervised, autonomous]

input:
  - directive: optional owner directive for what to work on this cycle

phases:
  discovery:
    agent: [feedback-analyst, community-manager, framework-architect, dx-specialist, ecosystem-analyst]
    pattern: discussion
    input: directive OR accumulated feedback signals + open GitHub issues
    output: workspace/pas-development/{slug}/discovery/priorities.md
    gate: product owner approves priorities

  planning:
    agent: framework-architect
    input: workspace/pas-development/{slug}/discovery/priorities.md
    output: workspace/pas-development/{slug}/planning/implementation-plan.md
    gate: product owner approves plan

  execution:
    agent: [framework-architect, dx-specialist, feedback-analyst, community-manager]
    input: workspace/pas-development/{slug}/planning/implementation-plan.md
    output: workspace/pas-development/{slug}/execution/changes/
    gate: product owner reviews changes

  validation:
    agent: qa-engineer
    input: workspace/pas-development/{slug}/execution/changes/
    output: workspace/pas-development/{slug}/validation/report.md
    gate: product owner approves release

  release:
    agent: community-manager
    input: workspace/pas-development/{slug}/validation/report.md
    output: PR URL
    gate: product owner confirms merge

status_file: workspace/pas-development/{slug}/status.yaml
---

# PAS Development Process

A dedicated process for evolving the PAS framework. Uses PAS's own constructs (processes, agents, skills) to coordinate a multi-agent team that analyzes feedback, plans improvements, implements changes, and validates quality.

## Phases

1. **Discovery** (discussion pattern): The Feedback Analyst presents internal signal analysis and the Community Manager presents GitHub issue triage. Framework Architect, DX Specialist, and Ecosystem Analyst contribute their perspectives. The team debates and converges on priorities. Alternatively, the product owner injects a directive and the team pressure-tests and enriches it. Orchestrator moderates and synthesizes.

2. **Planning** (solo): The Framework Architect takes approved priorities and produces a scoped implementation plan — what changes to which files, dependencies between changes, and what can be parallelized in Execution.

3. **Execution** (hub-and-spoke): The Orchestrator dispatches work items from the plan. Framework Architect handles architectural changes using PAS creation scripts for new artifacts, DX Specialist handles documentation and ergonomics, Feedback Analyst marks addressed signals, Community Manager opens PRs and links issues.

4. **Validation** (solo): The QA Engineer reviews all changes against the approved plan, PAS conventions, cross-artifact consistency, and regressions. Issues route back to Execution. Clean report triggers release.

5. **Release** (solo): All work is committed to `dev` first in two separate commits — a plugin-only commit (`plugins/pas/` files) and a dev artifacts commit (workspace, processes, library, etc.). Then the Community Manager creates a feature branch off `main`, cherry-picks the plugin commit, verifies the diff is plugin-only, and opens a PR targeting `main`. See the pr-management skill for the detailed workflow. Dev is the source of truth; main is the clean distribution branch.
