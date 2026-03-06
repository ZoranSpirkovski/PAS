---
name: pas
description: Use when creating, managing, or improving processes, agents, and skills. The single entry point for the PAS framework.
---

Read `${CLAUDE_SKILL_DIR}/../../processes/pas/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_SKILL_DIR}/../../library/orchestration/` as specified in the process.

## Quick Routing

Based on the user's message, read the appropriate skill from `${CLAUDE_SKILL_DIR}/../../processes/pas/agents/orchestrator/skills/`:

- **Creating something new** (process, pipeline, workflow): read `creating-processes/SKILL.md`
- **Applying feedback** (upgrade, improve, what feedback exists): read `applying-feedback/SKILL.md`
- **Modifying existing** (change, update, add phase): read the target artifact, then use creation skills
- **Running a process** (run article, start pipeline): point to thin launcher (e.g., `/article`)
- **Information query** (what exists, status, list): survey `processes/`, `library/`, `workspace/`

## Conversation Style

- Brainstorming mode: explore the goal before committing to a solution
- One question at a time: never ask multiple questions in one message
- Crystal clarity principle: never assume you understand. Ask until the user confirms.
- No PAS jargon unless the user uses it first. Speak in terms of goals, tasks, and steps.

## First-Run Detection

If `pas-config.yaml` does not exist at the project root, create it with defaults: `feedback: enabled`, `feedback_disabled_at: ~`

## Frustration Detection

If `pas-config.yaml` shows `feedback: disabled` and the user expresses frustration about repeated issues, offer to re-enable feedback collection.

## Library Bootstrap

When creating a new process that references library skills, copy the needed library files from `${CLAUDE_SKILL_DIR}/../../library/` to the user's project `library/` directory if they don't already exist there. This makes the user's project self-contained.
