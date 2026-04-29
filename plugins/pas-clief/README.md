# pas-clief

A script-free implementation of the PAS pattern (process / agent / skill) using Jake Van Clief's folder-as-workspace method.

## What this is

pas-clief is a sibling plugin to PAS. Same thinking model — process, agent, skill. Different runtime: pure markdown, no hooks, no `status.yaml`, no bash. Folder structure encodes everything; Claude's CLAUDE.md auto-loading provides shared context for free.

Choose pas-clief if you want:
- A personal workspace (no marketplace concept).
- Convention over enforcement.
- The Van Clief teaching applied: routing table, naming conventions, workspace isolation.
- A library + local pattern: canonical examples in this plugin, your own variants in your project.

Choose PAS-the-original if you want:
- Multi-agent orchestration with hook-enforced lifecycles.
- Auto-routing of feedback to GitHub.
- Marketplace distribution of your processes.

## Install

This plugin lives in the same marketplace as PAS. Enable it via your Claude Code marketplace settings.

## Quick start

1. `cd` to the project where you want a pas-clief workspace.
2. Run `/pas-clief:init`. The skill will brainstorm with you, then scaffold a tailored `CLAUDE.md`, library directories, and (optionally) your first process.
3. Open the workspace in a fresh `claude` session — your routing table is now part of every prompt.
4. When a new kind of work shows up, run `/pas-clief:add-process`.

## Slash commands

| Command | Purpose |
|---------|---------|
| `/pas-clief` | Main entry, intelligent router. |
| `/pas-clief:init` | Brainstorm + scaffold a fresh workspace. |
| `/pas-clief:add-agent` | Create a local agent in `library/agents/`. |
| `/pas-clief:add-skill` | Create a local skill in `library/skills/`. |
| `/pas-clief:add-process` | Create a local process in `.claude/skills/`. |
| `/pas-clief:upgrade` | Sync conventions from a newer plugin. |
| `/pas-clief:visualize` | Render a process flow as Mermaid. |
| `/pas-clief:newsletter` | Example library process. |

## Where things live

- `plugins/pas-clief/library/agents/` — canonical agents (reusable).
- `plugins/pas-clief/library/skills/` — canonical skills (capabilities used by agents and processes).
- `plugins/pas-clief/skills/` — slash-invokable entries (processes + creation/management skills).
- `<your-project>/library/agents/` and `library/skills/` — your local components.
- `<your-project>/.claude/skills/` — your local processes (slash-invokable as `/<name>`).
- `<your-project>/workspace/<process>/<session>/` — execution state.

## Path resolution

Plain names in process recipes search local first, then plugin. To force the plugin version when shadowed: `plugin:<name>`. To force a local: `local:<name>` (rarely needed).

## Spec & design

Full design at `docs/plans/2026-04-29-pas-clief-design.md` in this repo.

## License

MIT
