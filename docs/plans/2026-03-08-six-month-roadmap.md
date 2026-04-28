# PAS 6-Month Roadmap (March 2026 -- September 2026)

## Vision

Evolve PAS into the de-facto best way to build agentic workflows in Claude Code.

## Filtering Principle

Every item must pass: **"Does this make PAS better for the owner's actual workflows?"** External positioning follows product quality, not the other way around. PAS has one active user. Features like a process marketplace matter only if there are processes worth sharing. Focus on making pas-development excellent first -- that validates every architectural change against real usage.

## Current State (as of Cycle 12)

- Plugin version: 1.3.1
- 10 bash scripts (~1850 lines), 45-test automated hook harness
- 4 orchestration patterns at 345 lines total (lifecycle extracted, zero duplication)
- Library dedup implemented: new processes reference `${CLAUDE_PLUGIN_ROOT}/library/` directly
- Agent spawn timing race fixed (ready-handshake protocol in lifecycle.md)
- Signal schema formalized, feedback enforcement via hooks
- DX quick wins addressed, README with end-to-end walkthrough
- Version auto-bump integrated into release workflow
- No subprocess invocation, no process portability, no runtime status tooling

---

## Milestone 1: Foundation & Quick Wins (Month 1-2)

**Status:** Complete (Cycles 9-10)

### Items
- Fix DX quick wins: PPU acronym inconsistency, define "slug", filesystem warning, remove "crystal clarity" jargon
- Extract shared lifecycle protocol from orchestration patterns into `lifecycle.md`
- Implement agent ready-handshake protocol in lifecycle.md
- Add periodic DX audit as formal checkpoint in pas-development process
- Library dedup design document (implementation in next cycle)
- Formal 6-month roadmap (this document) and integration into pas-development

### Success Criteria
1. Orchestration patterns reference `lifecycle.md` -- no shared protocol blocks duplicated inline
2. Total line count across 4 pattern files drops from 578 to under 350
3. Ready-handshake protocol is specified in lifecycle.md and referenced by hub-and-spoke, discussion, and sequential-agents patterns
4. PPU expansion is consistent across README.md and self-evaluation SKILL.md
5. "Crystal clarity principle" appears nowhere in `plugins/pas/`
6. "Slug" is defined in orchestration SKILL.md
7. README Quick Start mentions filesystem changes on first use
8. DX audit is a recurring scheduled activity in pas-development process definition
9. Library dedup design document exists with migration plan and risk analysis

### Exit Criteria
All success criteria verified by QA engineer. Orchestration patterns are maintainable (single-edit fixes). Ready-handshake is documented for use in the next multi-agent cycle.

---

## Milestone 2: Reliability & Library Dedup (Month 2-3)

**Status:** Complete (Cycles 10-12)

### Items
- Library dedup implementation: processes reference plugin library directly, project-level override mechanism
- Test harness for bash hooks and scripts (priority: route-feedback.sh, verify-completion-gate.sh, check-self-eval.sh)
- Graceful error handling: silent failures become informative messages in all hooks
- Feedback signal schema formalization (currently prose + inline regex in route-feedback.sh)
- README with end-to-end example showing full input-output cycle

### Success Criteria
1. No project-level `library/` copy needed -- processes reference plugin library via `${CLAUDE_PLUGIN_ROOT}/library/` with project-level override fallback
2. First-run detection no longer copies library files; creates only `pas-config.yaml` and `workspace/`
3. All 5 hook scripts (check-self-eval.sh, verify-completion-gate.sh, verify-task-completion.sh, route-feedback.sh, pas-session-start.sh) have automated test cases
4. route-feedback.sh tests cover: signal parsing, target resolution, duplicate routing prevention, non-PAS project passthrough
5. Signal types defined in a structured schema file referenced by self-evaluation SKILL.md, route-feedback.sh, and applying-feedback SKILL.md
6. README Quick Start includes a 3-4 turn conversation example with resulting directory structure
7. A stranger reading only the README can understand what PAS does and how to create their first process

