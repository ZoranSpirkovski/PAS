# Cycle Modes, Upgrade Skill, Auto-Offer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add cycle mode selection to pas-development launcher, create quick cycle process, add upgrade skill, and auto-offer PAS for creation tasks.

**Architecture:** Four independent changes: (1) launcher skill with mode routing, (2) quick cycle process via pas-create-process, (3) upgrade skill as new orchestrator skill, (4) session-start hook context injection.

**Tech Stack:** Bash (hooks), Markdown (skills/processes), PAS conventions

---

### Task 1: Auto-Offer in SessionStart Hook

**Files:**
- Modify: `plugins/pas/hooks/pas-session-start.sh:63-86`
- Test: `plugins/pas/hooks/tests/test-hooks.sh`

**Step 1: Add auto-offer text to session-start output**

In `plugins/pas/hooks/pas-session-start.sh`, add the following lines after the `ENFORCEMENT` line (line 85) and before the `EOF` on line 86:

```bash
CREATION ROUTING: When the user wants to create a process, agent, skill, or workflow, offer /pas:pas as the tool to do it. PAS provides structured creation with brainstorming, proper scaffolding, and feedback integration.
```

**Step 2: Add test assertion**

In `plugins/pas/hooks/tests/test-hooks.sh`, find the session-start test section. Add:

```bash
assert_stdout_contains "$OUT" "CREATION ROUTING" \
  "session-start: outputs creation routing instruction"
```

**Step 3: Run tests**

Run: `bash plugins/pas/hooks/tests/test-hooks.sh`
Expected: All tests pass including the new assertion.

**Step 4: Commit**

```bash
git add plugins/pas/hooks/pas-session-start.sh plugins/pas/hooks/tests/test-hooks.sh
git commit -m "Add auto-offer for /pas:pas on creation intent"
```

---

### Task 2: Upgrade Skill

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md`
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/changelog.md`
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/feedback/backlog/.gitkeep`
- Modify: `plugins/pas/skills/pas/SKILL.md:19-29` (add routing entry)

**Step 1: Create upgrade skill directory**

```bash
mkdir -p plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/feedback/backlog
touch plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/feedback/backlog/.gitkeep
```

**Step 2: Write the upgrade skill**

Create `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md`:

```markdown
---
name: upgrading
description: Scan a PAS project and fix any gaps between its current state and what the installed plugin version expects.
---

# Upgrading PAS Projects

Declarative upgrade: define what PAS expects, scan the project, fix gaps. No version tracking needed — just "does your setup match what the current plugin expects?"

## When to Use

- User says "upgrade", "update", "migrate", or "what's new"
- User reports errors that suggest outdated project layout
- After a PAS plugin update

## Expected State Checklist

The current PAS plugin expects these conditions. Each item has a check and a fix.

### 1. Config location

- **Expected:** `.pas/config.yaml` exists
- **Legacy:** `pas-config.yaml` at project root (no `.pas/` directory)
- **Fix:** Create `.pas/` directory, move `pas-config.yaml` to `.pas/config.yaml`

### 2. Workspace location

- **Expected:** `.pas/workspace/` exists
- **Legacy:** `workspace/` at project root
- **Fix:** Move `workspace/` to `.pas/workspace/`

### 3. Processes location

- **Expected:** `.pas/processes/` contains process definitions
- **Legacy:** `processes/` at project root
- **Fix:** Move `processes/` to `.pas/processes/`

### 4. No local library copy

- **Expected:** No `.pas/library/` directory (processes reference `${CLAUDE_PLUGIN_ROOT}/library/` directly)
- **Legacy:** `.pas/library/` or `library/` with copied plugin skills
- **Fix:** Update thin launchers and process lifecycle sections to use `${CLAUDE_PLUGIN_ROOT}/library/`, then remove the local library copy. Back up to `.pas/library.bak/` before deleting.

### 5. Thin launcher references

- **Expected:** `.claude/skills/*/SKILL.md` files reference `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` for lifecycle and patterns
- **Legacy:** References to `.pas/library/orchestration/` or `library/orchestration/`
- **Fix:** Find and replace old library paths with `${CLAUDE_PLUGIN_ROOT}/library/` in each thin launcher

### 6. Process lifecycle references

