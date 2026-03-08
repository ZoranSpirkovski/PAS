---
name: pas
description: Use when creating, managing, or improving processes, agents, and skills. The single entry point for the PAS framework.
---

Read `${CLAUDE_SKILL_DIR}/../../processes/pas/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_SKILL_DIR}/../../library/orchestration/` as specified in the process.

## Quick Routing

Based on the user's message, read the appropriate skill from `${CLAUDE_SKILL_DIR}/../../processes/pas/agents/orchestrator/skills/`:

- **Creating something new** (process, pipeline, workflow): read `creating-processes/SKILL.md`
- **Creating hooks** (hook, lifecycle, guard, automation, when something happens): read `creating-hooks/SKILL.md`
- **Applying feedback** (upgrade, improve, what feedback exists): read `applying-feedback/SKILL.md`
- **Modifying existing** (change, update, add phase): read the target artifact, then use creation skills
- **Running a process** (run article, start pipeline): point to thin launcher (e.g., `/article`)
- **Visualizing a process** (visualize, overview, view, HTML, diagram): read `${CLAUDE_SKILL_DIR}/../../library/visualize-process/SKILL.md`
- **Information query** (what exists, status, list): survey `processes/`, `library/`, `workspace/`

## Conversation Style

- Brainstorming mode: explore the goal before committing to a solution
- One question at a time: never ask multiple questions in one message
- Crystal clarity principle: never assume you understand. Ask until the user confirms.
- No PAS jargon unless the user uses it first. Speak in terms of goals, tasks, and steps.

## First-Run Detection

If `pas-config.yaml` does not exist at the project root, run self-setup:

1. Create `pas-config.yaml` with defaults: `feedback: enabled`, `feedback_disabled_at: ~`
2. Create `library/` with core skills by copying from the PAS plugin's library: `self-evaluation/`, `message-routing/`, `orchestration/`
3. Create `workspace/` directory
4. Confirm to the user: "PAS initialized — library, workspace, and config are ready."

Hooks (`check-self-eval.sh`, `route-feedback.sh`) are loaded automatically by Claude Code from the plugin's `hooks/hooks.json` — no project-level configuration needed.

## Frustration Detection

If `pas-config.yaml` shows `feedback: disabled` and the user expresses frustration about repeated issues, offer to re-enable feedback collection.

## Library Bootstrap

First-Run Detection handles initial library setup. When creating a new process that references library skills not yet in the user's project `library/`, copy them from `${CLAUDE_SKILL_DIR}/../../library/`. This makes the user's project self-contained.

## Framework Feedback

Feedback about the PAS framework itself (not a specific process) should be filed as a GitHub issue on https://github.com/ZoranSpirkovski/PAS. Process-local feedback stays in workspace feedback directories and targets process artifacts. If during self-evaluation an agent identifies an issue with PAS itself (e.g., missing capabilities, broken conventions), it should note the target as `framework:pas` and the orchestrator should file it as a GitHub issue at shutdown.
