# Framework Assessment — Cycle 8 (12-Month Roadmap Input)

## Current Architecture Summary

PAS v1.3.0 consists of:
- **1 plugin** with 1 process (pas), 1 agent (orchestrator), 7 skills, 4 library skills, 5 hooks
- **4 orchestration patterns**: solo, hub-and-spoke, discussion, sequential-agents
- **Feedback system**: self-evaluation signals (PPU/OQI/GATE/STA), hook-enforced lifecycle, automated routing to artifact backlogs and GitHub issues
- **Creation infrastructure**: 3 bash scaffolding scripts (pas-create-process, pas-create-agent, pas-create-skill)
- **Dogfooding process**: pas-development (7 agents, 9 skills, 5 phases, discussion + hub-and-spoke patterns)

## What Scales Well

### 1. Process-Agent-Skill Hierarchy
The three-level abstraction is sound. Processes define flow, agents define roles, skills define capabilities. This separation of concerns is the framework's strongest architectural property. Adding a new process does not require modifying existing ones. Adding a new skill to an agent does not require modifying the process. This is true composability.

### 2. Orchestration Patterns as Library
Having 4 orchestration patterns as readable markdown documents (not code) is a genuine differentiator. Users can read how their process will execute. The decision matrix (solo -> discussion -> hub-and-spoke -> sequential-agents) gives clear guidance. New patterns can be added without touching existing ones.

### 3. Feedback Loop Architecture
The signal taxonomy (PPU/OQI/GATE/STA) with structured routing is well-designed. The chain — agent self-evaluates, hook routes signals to backlogs, applying-feedback skill processes backlogs — is architecturally clean. The hook enforcement (check-self-eval, verify-completion-gate, verify-task-completion) prevents silent degradation. This is the framework's most mature subsystem.

### 4. Convention Over Configuration
The `feedback/backlog/` and `changelog.md` convention on every artifact creates a uniform feedback surface. The SKILL.md format with YAML frontmatter provides consistent discovery. The `pas-config.yaml` is intentionally minimal (1 toggle). These conventions mean PAS works without configuration.

## What's Fragile

### 1. Library Mirror Drift (Structural)
The `library/` directory is a copy of `plugins/pas/library/`. Nothing enforces sync. Cycle-7 found 3 of 4 library skills out of sync. The proposed `sync-library.sh` script is a band-aid. The real problem: PAS has two sources of truth for the same content. This will get worse as the library grows.

**Scaling risk**: If PAS has 20 library skills, manual sync becomes untenable. Users who install the plugin and bootstrap `library/` will silently fall behind when the plugin updates.

**Architectural options**:
- (a) PostToolUse hook to auto-sync on write to `plugins/pas/library/`
- (b) Eliminate mirrors entirely — have skills reference `${CLAUDE_PLUGIN_ROOT}/library/` directly
- (c) Plugin update mechanism that re-bootstraps library on version change

### 2. Single-Process Plugin
The PAS plugin contains exactly one process (the pas management process). Users create their own processes outside the plugin. This means:
- The plugin's process definitions are not reusable as templates
- There is no process import/export mechanism
- Users cannot share processes via the marketplace (only the full PAS plugin is distributable)

**Scaling risk**: As users create sophisticated processes, there is no way to distribute or compose them. A user with a great SEO pipeline cannot share it as a PAS artifact.

### 3. Hook Input Contract Fragility
All 5 hooks parse unversioned JSON from stdin via `jq`. Fields like `cwd`, `agent_id`, `session_id`, `task_subject`, `last_assistant_message` are assumed stable. Claude Code provides no schema versioning guarantee for hook inputs. A breaking change in Claude Code's hook contract would silently break all PAS hooks.

**Scaling risk**: More hooks = more surface area for breakage. The `route-feedback.sh` hook alone has 200 lines of bash parsing.

### 4. No Testing Infrastructure
Zero automated tests exist for:
- Hook scripts (the most critical infrastructure)
- Creation scripts (pas-create-process, pas-create-agent, pas-create-skill)
- Orchestration pattern compliance
- Convention compliance (feedback/backlog/, changelog.md presence)

