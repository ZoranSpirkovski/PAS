# PAS Framework

This is the canonical repository for PAS (Process-Agent-Skill). Users install from here. PAS is distributed as a Claude Code plugin.

## Branch Structure

- `main` — Plugin distribution (clean, release-only)
- `dev` — Development workspace (pas-development process, plans, workspace, feedback)

Development happens on `dev`. Plugin changes get PR'd to `main`. `main` never merges from `dev`.

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
- PAS framework feedback always goes to a GitHub issue — no exceptions
