# Implementation Plan — Cycle 9 (Revised)

## Context

The owner's directive for cycle 9 was: "Create a 6-month roadmap for PAS." Discovery produced a roadmap outline in `workspace/pas-development/cycle-9/discovery/priorities.md`, but that is a transient workspace artifact. Before executing Month 1-2 items, we need to:

1. Formalize the roadmap as a durable planning document
2. Integrate it into the pas-development process so future cycles can consult it
3. Then execute Milestone 1 items as the first work under the roadmap

## Priorities Addressed

From `workspace/pas-development/cycle-9/discovery/priorities.md`:

- **P0 (new):** Formalize the 6-month roadmap as a durable artifact and integrate with pas-development
- **P1:** Fix DX quick wins (PPU inconsistency, define "slug", filesystem warning, confusing naming)
- **P2:** Library dedup (design only this cycle — implementation deferred)
- **P3:** Extract shared lifecycle from orchestration patterns (300 duplicated lines -> shared module)
- **P4:** Implement agent ready-handshake protocol (recurring bug, 3 cycles unfixed)
- **P5:** Add periodic DX audit as formal checkpoint in pas-development process

**Scope decision:** P0, P1, P3, P4, and P5 fit in a single execution phase. P2 (library dedup) is too large for this cycle — it requires changing every process's library references, modifying first-run detection, adding an override mechanism, and updating CLAUDE.md. This cycle produces the design document; next cycle implements it.

## Changes

### Change 1: Create formal 6-month roadmap document

**Priority:** P0 — Formalize the roadmap
**Agent:** Framework Architect
**Files:**
- Create: `docs/plans/2026-03-08-six-month-roadmap.md`

**Why `docs/plans/` (dev-only) and not `plugins/pas/`:** The roadmap is specific to PAS's own development process — it guides which cycles work on what. It is not part of the PAS plugin that other users install. It follows the same pattern as the existing `docs/plans/2026-03-07-feedback-enforcement.md`.

**Content structure:**
```markdown
# PAS 6-Month Roadmap (March 2026 — September 2026)

## Vision
{From discovery: evolve PAS into the de-facto best way to build agentic workflows}

## Filtering Principle
Every item must pass: "Does this make PAS better for the owner's actual workflows?"

## Milestones

### Milestone 1: Foundation & Quick Wins (Month 1-2)
**Status:** In progress (Cycle 9)
**Success criteria:** {specific, verifiable outcomes}
- Fix DX friction: PPU inconsistency, define "slug", filesystem warning, jargon removal
- Extract shared lifecycle protocol from orchestration patterns
- Implement agent ready-handshake protocol
- Add periodic DX audit checkpoint to pas-development
- Library dedup design (implementation in next cycle)
**Exit criteria:** Orchestration patterns reference lifecycle.md, no duplicated protocol blocks, ready-handshake in use

### Milestone 2: Reliability (Month 2-3)
**Status:** Not started
**Success criteria:** {specific outcomes}
- Test harness for bash hooks and scripts (priority: route-feedback.sh)
- Graceful error handling (silent failures -> informative messages)
- Feedback signal schema formalization
- README with end-to-end example
- Library dedup implementation
**Exit criteria:** All hooks have test coverage, README demonstrates full workflow

### Milestone 3: Capability Expansion (Month 3-4)
**Status:** Not started
**Success criteria:** {specific outcomes}
- Subprocess invocation (process calling process)
- Lightweight process mode for solo-pattern workflows
- Native Agent Teams alignment assessment
**Exit criteria:** A process can invoke another process, simple workflows skip lifecycle overhead

### Milestone 4: Process Portability (Month 4-5)
**Status:** Not started
**Success criteria:** {specific outcomes}
- Process packaging format for cross-repo sharing
- Import mechanism for external processes
- Subagent persistent memory exploration
**Exit criteria:** A process can be packaged and installed in a different project

### Milestone 5: Polish & Positioning (Month 5-6)
**Status:** Not started
**Success criteria:** {specific outcomes}
- Runtime status tooling (`/pas status`)
- Expanded configuration with documented schema
- Marketplace readiness assessment
- Process templates if adoption signals warrant
**Exit criteria:** PAS is self-documenting and ready for external assessment

## Progress Tracking
Each milestone maps to 2-4 development cycles. The orchestrator updates milestone status
in this document as cycles complete. When starting a cycle without a specific directive,
consult the next incomplete milestone.

## Revision History
- 2026-03-08: Initial roadmap from cycle 9 discovery
```

