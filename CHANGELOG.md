# Changelog

## 1.2.0 — 2026-03-07

Generation scripts. Three bash scripts replace manual artifact creation — the orchestrator makes creative decisions, scripts handle mechanical work. Zero post-generation editing.

### Generation Scripts

- **`pas-create-skill`**: Generates SKILL.md, changelog, references/, feedback/backlog/ from CLI flags. Validates kebab-case names, required flags.
- **`pas-create-agent`**: Generates agent.md, skills/, references/, changelog, feedback/backlog/. Auto-merges orchestrator tools and behavior when `--role orchestrator`.
- **`pas-create-process`**: Generates process.md, mode files, thin launcher, references/, changelog, feedback/backlog/. Validates orchestration patterns, phase/input field counts.

### Skill Simplification

- **creating-skills**: Steps 4-6 (Write SKILL.md, Scaffold, Create Eval) replaced by Step 4 "Generate the Skill" calling `pas-create-skill`.
- **creating-agents**: Steps 5-7 (Write agent.md, Scaffold, Create Eval) replaced by Step 5 "Generate the Agent" calling `pas-create-agent`. Added Step 6 "Create Agent Skills".
- **creating-processes**: Steps 6-12 (Scaffold, Write process.md, Mode Files, Thin Launcher, Integration Test) replaced by Step 6 "Generate Process" calling `pas-create-process`.

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

- **Hooks auto-discovery**: Hooks (`check-self-eval.sh`, `route-feedback.sh`) are auto-discovered by Claude Code from the plugin's `hooks/hooks.json` by convention — no `plugin.json` declaration or project-level configuration needed.

## 1.0.0 — 2026-03-06

Initial release. PAS framework as Claude Code plugin marketplace.