- **Expected:** `process.md` lifecycle sections reference `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md`
- **Legacy:** References to `.pas/library/orchestration/lifecycle.md`
- **Fix:** Find and replace in each `process.md`

## Workflow

1. **Scan** — Check each item in the checklist against the project
2. **Report** — Show a table: item, status (OK/NEEDS FIX), what will change
3. **Confirm** — Ask user: "Apply these fixes?" (never auto-apply without confirmation)
4. **Back up** — Before modifying, copy affected files/dirs to `.bak` suffixed locations
5. **Apply** — Execute fixes in checklist order
6. **Verify** — Re-scan to confirm all items now pass
7. **Report** — Show final status: what changed, what was backed up

## Key Principles

- Non-destructive: always back up before modifying
- Idempotent: running upgrade twice produces no changes the second time
- User confirms before any modifications
- Show before/after for each change
```

**Step 3: Create changelog**

Create `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/changelog.md`:

```markdown
# Upgrading Changelog
```

**Step 4: Add routing entry to /pas skill**

In `plugins/pas/skills/pas/SKILL.md`, add a new routing entry after the "Applying feedback" line (line 25):

```markdown
- **Upgrading** (upgrade, update, migrate, what's new, check setup): read `upgrading/SKILL.md`
```

**Step 5: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/ plugins/pas/skills/pas/SKILL.md
git commit -m "Add upgrade skill for declarative PAS project migration"
```

---

### Task 3: Quick Cycle Process

**Files:**
- Create: `.pas/processes/pas-development-quick/` (via `pas-create-process` script)
- Customize: `.pas/processes/pas-development-quick/process.md`
- Create: `.pas/processes/pas-development-quick/agents/orchestrator/agent.md`

**Step 1: Generate process scaffold**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process \
  --name pas-development-quick \
  --goal "Evolve the PAS framework using superpowers skills for fast iteration without multi-agent teams" \
  --orchestration solo \
  --phase "discovery:orchestrator:directive OR roadmap:workspace/pas-development-quick/{slug}/discovery/priorities.md:product owner approves priorities" \
  --phase "planning:orchestrator:discovery/priorities.md:workspace/pas-development-quick/{slug}/planning/implementation-plan.md:product owner approves plan" \
  --phase "execution:orchestrator:planning/implementation-plan.md:workspace/pas-development-quick/{slug}/execution/changes/:product owner reviews changes" \
  --phase "validation:orchestrator:execution/changes/:workspace/pas-development-quick/{slug}/validation/report.md:product owner approves release" \
  --phase "release:orchestrator:validation/report.md:PR URL:product owner confirms merge" \
  --input "directive:optional owner directive for what to work on this cycle" \
  --description "A lightweight version of pas-development that uses superpowers skills instead of multi-agent teams. Same 5 phases, solo orchestrator, faster iteration." \
  --sequential true
```

**Step 2: Customize the generated process.md**

Edit `.pas/processes/pas-development-quick/process.md` to add superpowers skill mappings in the body section. After the generated phase descriptions, replace the Lifecycle section with:

```markdown
## Superpowers Skill Mapping

Each phase uses a specific superpowers skill instead of spawning agent teams:

| Phase | Superpowers Skill | What It Does |
|-------|------------------|--------------|
| Discovery | `superpowers:brainstorming` | Interactive session with user to define directive |
| Planning | `superpowers:writing-plans` | Produce scoped implementation plan |
| Execution | `superpowers:dispatching-parallel-agents` or `superpowers:subagent-driven-development` | Dispatch work items from plan |
| Validation | `superpowers:verification-before-completion` | Verify changes against plan |
| Release | `superpowers:finishing-a-development-branch` | Commit, branch, PR via pr-management |

## Lifecycle

This process follows the shared lifecycle protocol. Read `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md` for:

- Workspace creation and status tracking
- Task creation (required — create a Claude Code task for each phase)
- Shutdown sequence and completion gate
- Ready handshake for multi-agent patterns
```

**Step 3: Create orchestrator agent**

Create `.pas/processes/pas-development-quick/agents/orchestrator/agent.md`:

```markdown
---
name: orchestrator
description: Solo orchestrator for quick PAS development cycles — uses superpowers skills instead of multi-agent teams
tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
skills:
  - ${CLAUDE_PLUGIN_ROOT}/library/self-evaluation/SKILL.md
---

# Quick Cycle Orchestrator

## Identity

You are the solo operator for quick PAS development cycles. You use superpowers skills as your toolkit — brainstorming for discovery, writing-plans for planning, parallel dispatch for execution, verification for validation, and the pr-management skill for release.

## Behavior

- In Discovery: invoke `superpowers:brainstorming` to explore what to work on with the user. If the user provided a directive, use it as the starting point.
- In Planning: invoke `superpowers:writing-plans` to produce a scoped plan.
- In Execution: invoke `superpowers:dispatching-parallel-agents` or `superpowers:subagent-driven-development` to implement the plan.
- In Validation: invoke `superpowers:verification-before-completion` to verify changes.
- In Release: follow the pr-management skill from `.pas/processes/pas-development/agents/community-manager/skills/pr-management/SKILL.md`
- At Shutdown: write self-evaluation using the self-evaluation library skill.

## Key Differences from Full Cycle

- No TeamCreate, no multi-agent discussion, no agent spawning
- You interact directly with the user at discovery (brainstorming) and gates
- Superpowers skills handle the methodology; you handle the PAS conventions
```

**Step 4: Commit**

```bash
git add .pas/processes/pas-development-quick/
git commit -m "Add quick cycle process for superpowers-driven PAS development"
```

---

### Task 4: Launcher Improvement

**Files:**
- Modify: `.claude/skills/pas-development/SKILL.md`

**Step 1: Rewrite the launcher skill**

Replace the contents of `.claude/skills/pas-development/SKILL.md` with:

```markdown
---
name: pas-development
description: Evolve the PAS plugin — choose between full multi-agent cycles, quick superpowers-driven cycles, or resume a previous cycle.
---

## Mode Selection

Before loading any process, present these options to the user:

1. **Full cycle** — Multi-agent teams with brainstorming at key touchpoints. Best for complex changes needing diverse perspectives.
2. **Quick cycle** — Solo orchestrator using superpowers skills. Best for focused changes where you know what to do.
3. **Resume** — Continue an interrupted cycle from where it left off.

Ask: "Which mode? (1) Full cycle, (2) Quick cycle, (3) Resume"

If the user passed arguments (a directive), carry them through to whichever mode is chosen.

## Routing

### Full cycle

Ask the user how they want to start discovery:
- **Direct directive** — user already knows what they want to work on
- **Signal-driven** — discover from accumulated feedback and roadmap
- **Brainstorm** — invoke `superpowers:brainstorming` to interactively define the directive, then proceed

Then:
Read `.pas/processes/pas-development/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` as specified in the process.
Execute.

After multi-agent discovery completes, if the findings surface complexity or trade-offs that weren't anticipated, offer a follow-up brainstorming session with the user before proceeding to planning.

### Quick cycle

Read `.pas/processes/pas-development-quick/process.md` for the process definition.
Read the orchestration pattern from `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` as specified in the process.
Execute.

### Resume

Find the most recent workspace under `.pas/workspace/pas-development/` or `.pas/workspace/pas-development-quick/` with `status: in_progress` in status.yaml.
Read that process's definition and orchestration pattern.
Resume from the last completed phase.
```

**Step 2: Commit**

```bash
git add .claude/skills/pas-development/SKILL.md
git commit -m "Add mode selection to pas-development launcher"
```

---

### Task 5: Final Integration Test

**Step 1: Run hook tests**

Run: `bash plugins/pas/hooks/tests/test-hooks.sh`
Expected: All tests pass.

**Step 2: Verify upgrade skill is routable**

Check that `/pas` skill routing includes the new "Upgrading" entry:
```bash
grep -n "Upgrading" plugins/pas/skills/pas/SKILL.md
```
Expected: Line with "upgrade, update, migrate" routing.

**Step 3: Verify quick cycle process exists**

```bash
test -f .pas/processes/pas-development-quick/process.md && echo "OK" || echo "MISSING"
```

**Step 4: Verify launcher has 3 options**

```bash
grep -c "Full cycle\|Quick cycle\|Resume" .claude/skills/pas-development/SKILL.md
```
Expected: 6+ matches (options appear multiple times).

**Step 5: Push to dev**

```bash
git push origin dev
```
