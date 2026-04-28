# Orchestration Library Changelog

## 2026-04-28 — Cycle 17 / 1.4.2: Phase Advancement Test doctrine + Session Binding Contract rewrite

Triggered by: orchestrator-side session-binding recurrence after the cycle-16 hook fix (see hooks/changelog.md → Cycle 17). The hook code held; the docs still pushed orchestrators and skill authors to bind fresh sessions in workspaces they didn't own.

Changes:
- `doctrines.md` — `Workspace Binding Is Skill-Owned` extended with **Phase Advancement Test**: bind only if this session is about to advance a phase in this workspace. "I see an in-progress workspace and I should register myself somewhere" is not a reason to bind. Origin section cites the consumer-side `pas-misrouted-and-migration-ts` recurrence.
- `lifecycle.md` — Session Binding Contract rewritten: the word "claims" is replaced with a concrete two-clause definition (creates the workspace, OR resumes a workspace whose phases this session is about to advance). Added explicit prohibition on writes by fresh sessions running unrelated work.
- `lifecycle.md` — Session tracking paragraph (formerly L122) corrected to reflect 1.4.1+ hook behavior — the hook only refreshes `current_session:` on true reconnect; initial binding is the skill's responsibility.
- `lifecycle.md` — Ad-Hoc Execution step 1 qualified: "use existing workspace" applies only when the workspace is for the same process and instance. Unrelated in-progress workspaces stay untouched.

## 2026-03-08 — Extract shared lifecycle protocol + ready-handshake

Triggered by: Cycle 9 Milestone 1 — orchestration pattern duplication (~300 of 578 lines identical)
Pattern: Every bug fix applied 4x across patterns; agent spawn timing race unfixed for 3 cycles
Changes:
- Created `lifecycle.md`: shared protocol for workspace creation, task creation, status tracking, ready-handshake, shutdown sequence, completion gate, session continuity, resumability
- hub-and-spoke.md: replaced duplicated lifecycle sections with references to lifecycle.md (250 -> ~140 lines). Added ready-handshake to spawn prompt requirements.
- discussion.md: replaced duplicated lifecycle sections with references to lifecycle.md (122 -> ~60 lines). Added ready-handshake to spawn step.
- solo.md: replaced duplicated lifecycle sections with references to lifecycle.md (92 -> ~40 lines). No ready-handshake (no agents spawned).
- sequential-agents.md: replaced duplicated lifecycle sections with references to lifecycle.md (114 -> ~65 lines). Added ready-handshake to spawn and handoff steps.
- Ready-handshake protocol: agents send `READY: {name}` after spawn, orchestrator waits before dispatching work. Mitigates TeamCreate spawn timing race.

## 2026-03-07 — Add task creation and hook enforcement references

Triggered by: GitHub issue #7 — orchestrator does not self-enforce process lifecycle
Pattern: Text-level enforcement (HARD REQUIREMENT, COMPLETION GATE) still skipped by orchestrator
Changes:
- All 4 patterns: Add task creation step at startup — [PAS]-prefixed tasks for phases + shutdown
- All 4 patterns: Add hook enforcement note under COMPLETION GATE
- hub-and-spoke.md: Add session tracking fields (current_session, sessions) to status.yaml format

## 2026-03-07 — Fix feedback system: mandatory workspace, completion gates

Triggered by: GitHub issue #6 — 2/2 sessions completed without feedback, workspace never created, self-eval never written
Pattern: Passive language ("check for workspace") allowed orchestrators to skip workspace creation entirely; no structural enforcement of feedback at shutdown
Changes:
- All 4 patterns: Rewrite workspace init from "check for" to imperative "create" with HARD REQUIREMENT callout
- All 4 patterns: Add COMPLETION GATE with 4 blocking conditions (phases complete, feedback files exist, framework signals filed, status finalized)
- hub-and-spoke.md: Add orchestrator self-eval step (step 6), framework signal routing (step 7)
- solo.md: Add framework signal routing step, COMPLETION GATE
- discussion.md: Replace "follows hub-and-spoke" with explicit Startup (4 steps) and Shutdown (8 steps) sections
- sequential-agents.md: Add new Startup (4 steps) and Shutdown (8 steps) sections that were missing entirely

## 2026-03-07 — Enforce self-evaluation, add agent communication guidance

Triggered by: GitHub issue #1 — Self-eval skipped 3x across 2 sessions, wrong communication mechanism used
Pattern: Shutdown and feedback enforcement fails because nothing enforces it; orchestrator repeatedly skipped self-eval
Changes:
- solo.md: Strengthened shutdown sequence with mandatory self-eval checkpoint, feedback routing verification
- hub-and-spoke.md: Added self-eval instructions to spawn prompt template
- hub-and-spoke.md: Added Agent Communication section (SendMessage for team members, Agent resume for ephemeral subagents)
- hub-and-spoke.md: Made self-eval mandatory before proceeding to agent shutdown, added feedback routing verification step
- hub-and-spoke.md: Added Intra-Phase Parallel Dispatch section — absorbs parallel agent dispatch pattern with PAS lifecycle enforcement (verified paths, shutdown protocol, mandatory feedback for all agents including ephemeral ones)