The `--base-dir` flag was added to creation scripts for "test isolation" but no tests use it. Validation is entirely manual via the pas-development cycle's QA phase.

**Scaling risk**: Every change to hooks or scripts is validated by a single pass in a development cycle. Regressions are caught by users, not automation.

### 5. No Cross-Process Communication
Processes are completely isolated. There is no mechanism for:
- One process to trigger another
- Shared state between processes
- Process composition (process A's output feeding process B's input)
- Event-based coordination between running processes

The pas-development process works around this by having the orchestrator manually read files from `workspace/`. This is fine for one process but does not generalize.

### 6. Context Window Pressure
The orchestration patterns (especially hub-and-spoke) require the orchestrator to carry significant context: process.md, mode files, orchestration pattern docs, status.yaml, team member states. For complex processes, the orchestrator's context window fills up before execution begins. The pas-development process already shows this pressure — 7 agents, 9 skills, 5 phases.

**Scaling risk**: Processes with more than ~8 agents or ~6 phases will hit context limits during orchestration. The orchestrator cannot delegate its own coordination work.

## Capability Boundaries — What PAS Can vs. Cannot Do Today

### Can Do
- Create and manage multi-agent processes from natural language goals
- Self-improve through structured feedback signals
- Enforce process lifecycle via hooks
- Visualize process structure as HTML
- Manage releases via PR workflow
- Support 4 orchestration patterns

### Cannot Do
- **Process templates/sharing**: No import/export, no marketplace distribution of individual processes
- **Cross-process communication**: Processes cannot trigger or feed into each other
- **Dynamic agent scaling**: Agent count is fixed at design time, cannot scale based on workload
- **Conditional branching**: Phases execute linearly or in parallel, but cannot branch based on output content
- **Persistent state across sessions**: Status.yaml provides resumability but no long-term state management
- **Version migration**: No mechanism to update existing processes when the framework's conventions change
- **Process introspection at runtime**: No way for a running process to query its own status programmatically (outside of reading status.yaml)

## Architectural Risk at Scale

### 10x Complexity (10 processes, 30+ agents, 50+ skills)
**Primary risk**: Convention drift. With 50+ skills, some will diverge from conventions (missing feedback/backlog/, incomplete SKILL.md frontmatter). Manual auditing in pas-development cycles will not catch everything.

**Mitigation needed**: Automated convention linting (a CLI tool or hook that validates all PAS artifacts against conventions).

### 100x Complexity (100 processes, ecosystem of shared processes)
**Primary risk**: Composition and distribution. Users will want to share processes, compose them into pipelines, and version them independently. The current monolithic plugin model cannot support this. Each process would need to be independently distributable and composable.

**Mitigation needed**: Process packaging format, dependency resolution, inter-process communication protocol.

## Deferred Backlog Assessment

### PreToolUse Guard Hooks (from cycle-7 backlog)
**What**: Block direct edits to `plugins/pas/` outside pas-development execution
**Architectural assessment**: Low-risk, high-value. Uses existing Claude Code hook infrastructure. Implementation is straightforward: match `Write|Edit` tools, check target path, deny if not in pas-development context. The main design question is how to detect "in pas-development context" — likely via checking for an active pas-development workspace in status.yaml.
**Recommended timing**: Q1 (months 1-3). This is foundational process integrity.

### PostToolUse Sync Hooks (from cycle-7 backlog)
**What**: Auto-sync library mirrors when plugin source changes
**Architectural assessment**: Medium complexity. The hook needs to detect writes to `plugins/pas/library/`, identify the corresponding mirror path, and copy. Edge cases: what if the mirror has local modifications? What if multiple files change in one operation?
**Recommended timing**: Q1 if mirror approach is kept. If option (b) from Fragility #1 is chosen (eliminate mirrors), this becomes unnecessary.

### Worktree-Based Release (from cycle-7 backlog)
**What**: Use git worktrees for release phase instead of branch switching
**Architectural assessment**: High value, medium complexity. Claude Code's native `--worktree` support makes this feasible. The release phase would create a worktree from main, cherry-pick plugin commits, run validation, open PR, and clean up. Eliminates the entire class of branch-switching bugs (which caused data loss in cycle-6).
**Recommended timing**: Q1-Q2 (months 2-4). This is a reliability fix for a proven failure mode.

