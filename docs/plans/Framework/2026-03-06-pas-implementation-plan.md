# PAS Framework Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the current monolithic article pipeline into the PAS (Process, Agent, Skill) framework as designed in `docs/plans/2026-03-05-pas-framework-design.md` (v6).

**Architecture:** PAS decomposes the monolithic `/article` skill into composable processes, agents, and skills with recursive feedback. Each process owns its agents and skills locally. A global library holds only skills with proven reuse. Feedback is collected via structured signals (PPU/OQI/GATE/STA), routed mechanically by a shell script, and applied by an intelligent applicator skill.

**Tech Stack:** Markdown (skills, agents, processes), YAML (process definitions, status tracking, config), Bash (hook scripts), Claude Code platform (hooks, TeamCreate, Agent tool)

**Source of truth:** `docs/plans/2026-03-05-pas-framework-design.md`

---

## Phase 0: Foundation (Repo Split)

Immediate clean break. Move old system to `legacy/`, scaffold PAS directories.

### Task 0.1: Move legacy files to `legacy/`

**Files to move (preserving internal structure):**

| Source | Destination |
|---|---|
| `.claude/agents/*.md` (5 files) | `legacy/.claude/agents/` |
| `.claude/skills/article/` | `legacy/.claude/skills/article/` |
| `.claude/skills/article-upgrade/` | `legacy/.claude/skills/article-upgrade/` |
| `.claude/skills/songwriting/` | `legacy/.claude/skills/songwriting/` |
| `prompts/` (entire) | `legacy/prompts/` |
| `config/` (entire) | `legacy/config/` |
| `workspace/` (entire) | `legacy/workspace/` |
| `existing_prompts/` (entire) | `legacy/existing_prompts/` |
| `experiments/` (entire) | `legacy/experiments/` |
| `tools/` (entire) | `legacy/tools/` |
| `feedback/` (entire) | `legacy/feedback/` |
| `other/` (entire) | `legacy/other/` |

**Files that stay (NOT moved):**
- `.claude/CLAUDE.md` — stays, will be updated
- `.claude/settings.local.json` — stays
- `reference/` — stays at root (global reference docs)
- `docs/` — stays at root
- `.gitignore`, `.venv/` — stay

**Step 1:** `mkdir -p legacy` and `git mv` all files listed above

**Step 2:** Remove now-empty directories (`.claude/agents/`, `.claude/skills/article/`, etc.)

**Step 3:** Commit

```bash
git add -A && git commit -m "Phase 0: Move old pipeline to legacy/ for PAS clean break"
```

### Task 0.2: Scaffold PAS directory structure

**Create directories:**
```
processes/.gitkeep
library/orchestration/.gitkeep
library/self-evaluation/.gitkeep
library/message-routing/.gitkeep
workspace/.gitkeep
.claude/skills/pas/
.claude/hooks/
```

**Create:** `pas-config.yaml`
```yaml
feedback: enabled
feedback_disabled_at: ~
```

### Task 0.3: Update `.claude/CLAUDE.md`

Replace current content to reflect PAS structure:
- Reference `/pas` as framework entry point
- Update repo layout to show `processes/`, `library/`, `workspace/`, `pas-config.yaml`
- Note old system archived in `legacy/`
- Keep publication config conventions
- Update workspace path convention to `workspace/{process}/{slug}/`

```bash
git add -A && git commit -m "Phase 0: Scaffold PAS directories, config, update CLAUDE.md"
```

---

## Phase 1: Process Creation Skill + Orchestration Library

**Design doc ref:** "creating-processes.md" section, "Process Definition Format", "Process Execution Engine"

### Task 1.1: Create orchestration library skills

**Files to create:**
- `library/orchestration/SKILL.md` — Decision guide: when to use which pattern
- `library/orchestration/hub-and-spoke.md` — Central hub execution rules, spawn order, status tracking, error chain, shutdown sequence
- `library/orchestration/discussion.md` — Multi-agent discussion, moderator role
- `library/orchestration/solo.md` — Single-agent operation
- `library/orchestration/sequential-agents.md` — One agent at a time, handoff rules

Each skill gets `feedback/backlog/.gitkeep` and `changelog.md`.

