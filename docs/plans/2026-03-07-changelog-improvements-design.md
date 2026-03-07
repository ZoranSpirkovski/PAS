# PAS v1.2.0 — Changelog-Driven Improvements Design

**Date:** 2026-03-07
**Scope:** Integrate Claude Code capabilities from changelogs v0.2.x through v2.1.71 into PAS framework

## Problem

The PAS framework (v1.1.0) was built against an earlier version of Claude Code. Analysis of 70+ changelog releases revealed new capabilities that PAS should leverage, and confirmed no breaking changes affect us.

## Design Decision: What to Change

Six improvements were identified. P1 (hook script updates) and P2 (agent-level hook declarations) are **deferred** to a parallel process handling definitive hook changes. This design covers P3-P6.

---

## P3: Worktree Isolation Guidance

### What

Add `isolation: "worktree"` guidance to hub-and-spoke orchestration and agent creation. Since v2.1.49, subagents can work in isolated git worktrees, preventing file conflicts during parallel execution.

### Where

1. **`plugins/pas/library/orchestration/hub-and-spoke.md`** — New "Worktree Isolation" subsection after "Intra-Phase Parallel Dispatch > Spawn Prompt Requirements"
2. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/SKILL.md`** — Add `isolation: worktree` to agent.md frontmatter example, add note in Step 1

### Design

Add a decision framework for when to use worktree isolation:

**Use when:**
- Subagents edit the same files or directories
- Subagents run code producing side effects in the working tree
- Guaranteed clean state needed per subagent

**Don't use when:**
- Subagents only read files
- Subagents write to distinct output directories (default PAS workspace pattern)
- Solo orchestration

Note that worktree agents return changes on a branch — orchestrator must merge after all complete.

---

## P4: Agent Memory Frontmatter

### What

Document the `memory` frontmatter field (user/project/local scope) in agent creation guidance. Since v2.1.0, agents can persist learnings across sessions.

### Where

**`plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/SKILL.md`** — Add `memory: project` to frontmatter example, add guidance in Step 5

### Design

Position memory as complementary to feedback backlogs:
- **Memory** = operational learnings (how to run better)
- **Feedback backlogs** = artifact improvements (what to change in skills/agents)

Recommend `project` scope for process-specific agents. `user` scope for cross-project agents. `local` for experiments.

---

## P5: Task System as Primary Phase Tracker

### What

Make Claude Code's built-in Task system (TaskCreate/TaskUpdate) the primary orchestration tracker while keeping status.yaml as a durable backup that survives process termination.

### Where

1. **`plugins/pas/library/orchestration/hub-and-spoke.md`** — Rewrite "Status Tracking" to "Phase Tracking" with Task system primary, status.yaml backup
2. **`plugins/pas/library/orchestration/sequential-agents.md`** — Update status tracking reference
3. **`plugins/pas/library/orchestration/solo.md`** — Add TaskCreate mention in operator behavior
4. **`plugins/pas/library/orchestration/discussion.md`** — Add Task system mention in status tracking

### Design

**Task system (primary):**
- At startup: TaskCreate per phase with dependencies matching I/O from process.md
- At phase start/completion/error: TaskUpdate
- Benefits: UI visibility (/tasks), built-in dependency tracking, background execution

**status.yaml (durable backup):**
- Write at every state change (same as before)
- Source of truth for resumability (Task system doesn't persist across sessions)
- Historical record with quality scores, timing, attempt counts
- Performance data for hang detection

The dual-tracking approach means: Task system is the live dashboard, status.yaml is the flight recorder.

---

## P6: Monitoring Library Skill

### What

Create a new library skill at `library/monitoring/` that uses `/loop` for periodic status checks on long-running autonomous processes.

### Where

1. **New: `plugins/pas/library/monitoring/SKILL.md`**
2. **New: `plugins/pas/library/monitoring/changelog.md`**
3. **New: `plugins/pas/library/monitoring/feedback/backlog/.gitkeep`**
4. **Update: `plugins/pas/skills/pas/SKILL.md`** — Add monitoring to first-run bootstrap list

### Design

**Usage:** `/loop 5m /monitoring` — checks every 5 minutes (configurable)

**Checks performed:**
1. Read status.yaml from active workspace
2. Report phase progress (completed/in_progress/pending counts)
3. Hang detection: flag if in_progress phase exceeds 2x average completed duration
4. Feedback check: count unrouted feedback files
5. Error surfacing: phases with attempts > 1 or quality < 5

**Output format:**
- Brief one-liner per check: `[HH:MM] {process} - {completed}/{total} phases | Current: {phase} ({elapsed}) | Issues: {count}`
- Detailed output only when issues detected

**Hang thresholds:**
- 2x average = potential hang (flag)
- 5x average = likely hang (alert)

---

## Execution Order

1. P3: Worktree isolation (hub-and-spoke.md + creating-agents)
2. P4: Agent memory (creating-agents — sequential with P3 since same file)
3. P5: Task system (all 4 orchestration patterns — can parallelize)
4. P6: Monitoring skill (independent — create new files + update entry skill)
5. Version bump 1.1.0 -> 1.2.0, changelog entry

## Verification

1. Install plugin, run `/pas` — verify skill loads and routes correctly
2. Verify monitoring skill is in first-run bootstrap list
3. Check agent.md frontmatter examples have valid YAML
4. Read all 4 orchestration patterns — verify Task system guidance is consistent
5. Verify creating-agents workflow flows naturally with new sections
