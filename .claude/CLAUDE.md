# PAS Framework — Development Branch

This is the development workspace for PAS (Process-Agent-Skill). The plugin source lives alongside the pas-development process, plans, workspace, and feedback.

## Branch Structure

- `main` — Plugin distribution (clean, release-only)
- `dev` — Development workspace (this branch)

All PAS plugin development happens on `dev`. Issues get applied here, tested, validated, and eventually merged into `main` for release.

## Repo Layout

- `plugins/pas/` — The PAS plugin (skills, hooks, library, processes — including `pas-development` as of 1.4.0)
- `.pas/` — Consumer-side workspace for this repo acting as a consumer of itself
  - `.pas/workspace/` — Session workspaces (status tracking, feedback)
  - `.pas/feedback/` — Framework-level feedback routing logs
- `docs/plans/` — Design docs and implementation plans
- `.claude/skills/pas-development/` — Thin launcher for the dev process (reads from `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/`)
- `.claude-plugin/marketplace.json` — Marketplace catalog

## Plugin Structure

- `plugins/pas/skills/pas/SKILL.md` — `/pas` entry point with intelligent routing
- `plugins/pas/skills/bootstrap-marketplace/` — Scaffold a new user-controlled marketplace
- `plugins/pas/hooks/` — Hook scripts and configuration (self-eval check, feedback routing)
- `plugins/pas/library/` — Global skills (orchestration, self-evaluation, message-routing, doctrines)
- `plugins/pas/processes/pas/` — PAS self-management process (orchestrator with 5 skills)
- `plugins/pas/processes/pas-development/` — The PAS development process itself (authoritative location as of 1.4.0)
- `plugins/pas/pas-config.yaml` — Framework configuration (feedback toggle, framework_signal_repo)

## PR Scope

PRs are for direct PAS plugin changes only — files under `plugins/pas/` plus `.claude-plugin/marketplace.json` (distribution artifact updated by the version auto-bump). Everything else (`.pas/` artifacts, `docs/plans/`, changelogs) gets committed directly to `dev`. This keeps PRs focused on reviewable plugin upgrades.

**In a feature branch PR:** `plugins/pas/` changes and `.claude-plugin/marketplace.json`.
**On dev directly:** `.pas/` workspace artifacts (no longer processes — those are in the plugin), changelogs, plans.

## Protected Files (dev branch)

NEVER delete or exclude these directories when merging, cleaning, or restructuring:

- `plugins/pas/processes/pas-development/` — The PAS development process (7 agents, 5 phases, quick sub-process). **Under 1.4.0 this is the authoritative location — migrated from `.pas/processes/pas-development/` in cycle-15.** DO NOT move it back or delete it.
- `.pas/workspace/` — Session workspaces and feedback (consumer-side artifacts for cycles running in this repo)

If a merge or cleanup removes them, restore immediately from git history.

## Development Workflow

Changes to the PAS plugin (`plugins/pas/`) should go through `/pas-development` rather than ad-hoc edits. The development process provides multi-agent discovery, structured planning, validation, and feedback collection that direct edits skip. Native plan mode works for quick exploration, but for shipping changes, use the process.

## Conventions

- Every artifact (process, agent, skill) has `feedback/backlog/` and `changelog.md`
- Skills follow Agent Skills spec (SKILL.md format with YAML frontmatter + progressive disclosure markdown)
- Agents are always process-local (no shared agents across processes)
- Skills are local-first; only graduate to `plugins/pas/library/` when reused in 2+ places
- PAS framework feedback always goes to a GitHub issue — no exceptions
- pas-development process feedback now lives in `plugins/pas/processes/pas-development/.../feedback/backlog/` (migrated in cycle-15)