**Content for hub-and-spoke.md** (primary pattern, most detailed):
- Orchestrator reads process.md and spawns team members via TeamCreate
- Orchestrator infers parallelism from I/O dependencies
- Status tracking: write status.yaml continuously (pending/in_progress/completed with rich metadata)
- Error chain: agent self-recovers → orchestrator monitors for hangs → retry once → escalate
- Partial output quarantined to `partial/`
- Shutdown: complete phases → send downstream feedback → agents write self-eval → all shutdown → finalize status.yaml
- Gate protocol for supervised mode

```bash
git add library/orchestration/ && git commit -m "Phase 1: Orchestration library skills"
```

### Task 1.2: Create `creating-processes.md`

**File:** `.claude/skills/pas/creating-processes.md`

**Workflow steps:**
1. Clarify the goal (crystal clarity principle, one question at a time)
2. Design phases (input/output per phase, infer parallelism from I/O)
3. Determine agents (minimum viable set, start lean)
4. Select orchestration pattern (read `library/orchestration/SKILL.md`)
5. Scaffold process directory:
   ```
   processes/{name}/
     process.md
     agents/{orchestrator + specialists}/
     modes/supervised.md, autonomous.md
     config/, reference/, tools/
     feedback/backlog/
     changelog.md
   ```
6. Write process.md (YAML frontmatter: name, goal, version, orchestration, sequential, modes, phases with input/output/gate, status_file)
7. Create agents (invoke creating-agents.md for each)
8. Create mode files (structured header + prose behavior)
9. Create thin launcher in `.claude/skills/{name}/SKILL.md`
10. Create test scenario (integration test for the process)

```bash
git add .claude/skills/pas/creating-processes.md && git commit -m "Phase 1: Process creation skill"
```

---

## Phase 2: Agent Creation Skill

**Design doc ref:** "Agent Definition Format", "creating-agents.md", "Agent Lifecycle"

### Task 2.1: Create `creating-agents.md`

**File:** `.claude/skills/pas/creating-agents.md`

**Workflow steps:**
1. Determine role (name, description, tools, orchestrator vs specialist)
2. Check for overlap with existing agents in the process
3. Determine skills (invoke creating-skills.md for each)
4. Select model tier (based on role complexity)
5. Write agent.md (YAML frontmatter: name, description, tools, skills list; prose: identity, behavior, deliverables, known pitfalls)
6. Scaffold agent directory:
   ```
   processes/{process}/agents/{name}/
     agent.md
     skills/{skill-name}/SKILL.md ...
     feedback/backlog/
     changelog.md
   ```
7. Create agent eval scenario

**Orchestrator-specific additions:**
- Tools MUST include: Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Agent, SendMessage, TeamCreate
- Reads process.md + orchestration pattern
- Handles phases directly or delegates
- Global skills: library/self-evaluation/SKILL.md (when feedback enabled)

```bash
git add .claude/skills/pas/creating-agents.md && git commit -m "Phase 2: Agent creation skill"
```

---

## Phase 3: Skill Creation Skill

**Design doc ref:** "creating-skills.md", "Skill Granularity"

### Task 3.1: Create `creating-skills.md`

**File:** `.claude/skills/pas/creating-skills.md`

**Workflow steps:**
1. Determine purpose, consumers, degrees of freedom
2. Check for overlap (existing skills in agent/process + library/)
3. Apply granularity heuristics:
   - Feedback: can you improve parts independently? → split
   - Reuse: could another agent use one part? → split
   - Size: >5000 tokens → flag for evaluation
4. Write SKILL.md (Agent Skills spec format: YAML frontmatter + progressive disclosure markdown)
5. Scaffold skill directory (only create optional dirs when needed):
   ```
   {skill-name}/
     SKILL.md
     feedback/backlog/
     changelog.md
     scripts/      # only if needed
     references/   # only if needed
     evals/        # only if eval scenarios exist
   ```
6. Create skill eval (evals/evals.json with assertions)
7. Library graduation check (used in 2+ places → move to library/)

```bash
git add .claude/skills/pas/creating-skills.md && git commit -m "Phase 3: Skill creation skill"
```

---

## Phase 4: Feedback System

5 deliverables: self-evaluation skill, message-routing skill, feedback applicator, 2 hook scripts.