### Exit Criteria
All hooks pass automated tests. Library dedup works for pas-development process (verified by running a full cycle). README reviewed by DX specialist for clarity.

---

## Milestone 3: Capability Expansion (Month 3-4)

**Status:** Not started

### Items
- Subprocess invocation: a process can invoke another process as a phase
- Lightweight process mode: `lifecycle: lightweight` option skips workspace/status/tasks/completion-gate for simple solo-pattern processes
- Native Agent Teams alignment assessment (evaluate Claude Code platform evolution)

### Success Criteria
1. A `subprocess` phase type exists that handles: spawning child process, tracking its status, passing input/output, merging feedback back to parent
2. PAS can express "run the article process for each topic in the batch" or "run QA validation as a subprocess"
3. Lightweight mode: `lifecycle: lightweight` in process.md frontmatter skips workspace creation, status tracking, task creation, and completion gate
4. Hooks `exit 0` cleanly when no workspace is found (already true) -- no changes needed for lightweight mode hook behavior
5. Lightweight processes keep process structure, gates, and feedback (written to process backlog instead of workspace)
6. Agent Teams assessment document exists with: current alignment, divergence risks, adoption recommendations

### Exit Criteria
Subprocess invocation works in a real example (not just test). Lightweight mode tested with a simple solo process. Agent Teams assessment reviewed by ecosystem analyst.

---

## Milestone 4: Process Portability (Month 4-5)

**Status:** Not started

### Items
- Process packaging format (`pas-package.yaml`) for cross-repo sharing
- Import mechanism for external processes
- Subagent persistent memory exploration

### Success Criteria
1. A `pas-package.yaml` manifest format exists that bundles: process.md, agents, skills, required library skills, and hook requirements
2. A `pas install` command (or equivalent) unpacks a package into the target project, resolving library dependencies
3. pas-development process itself can be packaged and installed in a different project as a test
4. Investigation document on subagent persistent memory with findings and recommendations

### Exit Criteria
At least one process successfully packaged and installed in a fresh project. Package format documented.

---

## Milestone 5: Polish & Positioning (Month 5-6)

**Status:** Not started

### Items
- Runtime status tooling (`/pas status` command showing active processes, phases, completion percentage)
- Expanded configuration with documented schema (default model, orchestration pattern, workspace location)
- Marketplace readiness assessment (not submission -- assessment of whether PAS is ready)
- Process templates for common use cases if adoption signals warrant

### Success Criteria
1. `/pas status` shows: active processes, current phase, completion percentage, pending feedback
2. `pas-config.yaml` supports at least 5 documented configuration options beyond `feedback`
3. Marketplace readiness assessment document exists with: checklist of requirements, gap analysis, go/no-go recommendation
4. If adoption signals exist (stars > 0, forks > 0, or external issues), at least 2 process templates exist for common use cases

### Exit Criteria
Status tooling works on pas-development. Configuration options documented in README. Marketplace assessment reviewed by all agents.

---

## Progress Tracking

Each milestone maps to 2-4 development cycles. The orchestrator updates milestone status in this document as cycles complete. When starting a cycle without a specific directive, consult the next incomplete milestone to frame discovery.

| Milestone | Status | Cycles |
|-----------|--------|--------|
| 1. Foundation & Quick Wins | Complete | Cycles 9-10 |
| 2. Reliability & Library Dedup | Complete | Cycles 10-12 |
| 3. Capability Expansion | Not started | -- |
| 4. Process Portability | Not started | -- |
| 5. Polish & Positioning | Not started | -- |

## Revision History

- 2026-03-10: Milestones 1-2 marked complete. Current state updated to cycle 12.
- 2026-03-08: Initial roadmap from cycle 9 discovery. Source: `workspace/pas-development/cycle-9/discovery/priorities.md`
