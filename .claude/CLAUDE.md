# PAS Framework

Process-Agent-Skill framework for building agentic workflows. Distributed as a Claude Code plugin marketplace.

## Repo Layout

- `plugins/pas/` — The PAS plugin (skills, hooks, library, processes)
- `.claude-plugin/marketplace.json` — Marketplace catalog for plugin distribution
- `.claude/` — Repo-level Claude Code configuration

## Plugin Structure

- `plugins/pas/skills/pas/SKILL.md` — `/pas` entry point with intelligent routing
- `plugins/pas/hooks/` — Hook scripts and configuration (self-eval check, feedback routing)
- `plugins/pas/library/` — Global skills (orchestration, self-evaluation, message-routing)
- `plugins/pas/processes/pas/` — PAS self-management process (orchestrator with 4 skills)
- `plugins/pas/pas-config.yaml` — Framework configuration (feedback toggle)

## Conventions

- Every artifact (process, agent, skill) has `feedback/backlog/` and `changelog.md`
- Skills follow Agent Skills spec (SKILL.md format with YAML frontmatter + progressive disclosure markdown)
- Agents are always process-local (no shared agents across processes)
- Skills are local-first; only graduate to `library/` when reused in 2+ places