### Task 4.1: Create `library/self-evaluation/SKILL.md`

**File:** `library/self-evaluation/SKILL.md`

**Content:** The always-on feedback skill carried by all agents when feedback is enabled.

Key sections:
- **When:** Activates at shutdown step 3 (after downstream feedback, before final shutdown). Zero cost during work.
- **Four signal types** with exact format:
  - PPU: Target, Frequency, Evidence, Priority, Preference
  - OQI: Target, Degraded, Root Cause, Fix, Evidence, Priority
  - GATE: Target, Rejected Change, Why Rejected, Alternative, Evidence
  - STA: Target, Strength (CONFIRMED_BY_USER/OBSERVED), Behavior, Context
- **Saturation rule:** Smooth sessions → "No issues detected." No positive lists.
- **Recursive boundary:** Never feedback about feedback. User-initiated only.
- **Output location:** `workspace/{process}/{slug}/feedback/{agent-name}.md`

Also create: `library/self-evaluation/feedback/backlog/.gitkeep`, `library/self-evaluation/changelog.md`

```bash
git add library/self-evaluation/ && git commit -m "Phase 4.1: Self-evaluation global skill"
```

### Task 4.2: Create `library/message-routing/SKILL.md`

**File:** `library/message-routing/SKILL.md`

**Content:** Classifies user messages at gates. Used by orchestrator agents.

Classifications: Approval → proceed, Feedback → fix + queue signal, Question → answer + continue, Instruction → incorporate + continue.

Also create: `library/message-routing/feedback/backlog/.gitkeep`, `library/message-routing/changelog.md`

```bash
git add library/message-routing/ && git commit -m "Phase 4.2: Message routing global skill"
```

### Task 4.3: Create `applying-feedback.md`

**File:** `.claude/skills/pas/applying-feedback.md`

**Workflow steps:**
1. Survey backlogs recursively (processes/, library/)
2. Present accumulation summary
3. Ask user preference (apply all + remember, apply all once, just this, review first)
4. Sanity checks per signal: target validation, signal quality, duplicate detection, conflict with STAs
5. Pattern analysis: 3+ reports = strong, 2 HIGH = moderate
6. Resolve contradictions (most recent wins, frequency wins, context merge, escalate)
7. Apply with consolidation-first approach
8. Check STAs — warn if changes affect anchored behavior
9. Present diff for approval
10. Write changelog entry (dated, links to triggering signals)
11. Clear processed signals, commit

Quality tests: Efficiency, Accuracy, Alignment, UX.

```bash
git add .claude/skills/pas/applying-feedback.md && git commit -m "Phase 4.3: Feedback applicator skill"
```

### Task 4.4: Create hook scripts

**File:** `.claude/hooks/check-self-eval.sh` (SubagentStop safety net)
- Check if agent wrote self-eval file to workspace feedback inbox
- If missing: log warning to `feedback/warnings.log`
- If present: exit 0 (no-op)
- No LLM calls

**File:** `.claude/hooks/route-feedback.sh` (Stop, feedback routing)
- Guard: check if feedback files exist. If none, exit 0.
- For each .md file in workspace feedback inbox:
  - Parse `[PPU-NN]`, `[OQI-NN]`, `[GATE-NN]`, `[STA-NN]` signal blocks
  - Read `Target:` field from each signal
  - Route to target artifact's `feedback/backlog/` directory
  - Filename: `{date}-{source-file}-{signal-id}.md`
- Clean up workspace feedback inbox after routing
- Function definitions before main loop

Both scripts: `chmod +x`, `set -euo pipefail`

### Task 4.5: Configure hooks in settings.json

**File:** `.claude/settings.json` — Add hooks config for SubagentStop and Stop events pointing to the hook scripts. Verify exact format against Claude Code hook documentation.

```bash
git add .claude/hooks/ .claude/skills/pas/applying-feedback.md .claude/settings.json && git commit -m "Phase 4: Hook scripts, feedback applicator, settings"
```

### Task 4.6: Test feedback routing against legacy data

Manual TDD: copy a legacy feedback report to a mock workspace, run `route-feedback.sh`, verify routing. Test edge cases: missing Target, unknown target, empty file.

---

## Phase 5: `/pas` Entry Point