The Framework Architect fills in the specific success criteria and exit criteria based on the discovery artifacts, particularly `framework-assessment.md` and `dx-audit.md`.

**Depends on:** none

### Change 2: Integrate roadmap into pas-development process

**Priority:** P0 — Roadmap integration
**Agent:** Framework Architect
**Files:**
- Modify: `processes/pas-development/process.md` — Add to the discovery phase input: `OR active roadmap milestone from docs/plans/`. Update the phase description to mention: "When no directive is provided and no urgent feedback exists, the orchestrator consults the active roadmap (`docs/plans/2026-03-08-six-month-roadmap.md`) to determine which milestone to work on next."
- Modify: `processes/pas-development/agents/orchestrator/agent.md` — Add to Behavior section: "On startup without a directive: check `docs/plans/` for an active roadmap. Read the roadmap, find the first milestone with status other than 'Completed', and use it to frame discovery. Present the milestone's remaining items to the team as the starting point for prioritization."

**Architectural rationale:** The roadmap is an input to the process, not a structural change to the process. The orchestrator already has two input modes (directive vs feedback-driven). This adds a third: roadmap-driven. The precedence is: owner directive > active roadmap milestone > accumulated feedback signals.

**Depends on:** Change 1 (roadmap must exist to be referenced)

### Change 3: Fix PPU acronym inconsistency

**Priority:** P1 — DX quick wins
**Agent:** DX Specialist
**Files:**
- Modify: `README.md` (line 90) — Change "Process/Pipeline Upgrade" to "Persistent Preference Update" to match the canonical definition in `plugins/pas/library/self-evaluation/SKILL.md` (line 29)
**Depends on:** none

### Change 4: Define "slug" in orchestration SKILL.md

**Priority:** P1 — DX quick wins
**Agent:** DX Specialist
**Files:**
- Modify: `plugins/pas/library/orchestration/SKILL.md` — Add a "Terminology" section defining "slug" as a short identifier for a process run instance (e.g., `cycle-9`, `2026-03-08-code-review`). The slug is provided by the user or derived from the directive when the orchestrator creates the workspace.
**Depends on:** none

### Change 5: Add filesystem warning to README Quick Start

**Priority:** P1 — DX quick wins
**Agent:** DX Specialist
**Files:**
- Modify: `README.md` (after line 57) — Add one sentence: "On first use, PAS creates `pas-config.yaml`, `library/`, and `workspace/` directories in your project root."
**Depends on:** none

### Change 6: Replace "crystal clarity principle" with plain instruction

