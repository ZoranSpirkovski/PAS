# Changelog

## 1.1.0 — 2026-03-07

First feedback cycle. Applied 16 signals from first real usage (SEO process creation across 2 sessions). [Issue #1](https://github.com/ZoranSpirkovski/PAS/issues/1), [PR #2](https://github.com/ZoranSpirkovski/PAS/pull/2).

### Creating Processes

- **Execution framing**: Skill asserts itself as the execution framework. Prevents plan mode misuse — exits plan mode before starting, enforces AskUserQuestion for interactive brainstorming.
- **Reference material preparation** (new Step 2): Store original source material, analyze for best reference format, no arbitrary length limits. Distilled docs supplement the source — they don't replace it.
- **Source verification** (new Step 9): Mandatory cross-check of created skills against reference material to prevent fabrication and omission.

### Orchestration Patterns

- **Mandatory self-evaluation**: Shutdown in solo.md and hub-and-spoke.md now enforces self-eval checkpoint. Cannot declare session complete without it.
- **Self-eval in spawn prompts**: Every team member spawn prompt includes self-evaluation instructions.
- **Agent communication guide**: New section in hub-and-spoke.md — SendMessage for team members, Agent resume for ephemeral subagents.
- **Feedback routing verification**: Shutdown sequence verifies all feedback signals have been routed before completion.
- **Intra-phase parallel dispatch**: Absorbed parallel agent dispatch pattern into hub-and-spoke.md with PAS lifecycle enforcement — verified paths, shutdown protocol, mandatory feedback for all agents including ephemeral ones.

### PAS Entry Point

- **Self-setup on first run**: First-Run Detection now creates library/ (with core skills), workspace/, and pas-config.yaml.
- **Framework feedback**: New section documenting how to route PAS-level issues to GitHub (target `framework:pas`).

### Infrastructure

- **Hook installation via self-setup**: Plugin manifest doesn't support hook declaration. First-Run Detection now installs hooks into the project's `.claude/settings.json`, enabling check-self-eval.sh and route-feedback.sh.

## 1.0.0 — 2026-03-06

Initial release. PAS framework as Claude Code plugin marketplace.
