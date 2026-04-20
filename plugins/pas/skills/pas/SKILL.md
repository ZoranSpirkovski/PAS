---
name: pas
description: Use when creating, managing, or improving processes, agents, and skills. The single entry point for the PAS framework.
---

## Marketplace Gate

**PAS-the-skill operates only inside a marketplace repository** — a git repo containing `.claude-plugin/marketplace.json` at the root. PAS is the tool for maintaining the marketplace your skills live in: creating skills, improving processes, developing them, implementing issues. Skills created with PAS run anywhere via Claude Code's plugin system; but the creation/maintenance workflow happens in the marketplace repo.

Before proceeding, resolve the current marketplace:

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/guards.sh"
MARKETPLACE_ROOT=$(resolve_marketplace_root)
```

**If `resolve_marketplace_root` succeeds**, export `PAS_MARKETPLACE_ROOT="$MARKETPLACE_ROOT"` and proceed.

**If it fails** (current directory is not inside a marketplace), STOP and present three options via AskUserQuestion:

1. **`cd` to an existing marketplace** — list registered marketplaces from `~/.claude/plugins/known_marketplaces.json` (use `jq -r 'to_entries[] | "\(.key)\t\(.value.installLocation)"'`). Ask the user to choose one or provide a path.
2. **Bootstrap a new marketplace here** — read `${CLAUDE_SKILL_DIR}/../bootstrap-marketplace/SKILL.md` and invoke the scaffold.
3. **Exit** — do nothing.

Do NOT run creation/modification skills outside a marketplace. The hooks (feedback routing) run everywhere PAS is installed regardless — this gate applies only to the `/pas` entry-point skill.

---

Read `${CLAUDE_SKILL_DIR}/../../processes/pas/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_SKILL_DIR}/../../library/orchestration/` as specified in the process.

## Project Convention

Under the marketplace-authoritative model (PAS ≥ 1.4.0):

- **Marketplace (`$PAS_MARKETPLACE_ROOT`)** — holds plugins, skills, processes, library content. Source of truth.
- **Consumer `.pas/workspace/`** — execution instances, status tracking, session feedback. Lives in the project where the skill was *used*, not where it was authored.

Older projects may still have consumer-side `.pas/processes/` or `.pas/config.yaml` from PAS ≤ 1.3.x — the upgrading skill handles migration.

## Quick Routing

Based on the user's message, read the appropriate skill from `${CLAUDE_SKILL_DIR}/../../processes/pas/agents/orchestrator/skills/`:

- **Creating something new** (process, pipeline, workflow): read `creating-processes/SKILL.md`
- **Creating hooks** (hook, lifecycle, guard, automation, when something happens): read `creating-hooks/SKILL.md`
- **Applying feedback** (upgrade, improve, what feedback exists): read `applying-feedback/SKILL.md`
- **Upgrading** (upgrade, update, migrate, what's new, check setup): read `upgrading/SKILL.md`
- **Modifying existing** (change, update, add phase): find the target in `.pas/processes/` or `.pas/library/`, read it, then use creation skills to apply the modification
- **Running a process** (run article, start pipeline): point to thin launcher (e.g., `/article`)
- **Visualizing a process** (visualize, overview, view, HTML, diagram): read `${CLAUDE_SKILL_DIR}/../../library/visualize-process/SKILL.md`
- **Information query** (what exists, status, list): survey `.pas/processes/`, `.pas/library/`, `.pas/workspace/`

## Conversation Style

- Brainstorming mode: explore the goal before committing to a solution
- One question at a time: never ask multiple questions in one message
- Never assume you understand what the user wants — ask clarifying questions until they confirm.
- No PAS jargon unless the user uses it first. Speak in terms of goals, tasks, and steps.

## First-Run Detection (consumer)

Under the marketplace-authoritative model, a **consumer project** holds only `.pas/workspace/` — nothing else. Hooks and skills create `.pas/workspace/` lazily on first write (no eager `.pas/config.yaml` creation).

Feedback enabled/disabled defaults to the plugin-level setting at `${CLAUDE_PLUGIN_ROOT}/pas-config.yaml`. To override per-project, drop a workspace-scoped config with `feedback: disabled` (location TBD in a future cycle; legacy consumer `.pas/config.yaml` is still honored for backward compatibility).

Legacy projects: if old-style `pas-config.yaml` exists at root, auto-migrate moves it into `.pas/config.yaml` (unchanged from earlier behavior). Consumer-side `.pas/config.yaml` is **deprecated as of PAS 1.4.0** and will be removed in a future cycle after downstream consumers upgrade.

Hooks (`check-self-eval.sh`, `route-feedback.sh`) are loaded automatically by Claude Code from the plugin's `hooks/hooks.json` — no project-level configuration needed.

## Frustration Detection

If `.pas/config.yaml` shows `feedback: disabled` and the user expresses frustration about repeated issues, offer to re-enable feedback collection.

## Library Bootstrap

Processes reference the plugin library directly via `${CLAUDE_PLUGIN_ROOT}/library/` — no copying needed. The library lives in the plugin and is always available at runtime.

## Framework Feedback

Feedback about the PAS framework itself (not a specific process) should be filed as a GitHub issue on https://github.com/ZoranSpirkovski/PAS. Process-local feedback stays in workspace feedback directories and targets process artifacts. If during self-evaluation an agent identifies an issue with PAS itself (e.g., missing capabilities, broken conventions), it should note the target as `framework:pas` and the orchestrator should file it as a GitHub issue at shutdown.
