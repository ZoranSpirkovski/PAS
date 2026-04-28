# Cycle Modes, Upgrade Skill, Auto-Offer Design

**Status:** Approved
**Created:** 2026-03-10
**Context:** Cycle 13 — improve pas-development launcher, add quick cycle process, upgrade skill, auto-offer

---

## 1. Launcher Improvement (`/pas-development` skill)

The skill presents 3 options before loading any process:

1. **Full cycle** — multi-agent teams, brainstorming available at discovery entry, discussion pattern, full ceremony
2. **Quick cycle** — solo orchestrator with superpowers skills, no agent spawning
3. **Resume** — reads latest workspace status.yaml, continues

If user picks Full cycle, they get a follow-up:
- **Direct directive** — "I know what I want"
- **Signal-driven** — agents discover from feedback/roadmap
- **Brainstorm** — interactive brainstorming skill to define the directive, then agents pressure-test it

If user passes a directive as an argument, it carries through to whichever mode they pick.

## 2. Quick Cycle Process

A new process created via `/pas:pas` under pas-development. Same 5 phases (discovery → planning → execution → validation → release) but:

- **Discovery**: Brainstorming skill with user (no agent team)
- **Planning**: Writing-plans skill (no framework-architect agent)
- **Execution**: Dispatching-parallel-agents or subagent-driven-development
- **Validation**: Verification-before-completion skill
- **Release**: Finishing-a-development-branch + pr-management

Solo orchestration pattern. The orchestrator IS the operator, using superpowers skills as its toolkit.

## 3. Upgrade Skill (`/pas:pas upgrade`)

Declarative approach — defines what current PAS expects, scans, fixes gaps.

### Expected state checklist

- Config at `.pas/config.yaml` (not root-level `pas-config.yaml`)
- Workspace at `.pas/workspace/`
- No `.pas/library/` directory (processes use `${CLAUDE_PLUGIN_ROOT}/library/` directly)
- Thin launchers in `.claude/skills/` reference `${CLAUDE_PLUGIN_ROOT}/library/`, not `.pas/library/`
- Process lifecycle sections reference `${CLAUDE_PLUGIN_ROOT}/library/`

### Flow

1. Scan project for PAS artifacts (config, processes, library, thin launchers)
2. Diff against expected state checklist
3. Show what needs fixing with before/after preview
4. User confirms
5. Apply fixes (back up originals first)
6. Report what changed

Non-destructive: backs up before modifying. User always confirms before changes.

### Routing

Added to `/pas` skill Quick Routing:
- **Upgrading** (upgrade, update, migrate, what's new): read `upgrading/SKILL.md`

## 4. Auto-Offer (`pas-session-start.sh`)

Extend the existing SessionStart hook output with a brief instruction:

> When the user wants to create a process, agent, skill, or workflow — offer `/pas:pas` as the tool to do it. PAS provides structured creation with brainstorming, proper scaffolding, and feedback integration.

This makes Claude aware that PAS is the right tool for creation tasks, without requiring users to know about `/pas` upfront.

## Files to Create/Modify

### New files (plugin — PR)
- `.pas/processes/pas-development/modes/quick.md` — quick cycle mode definition
- `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md` — upgrade skill
- Quick cycle process artifacts (created via `/pas:pas`)

### Modified files (plugin — PR)
- `plugins/pas/skills/pas/SKILL.md` — add upgrade routing
- `plugins/pas/hooks/pas-session-start.sh` — add auto-offer instruction

### Modified files (dev-only)
- `.claude/skills/pas-development/SKILL.md` — launcher with 3 options