**Design doc ref:** "Entry Point: /pas Only", "First-Time User Experience"

### Task 5.1: Create `SKILL.md` (PAS router)

**File:** `.claude/skills/pas/SKILL.md`

**Content:** Intelligent router. Reads user message, applies crystal clarity principle, routes internally.

Routes:
- Process creation → read creating-processes.md
- Feedback application → read applying-feedback.md
- Process modification → read target process.md + use creation skills
- Process execution → point to thin launcher or execute
- Information → survey processes/, library/, workspace/

Additional:
- First-run detection: no pas-config.yaml → create with defaults
- Frustration detection: if feedback disabled and user frustrated → offer reactivation
- Conversation style: brainstorming, one question at a time, no PAS jargon unless user uses it

```bash
git add .claude/skills/pas/SKILL.md && git commit -m "Phase 5: /pas entry point with intelligent routing"
```

---

## Phase 6: Rebuild Article Pipeline

Use PAS creation skills to build `processes/article/`. Content adapted from `legacy/prompts/` and `legacy/.claude/agents/`.

### Task 6.1: Create process.md and mode files

**Files:**
- `processes/article/process.md` — Declarative YAML (name, goal, orchestration: hub-and-spoke, phases: sourcing→research→verification→writing→editorial→publishing with I/O deps and gates)
- `processes/article/modes/supervised.md` — Gates enforced
- `processes/article/modes/autonomous.md` — Gates advisory
- `processes/article/feedback/backlog/.gitkeep`
- `processes/article/changelog.md`

Start flat (no sub-processes). Add later when feedback indicates need.

### Task 6.2: Create orchestrator agent (adapted from editor)

**Source:** `legacy/.claude/agents/editor.md` + `legacy/prompts/sourcing.md` + `legacy/prompts/editorial-review.md`

**Files:**
- `processes/article/agents/orchestrator/agent.md`
- `processes/article/agents/orchestrator/skills/sourcing/SKILL.md` (from legacy/prompts/sourcing.md)
- `processes/article/agents/orchestrator/skills/editorial-review/SKILL.md` (from legacy/prompts/editorial-review.md)
- Each skill + agent gets `feedback/backlog/.gitkeep` and `changelog.md`

### Task 6.3: Create researcher agent

**Source:** `legacy/.claude/agents/researcher.md` + `legacy/prompts/research-planning.md` + `legacy/prompts/research-execution.md` + `legacy/prompts/internal-links.md`

**Files:**
- `processes/article/agents/researcher/agent.md`
- `processes/article/agents/researcher/skills/research-planning/SKILL.md`
- `processes/article/agents/researcher/skills/research-execution/SKILL.md`
- `processes/article/agents/researcher/skills/internal-links/SKILL.md`
- Each gets feedback/backlog/ and changelog.md

### Task 6.4: Create fact-checker agent

**Source:** `legacy/.claude/agents/fact-checker.md` + `legacy/prompts/verification.md`

**Files:**
- `processes/article/agents/fact-checker/agent.md`
- `processes/article/agents/fact-checker/skills/verification/SKILL.md`
- Feedback/changelog scaffolding

### Task 6.5: Create journalist agent

**Source:** `legacy/.claude/agents/journalist.md` + `legacy/prompts/writing.md` + `legacy/prompts/audit.md`

**Files:**
- `processes/article/agents/journalist/agent.md`
- `processes/article/agents/journalist/skills/writing/SKILL.md`
- `processes/article/agents/journalist/skills/audit/SKILL.md`
- Feedback/changelog scaffolding

### Task 6.6: Create publisher agent

**Source:** `legacy/.claude/agents/publisher.md` + `legacy/prompts/seo.md` + `legacy/prompts/image-generation.md` + `legacy/prompts/song-generation.md` + `legacy/prompts/distribution.md`

**Files:**
- `processes/article/agents/publisher/agent.md`
- `processes/article/agents/publisher/skills/seo/SKILL.md`
- `processes/article/agents/publisher/skills/image-generation/SKILL.md`
- `processes/article/agents/publisher/skills/song-generation/SKILL.md`
- `processes/article/agents/publisher/skills/distribution/SKILL.md`
- Feedback/changelog scaffolding

### Task 6.7: Move config, reference, and tools into process