## 12-Month Architectural Roadmap Input

Based on the assessment above, here are the architectural investment areas I see, organized by when the framework's foundations need investment vs. when features can be added on top.

### Foundation Phase (Months 1-4): Reliability and Testing
The framework needs to solidify what exists before adding new capabilities.

1. **Testing infrastructure** — Automated tests for hooks, creation scripts, and convention compliance. This is the single biggest gap. Every other improvement is at risk without tests to catch regressions.
2. **PreToolUse guard hooks** — Process integrity enforcement. Prevents the dogfooding bypass that cycle-6/7 identified.
3. **Library sync solution** — Either PostToolUse hooks or elimination of mirrors. Resolve the dual-source-of-truth problem.
4. **Worktree-based release** — Eliminate branch-switching bugs. This is a reliability fix, not a feature.
5. **Hook input validation** — Add defensive parsing and version checking to hooks so Claude Code updates don't silently break them.

### Capability Phase (Months 4-8): Expressiveness
With a solid foundation, add capabilities that expand what PAS can express.

6. **Conditional branching in phases** — Allow phases to branch based on output content (e.g., "if validation fails, route back to execution"). This requires extending process.md syntax and orchestration pattern logic.
7. **Cross-process communication** — Define a protocol for processes to trigger each other or share outputs. Likely file-based (process A writes to a known path, process B reads from it) with optional hook-based notification.
8. **Process templates** — Extract reusable patterns from existing processes (e.g., "discovery-planning-execution" is a common template). Allow `pas-create-process --from-template` to scaffold from templates.
9. **Convention linting CLI** — `pas lint` command that validates all artifacts against PAS conventions. Run in CI or as a pre-commit hook.

### Distribution Phase (Months 8-12): Ecosystem
With reliability and expressiveness in place, enable sharing and composition.

10. **Process packaging** — Define a format for distributing individual processes (not just the full plugin). Processes would declare dependencies (library skills, hooks) and `pas install <process>` would resolve them.
11. **Process composition** — Allow a process to reference another process as a phase (sub-processes). Status.yaml already has a `subprocess` field — make it operational.
12. **Version migration** — When PAS conventions change (e.g., new required fields in SKILL.md), provide `pas migrate` to update existing artifacts.
13. **Persistent state management** — A mechanism for processes to maintain state across sessions beyond status.yaml (e.g., accumulated metrics, learned preferences, cross-session context).

### Continuous (Throughout)
- **Feedback system evolution** — The signal taxonomy may need extension as new patterns emerge. Keep it minimal but be ready to add types.
- **Orchestration pattern refinement** — Each pattern will accumulate operational knowledge. The hub-and-spoke pattern has already grown significantly (from 50 to 250 lines across 3 versions). Monitor for patterns splitting or merging.
- **Claude Code platform alignment** — Track hook API changes, new tool capabilities, and agent team stabilization. Adjust PAS infrastructure to match platform evolution.

## Key Architectural Decisions Needed

1. **Library mirrors vs. direct references**: Should we eliminate the library mirror pattern entirely? If `${CLAUDE_PLUGIN_ROOT}` is reliable, mirrors add complexity without value. If plugin references are fragile, mirrors provide resilience. This decision affects months 1-4 planning.

2. **Process distribution unit**: Is a PAS process the right unit for marketplace distribution, or should it be something larger (a "workflow bundle" with processes + library skills + hooks)? This decision shapes months 8-12.

3. **Hook language**: As hooks grow more complex (route-feedback.sh is already 200 lines of bash), should PAS migrate to a more maintainable hook implementation language? Options: keep bash (simple, portable), move to Python/Node (testable, structured), or move to prompt-type hooks (AI-powered but slower).

4. **Backward compatibility strategy**: PAS has no versioned contract with users. When process.md syntax changes or SKILL.md frontmatter adds required fields, existing processes break silently. Should PAS adopt semantic versioning for its conventions, or rely on migration tooling?
