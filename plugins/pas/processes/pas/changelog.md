# PAS Process Changelog

## 2026-03-07 — Add self-setup, framework feedback mechanism, hook declaration

Triggered by: GitHub issue #1 — No init for new repos, no way to give feedback to PAS itself, hooks never fire
Pattern: PAS infrastructure assumptions break on first use in new repos; feedback loop structurally broken
Changes:
- SKILL.md (entry point): Enhanced First-Run Detection to create library/, workspace/, and pas-config.yaml
- SKILL.md (entry point): Added Framework Feedback section for routing PAS-level issues to GitHub
- SKILL.md (entry point): Updated Library Bootstrap to reference First-Run Detection
- plugin.json: Removed invalid hooks field — hooks are auto-discovered from `hooks/hooks.json` by convention
- SKILL.md (entry point): Documented that hooks load automatically, no project-level config needed