- Copy `legacy/config/publications/` → `processes/article/config/publications/`
- Copy `reference/reuters-principles.md` → `processes/article/reference/`
- Copy `reference/reuters_handbook_of_journalism.md` → `processes/article/reference/`
- Copy `legacy/tools/make-video.sh` → `processes/article/tools/`
- Copy `legacy/tools/md2html.sh` → `processes/article/tools/`

Note: `reference/claude-code-capabilities.md` stays at project root (used by PAS itself). Suno/macedonian refs stay at root (future songwriting process).

### Task 6.8: Create thin launcher and workspace

- `.claude/skills/article/SKILL.md` — Points to `processes/article/process.md`
- `workspace/article/.gitkeep`

### Task 6.9: Commit article pipeline

```bash
git add processes/article/ .claude/skills/article/ workspace/article/ && git commit -m "Phase 6: Rebuild article pipeline as PAS process"
```

### Task 6.10: End-to-end verification

Run `/article` in supervised mode. Verify:
1. Workspace created at `workspace/article/{date-slug}/`
2. status.yaml written correctly
3. Orchestrator handles sourcing + editorial using own skills
4. Specialist agents spawn as team members
5. Each agent reads its agent.md and skills from process directory
6. Gates pause for review
7. Output files in correct locations
8. Self-eval files written at shutdown
9. Feedback routing hook fires

---

## Phase 7: Self-Hosting

### Task 7.1: Use `/pas` to create `processes/pas/`

Invoke `/pas`: "I want a process that helps users create and manage processes, agents, and skills."

PAS should scaffold itself as a process with orchestrator owning: creating-processes, creating-agents, creating-skills, applying-feedback as skills.

### Task 7.2: Migrate bootstrap to self-hosted

Move content from `.claude/skills/pas/creating-*.md` and `applying-feedback.md` into `processes/pas/agents/orchestrator/skills/`.

Update `.claude/skills/pas/SKILL.md` to be a thin launcher → `processes/pas/process.md`.

### Task 7.3: Verify self-hosted PAS

Test by creating a trivial new process. Verify same quality as bootstrap.

```bash
git add processes/pas/ .claude/skills/pas/ && git commit -m "Phase 7: Self-host PAS as processes/pas/"
```

---

## Phase 8: Activate Feedback Loop

### Task 8.1: Verify hooks fire correctly

Test SubagentStop and Stop hooks manually. Check Claude Code hook docs for exact format.

### Task 8.2: Run real article session

Run `/article` with real source, supervised mode. Provide deliberate feedback at a gate.

### Task 8.3: Verify full feedback cycle

1. Agent self-eval files exist in workspace feedback inbox
2. Session.md written by orchestrator
3. Stop hook routes signals to correct artifact backlogs
4. Workspace inbox cleaned up
5. `/pas` can survey and apply accumulated feedback
6. Changelog entries written correctly

### Task 8.4: Optional cleanup

If everything works: optionally delete `legacy/`, update CLAUDE.md references.

```bash
git commit -m "Phase 8: Activate feedback loop, verify end-to-end"
```

---

## Verification

- Phase 0: `legacy/` contains all old files, `processes/` and `library/` exist, `pas-config.yaml` exists
- Phase 1-3: PAS creation skills exist in `.claude/skills/pas/`, orchestration library populated
- Phase 4: Self-eval and message-routing skills in `library/`, hooks in `.claude/hooks/`, settings.json configured
- Phase 5: `/pas` routes correctly to creation/feedback/modification flows
- Phase 6: `processes/article/` fully populated, `/article` thin launcher works, end-to-end article production verified
- Phase 7: `processes/pas/` exists, bootstrap replaced with self-hosted
- Phase 8: Full feedback cycle works (collect → route → apply)

## Risk Mitigation

| Risk | Mitigation |
|---|---|
| Hook API mismatch | Test hooks manually in Phase 4.6. Check Claude Code docs. |
| Content loss during prompt adaptation | Diff adapted skills against legacy originals. Skills should be richer, not thinner. |
| Large Phase 6 | Break into per-agent commits if needed. |
| Self-hosting risk (Phase 7) | Keep bootstrap in `.claude/skills/pas/` as fallback until verified. |
