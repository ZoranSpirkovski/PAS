# Changelog

## 1.3.0 — 2026-03-07

Feedback system fix. Addresses 7 failures documented in [Issue #6](https://github.com/ZoranSpirkovski/PAS/issues/6) where two consecutive sessions completed without producing any feedback.

### Orchestration Patterns (Critical)

- **Mandatory workspace creation**: All 4 orchestration patterns (hub-and-spoke, solo, discussion, sequential-agents) now use imperative "Create workspace" as a HARD REQUIREMENT instead of passive "Check for existing workspace"
- **Orchestrator self-evaluation**: Orchestrator writes its own self-eval at shutdown (previously only team members did)
- **COMPLETION GATE**: All 4 patterns now have a blocking completion gate with 4 conditions that must be true before declaring session complete
- **Discussion/sequential-agents startup**: These patterns now have explicit startup sequences (previously deferred to hub-and-spoke or were missing entirely)
- **Framework signal routing**: Shutdown sequences now include explicit step to file `framework:pas` signals as GitHub issues

### Hook and Script Fixes

- **route-feedback.sh**: Added `plugins/` fallback search for process, agent, and skill targets. Added `framework)` case. Fixes path resolution failures when targeting plugin-owned artifacts.
- **creating-processes**: Restored step 8 "Determine Hooks" that was lost during generation scripts refactor
- **Generation scripts**: All 3 scripts (pas-create-process, pas-create-agent, pas-create-skill) now support `--base-dir` flag for safe test isolation

### Self-Evaluation

- **Framework feedback routing**: New section in self-evaluation skill documenting the `framework:pas` target, `Route: github-issue` marker, and the agent-to-orchestrator routing chain
- **PAS entry point**: Framework feedback section strengthened with non-negotiable enforcement chain (self-eval flags it, shutdown routes it, completion gate blocks without it)

### Feedback Enforcement

- **`pas-session-start.sh`** (new SessionStart hook): Injects PAS lifecycle context at session start — workspace creation requirements, task creation requirements, shutdown sequence. Also reports active workspace status for session resumption.
- **`verify-completion-gate.sh`** (new Stop hook): Blocks Claude from stopping (exit 2) when all phases are completed but `feedback/orchestrator.md` is missing. Includes `stop_hook_active` loop prevention.
- **`verify-task-completion.sh`** (new TaskCompleted hook): Blocks `[PAS]`-prefixed tasks from completing until deliverables exist on disk. Enforces self-evaluation, status finalization, and workspace initialization.
- **`check-self-eval.sh`** (enhanced SubagentStop hook): Changed from warning-only (exit 0 + log file) to blocking (exit 2 + stderr feedback). Subagents can no longer stop without writing self-evaluation.
- **hooks.json restructured**: 5 hook registrations across 4 lifecycle events (SessionStart, SubagentStop, TaskCompleted, Stop). Completion gate runs before feedback routing.
- **Task creation in orchestration patterns**: All 4 patterns now create `[PAS]`-prefixed Claude Code tasks at startup for each phase + shutdown steps. Tasks are enforced by hooks.
- **Session tracking**: Feedback files use session-specific filenames (`orchestrator-{session_id}.md`). Stop hook verifies feedback from the current session, not a previous one.

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
