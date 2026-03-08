# PAS Process Changelog

## 2026-03-08 — Remove "crystal clarity" jargon (Cycle 9, Milestone 1)

Triggered by: DX audit — "crystal clarity principle" is internal jargon that adds no value over plain language
Changes:
- SKILL.md (entry point) line 25: replaced with "Never assume you understand what the user wants — ask clarifying questions until they confirm."
- agents/orchestrator/agent.md line 24: replaced with "ask until the user confirms before acting"
- agents/orchestrator/skills/creating-processes/SKILL.md line 22: replaced with plain instruction
- agents/orchestrator/skills/applying-feedback/SKILL.md line 76: replaced with "ask the user to clarify"
- process.md line 34: replaced with "Never assume — ask clarifying questions until the user confirms."

## 2026-03-07 — Add self-setup, framework feedback mechanism, hook declaration

Triggered by: GitHub issue #1 — No init for new repos, no way to give feedback to PAS itself, hooks never fire
Pattern: PAS infrastructure assumptions break on first use in new repos; feedback loop structurally broken
Changes:
- SKILL.md (entry point): Enhanced First-Run Detection to create library/, workspace/, and pas-config.yaml
- SKILL.md (entry point): Added Framework Feedback section for routing PAS-level issues to GitHub
- SKILL.md (entry point): Updated Library Bootstrap to reference First-Run Detection
- plugin.json: Removed invalid hooks field — hooks are auto-discovered from `hooks/hooks.json` by convention
- SKILL.md (entry point): Documented that hooks load automatically, no project-level config needed
