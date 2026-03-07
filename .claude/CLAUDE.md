# PAS Framework — Development Branch

This is the development workspace for PAS (Process-Agent-Skill). The plugin source lives alongside the pas-development process, plans, workspace, and feedback.

## Branch Structure

- `main` — Plugin distribution (clean, release-only)
- `dev` — Development workspace (this branch)

All PAS plugin development happens on `dev`. Issues get applied here, tested, validated, and eventually merged into `main` for release.

## Repo Layout

- `plugins/pas/` — The PAS plugin (skills, hooks, library, processes)
- `processes/pas-development/` — The PAS development process (7 agents, 4 phases)
- `library/` — Bootstrapped library (copied from plugin for local use)
- `workspace/` — Session workspaces (status tracking, feedback)
- `docs/plans/` — Design docs and implementation plans
- `.claude/skills/pas-development/` — Thin launcher for the dev process
- `pas-config.yaml` — Local PAS configuration
- `.claude-plugin/marketplace.json` — Marketplace catalog

## Plugin Structure

- `plugins/pas/skills/pas/SKILL.md` — `/pas` entry point with intelligent routing
- `plugins/pas/hooks/` — Hook scripts and configuration (self-eval check, feedback routing)
- `plugins/pas/library/` — Global skills (orchestration, self-evaluation, message-routing)
- `plugins/pas/processes/pas/` — PAS self-management process (orchestrator with 4 skills)
- `plugins/pas/pas-config.yaml` — Framework configuration (feedback toggle)

## PR Scope

PRs are for direct PAS plugin changes only — files under `plugins/pas/`. Everything else (`library/` mirrors, root `CHANGELOG.md`, `docs/plans/`, workspace artifacts) gets committed directly to `dev`. This keeps PRs focused on reviewable plugin upgrades.

**In a feature branch PR:** only `plugins/pas/` changes.
**On dev directly:** `library/` mirror syncs, changelogs, plans, workspace, feedback.

## Conventions

- Every artifact (process, agent, skill) has `feedback/backlog/` and `changelog.md`
- Skills follow Agent Skills spec (SKILL.md format with YAML frontmatter + progressive disclosure markdown)
- Agents are always process-local (no shared agents across processes)
- Skills are local-first; only graduate to `library/` when reused in 2+ places
- PAS framework feedback always goes to a GitHub issue — no exceptions
- pas-development process feedback stays local in `processes/pas-development/feedback/backlog/`
