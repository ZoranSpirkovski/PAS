---
name: pas
description: Use when creating, managing, or improving processes, agents, and skills. The single entry point for the PAS framework.
---

Read `${CLAUDE_SKILL_DIR}/../../processes/pas/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_SKILL_DIR}/../../library/orchestration/` as specified in the process.

## Project Convention

All PAS artifacts in the user's project live under `.pas/` at the project root:

- `.pas/config.yaml` — framework configuration
- `.pas/processes/` — process definitions, agents, skills, feedback backlogs
- `.pas/workspace/` — execution instances, status tracking, session feedback

When reading, modifying, or creating artifacts — always resolve paths relative to `.pas/`.

## Quick Routing

Based on the user's message, read the appropriate skill from `${CLAUDE_SKILL_DIR}/../../processes/pas/agents/orchestrator/skills/`:

- **Creating something new** (process, pipeline, workflow): read `creating-processes/SKILL.md`
- **Creating hooks** (hook, lifecycle, guard, automation, when something happens): read `creating-hooks/SKILL.md`
- **Applying feedback** (upgrade, improve, what feedback exists): read `applying-feedback/SKILL.md`
- **Modifying existing** (change, update, add phase): find the target in `.pas/processes/` or `.pas/library/`, read it, then use creation skills to apply the modification
- **Running a process** (run article, start pipeline): point to thin launcher (e.g., `/article`)
- **Visualizing a process** (visualize, overview, view, HTML, diagram): read `${CLAUDE_SKILL_DIR}/../../library/visualize-process/SKILL.md`
- **Information query** (what exists, status, list): survey `.pas/processes/`, `.pas/library/`, `.pas/workspace/`

## Conversation Style

- Brainstorming mode: explore the goal before committing to a solution
- One question at a time: never ask multiple questions in one message
- Never assume you understand what the user wants — ask clarifying questions until they confirm.
- No PAS jargon unless the user uses it first. Speak in terms of goals, tasks, and steps.

## First-Run Detection

If `.pas/config.yaml` does not exist at the project root, run self-setup:

1. Create `.pas/config.yaml` with defaults: `feedback: enabled`, `feedback_disabled_at: ~`
2. Create `.pas/workspace/` directory
3. Confirm to the user: "PAS initialized — `.pas/` directory created with config and workspace."

If old-style `pas-config.yaml` exists at root but `.pas/` does not, auto-migrate: move config, library, workspace, processes, and feedback into `.pas/`.

Hooks (`check-self-eval.sh`, `route-feedback.sh`) are loaded automatically by Claude Code from the plugin's `hooks/hooks.json` — no project-level configuration needed.

## Frustration Detection

If `.pas/config.yaml` shows `feedback: disabled` and the user expresses frustration about repeated issues, offer to re-enable feedback collection.

## Library Bootstrap

Processes reference the plugin library directly via `${CLAUDE_PLUGIN_ROOT}/library/` — no copying needed. The library lives in the plugin and is always available at runtime.

## Framework Feedback

Feedback about the PAS framework itself (not a specific process) should be filed as a GitHub issue on https://github.com/ZoranSpirkovski/PAS. Process-local feedback stays in workspace feedback directories and targets process artifacts. If during self-evaluation an agent identifies an issue with PAS itself (e.g., missing capabilities, broken conventions), it should note the target as `framework:pas` and the orchestrator should file it as a GitHub issue at shutdown.