**Priority:** P1 — DX quick wins
**Agent:** DX Specialist
**Files:**
- Modify: `plugins/pas/skills/pas/SKILL.md` (line 25) — Replace "Crystal clarity principle: never assume you understand. Ask until the user confirms." with "Never assume you understand what the user wants — ask clarifying questions until they confirm."
- Modify: `plugins/pas/processes/pas/agents/orchestrator/agent.md` (line 24) — Replace "crystal clarity before action" with "ask until the user confirms before acting"
- Modify: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md` (line 22) — Replace "Apply the crystal clarity principle. Never assume you understand what the user wants." with "Never assume you understand what the user wants. Ask clarifying questions until the user confirms."
- Modify: `plugins/pas/processes/pas/agents/orchestrator/skills/applying-feedback/SKILL.md` (line 76) — Replace "ask the user for crystal clarity" with "ask the user to clarify"
- Modify: `plugins/pas/processes/pas/process.md` (line 34) — Replace "Crystal clarity principle: never assume, ask until clear." with "Never assume — ask clarifying questions until the user confirms."
**Depends on:** none

### Change 7: Extract shared lifecycle protocol from orchestration patterns

**Priority:** P3 — Lifecycle extraction (Milestone 1)
**Agent:** Framework Architect
**Files:**
- Create: `plugins/pas/library/orchestration/lifecycle.md` — New file containing the shared protocol sections extracted from the 4 pattern files:
  - **Workspace Creation**: the `mkdir -p` block, `status.yaml` initial write, and resume check (currently identical in all 4 patterns)
  - **Lifecycle Task Creation**: the `[PAS]` prefix convention with phase tasks and 3 shutdown tasks (currently identical in all 4 patterns)
  - **Status Tracking Format**: the `status.yaml` YAML schema with phases, sessions, quality scores (currently in hub-and-spoke, referenced by others)
  - **Completion Gate**: the 4-condition check, hook enforcement note (currently identical in all 4 patterns)
  - **Shutdown Sequence (common steps)**: self-evaluation collection, framework signal routing, signal verification, status finalization (currently near-identical in all 4 patterns)
  - **Session Continuity**: the offer-next-cycle paragraph (currently identical in all 4 patterns)
  - **Resumability**: the resume-from-status.yaml protocol (currently in hub-and-spoke, applicable to all)
  - **Ready Handshake** (new — see Change 8): protocol for agent spawn confirmation
- Modify: `plugins/pas/library/orchestration/hub-and-spoke.md` — Replace duplicated sections with references to `lifecycle.md`. Keep only: orchestrator role description, spawning team members details, agent communication rules, parallelism inference, intra-phase parallel dispatch, error handling chain, gate protocol (claim verification). Target: ~120-140 lines (from 250).
- Modify: `plugins/pas/library/orchestration/discussion.md` — Replace duplicated sections with references to `lifecycle.md`. Keep only: when to use, moderator behavior, turn-taking protocol, discussion-specific status tracking (rounds), discussion-specific gate protocol. Target: ~50-60 lines (from 122).
- Modify: `plugins/pas/library/orchestration/solo.md` — Replace duplicated sections with references to `lifecycle.md`. Keep only: when to use, operator behavior, when to upgrade. Target: ~30-40 lines (from 92).
- Modify: `plugins/pas/library/orchestration/sequential-agents.md` — Replace duplicated sections with references to `lifecycle.md`. Keep only: when to use, handoff protocol, agent lifecycle (eager_shutdown), error handling specifics. Target: ~50-60 lines (from 114).
- Update: `plugins/pas/library/orchestration/changelog.md` — Document the extraction
- Mirror to: `library/orchestration/lifecycle.md` — Copy the new file and updated patterns to the project-level library (standard dev-branch mirror sync)
**Depends on:** none (but Change 8 content is included in lifecycle.md)

### Change 8: Implement agent ready-handshake protocol

**Priority:** P4 — Ready handshake (Milestone 1)
**Agent:** Framework Architect
**Files:**
- Content goes into `plugins/pas/library/orchestration/lifecycle.md` (created in Change 7) as a "Ready Handshake" section. The protocol:
  1. Orchestrator spawns agent via TeamCreate
  2. Agent spawn prompt includes: "After reading your agent.md and skills, send a message to the orchestrator containing only: `READY: {agent-name}`"
  3. Orchestrator waits for READY messages from all spawned agents before sending any work instructions
  4. If an agent does not send READY within a reasonable period, orchestrator sends a probe message: "Confirm you are ready by responding with `READY: {agent-name}`"
  5. Only after all agents confirm READY does the orchestrator begin phase dispatch
- Modify: `plugins/pas/library/orchestration/hub-and-spoke.md` — Update "Spawning Team Members" section to reference the ready-handshake in lifecycle.md. Add to spawn prompt requirements: include READY instruction.
- Modify: `plugins/pas/library/orchestration/discussion.md` — Update spawn step to reference ready-handshake
- Modify: `plugins/pas/library/orchestration/sequential-agents.md` — Update spawn step to reference ready-handshake
- No change to `solo.md` — solo pattern does not spawn agents
**Depends on:** Change 7 (lifecycle.md must exist first, but since both are implemented by the same agent, they are done together)

### Change 9: Add periodic DX audit as formal checkpoint in pas-development

**Priority:** P5 — DX audit checkpoint (Milestone 1)
**Agent:** Framework Architect
**Files:**
- Modify: `processes/pas-development/process.md` — Add a note to the Discovery phase description that every 3rd cycle (or when the orchestrator determines enough changes have accumulated since the last DX audit), the DX Specialist should perform a fresh DX audit of `plugins/pas/` as part of discovery. This is a process definition change, not a structural change — it makes the existing DX audit a recurring scheduled activity rather than ad-hoc.
- Modify: `processes/pas-development/agents/dx-specialist/agent.md` — Add to Behavior section: "In Discovery (recurring): every 3rd cycle or when triggered by the orchestrator, perform a full DX audit of the plugin (`plugins/pas/`) using the dx-audit skill."
**Depends on:** none

### Change 10: Library dedup design document

**Priority:** P2 — Library dedup (design only, implementation deferred to Milestone 2)
**Agent:** Framework Architect
**Files:**
- Create: `workspace/pas-development/cycle-9/planning/library-dedup-design.md` — Design document specifying:
  - Current state: copy-on-bootstrap from `plugins/pas/library/` to project `library/`
  - Target state: processes reference `plugins/pas/library/` directly via `${CLAUDE_PLUGIN_ROOT}/library/` (or the equivalent variable); project-level `library/` becomes an override layer where a local file takes precedence over the plugin file
  - Migration plan: update all `library/` references in orchestration patterns and agent.md files; update first-run detection in SKILL.md to stop copying; update CLAUDE.md protected files note
  - Risk: processes running outside the plugin context (standalone use) need a fallback — if no plugin root, use project-level `library/`
  - This design will be the input for a future cycle's execution
**Depends on:** Change 7 (lifecycle extraction clarifies what library files exist and how they are referenced)

## Execution Order

### Parallel Group 1 (no dependencies)
- Changes 3, 4, 5, 6 (DX quick wins) -> DX Specialist (single work package)
- Change 1 (roadmap document) -> Framework Architect
- Changes 7 + 8 (lifecycle extraction + ready handshake) -> Framework Architect
- Change 9 (DX audit checkpoint) -> Framework Architect

**Note:** Framework Architect changes 1, 7+8, and 9 are independent but assigned to the same agent. The agent should do Change 1 first (small, focused), then Changes 7+8 (largest piece of work), then Change 9 (small edit).

### Sequential Group 2 (depends on Group 1)
- Change 2 (roadmap integration into pas-development) -> Framework Architect (depends on Change 1)
- Change 10 (library dedup design) -> Framework Architect (depends on Change 7)

## Out of Scope

### Deferred to Milestone 2 (Month 2-3)
- **Library dedup implementation** (P2): This cycle produces the design document; a future cycle implements it. The lifecycle extraction (Change 7) is the prerequisite since it restructures the library/orchestration/ directory.
- **Test harness for hooks**: Important but independent of the foundation work. Requires its own focused cycle.
- **README end-to-end example**: High-impact DX improvement, but better done after the foundation is solid.
- **Feedback signal schema formalization**: Depends on the library dedup being done first.

### Deferred to Milestone 3+ (Month 3+)
- **Lightweight process mode**: Architecturally sound but needs careful design. Month 3-4.
- **Subprocess invocation**: Largest missing capability. Month 3-4.

### Considered and rejected for this cycle
- **Rename GATE signal type** (DX audit N2): Cascades through self-evaluation SKILL.md, route-feedback.sh regex, applying-feedback SKILL.md, and all existing feedback files. Defer to signal schema formalization in Milestone 2.
- **Remove Two-Tier Agent Lifecycle from README** (DX audit quick win 6): The README will get a larger rewrite when the end-to-end example is added in Milestone 2. Avoid making small README changes that will be overwritten.

## Agent Assignment Summary

| Agent | Changes | Estimated Scope |
|-------|---------|----------------|
| DX Specialist | 3, 4, 5, 6 | 4 small text edits across 6 plugin files + README |
| Framework Architect | 1, 2, 7, 8, 9, 10 | 1 roadmap doc, 1 new library file (lifecycle.md), 4 file rewrites (patterns), 3 small edits (process.md x2, agent.md x2), 1 design doc |

## Verification Criteria

After execution, the QA Engineer should verify:
1. `docs/plans/2026-03-08-six-month-roadmap.md` exists with 5 milestones, success criteria, and exit criteria for each
2. `processes/pas-development/process.md` references the roadmap as a discovery input
3. `processes/pas-development/agents/orchestrator/agent.md` includes roadmap-consultation behavior
4. `plugins/pas/library/orchestration/lifecycle.md` exists and contains all shared protocol sections
5. Each pattern file references lifecycle.md instead of duplicating content
6. No pattern file contains the workspace mkdir block, task creation block, completion gate block, or session continuity paragraph inline
7. The ready-handshake protocol is referenced in hub-and-spoke, discussion, and sequential-agents spawn sections
8. PPU expansion is consistent across README.md and self-evaluation SKILL.md
9. "Crystal clarity principle" appears nowhere in `plugins/pas/` (only in workspace discovery artifacts, which are historical)
10. "slug" is defined in orchestration SKILL.md
11. README Quick Start mentions filesystem changes on first use
12. All modified plugin files still have valid YAML frontmatter (where applicable)
13. The library mirror (`library/orchestration/`) matches `plugins/pas/library/orchestration/` after sync
14. Roadmap Milestone 1 status is updated to "In progress" with cycle-9 reference
