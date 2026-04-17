# Cycle-14 Dogfood Signals — Draft GitHub Issues

> **For community-manager:** file these four issues against `ZoranSpirkovski/PAS` at the release phase, after the M3 PR merges. Each issue should be labeled for **Milestone 4 — Lifecycle Governance** triage. Each is a real bug observed *during cycle 14 execution itself*, separate from the 44 issues being closed by M3.

---

## Issue 1 — TaskUpdate ownership-change auto-broadcasts task assignments to the team

**Title:** `TaskUpdate(owner=...)` broadcasts a `task_assignment` notification to all teammates, causing role-mismatched agents to claim PAS lifecycle tasks

**Labels:** `bug`, `lifecycle`, `dogfood`

**Body:**

### Symptom

When the team-lead claims a PAS lifecycle task (`#1` Phase: discovery, `#3` Phase: execution, etc.) by setting its `owner` field via `TaskUpdate`, the harness broadcasts a `{"type":"task_assignment","taskId":"<n>","subject":"[PAS] ..."}` notification to every teammate in the team.

Three downstream agents in cycle 14 (feedback-analyst, community-manager, dx-specialist) interpreted those notifications as direct work assignments and began acting on tasks that were not in their role:

- feedback-analyst was prompted to start task #5 (release-phase pr-management — community-manager work) and then task #7 (route framework signals — orchestrator work).
- community-manager began drafting release-phase artifacts during the discovery phase.

### Reproduction

1. Spawn a team via `TeamCreate` with ≥ 2 teammates.
2. Have the team-lead `TaskCreate` a task with `subject: "[PAS] ..."`.
3. Have the team-lead `TaskUpdate(taskId, owner: "team-lead")` to claim it.
4. Observe: every teammate receives the `task_assignment` notification, not just the named owner.

### Impact

- Wrong-role agents start phase-bound work out of phase order.
- The team-lead has to issue a second clarification broadcast (this happened in cycle 14: `Broadcast to all teammates: ignore [PAS] task_assignment notifications`).
- Multiplies notification noise per teammate per task.

### Suggested fix

Either:

1. `TaskUpdate(owner)` should send the assignment notification only to the named owner, not the whole team; OR
2. The notification should carry an explicit `recipient: "<owner-name>"` field so each agent can self-filter; OR
3. Document that `task_assignment` is informational only — agents must wait for an explicit plain-text dispatch before acting.

Options 1 and 2 are framework changes. Option 3 is a PAS-layer documentation fix in `library/orchestration/lifecycle.md`.

### Source

Cycle 14 execution. team-lead's broadcast clarifying the issue: `.pas/workspace/pas-development/cycle-14/...` (team-lead transcript, mid-discovery).

---

## Issue 2 — Subagents auto-claim broadcast `task_assignment` notifications over plain-text SendMessage dispatches

**Title:** Agents prefer `task_assignment` system notifications over team-lead's plain-text `SendMessage` dispatches

**Labels:** `bug`, `lifecycle`, `agent-behavior`, `dogfood`

**Body:**

### Symptom

In cycle 14, the team-lead sent role-specific dispatches via plain-text `SendMessage` to each agent (`Discovery round 1 dispatch`, etc.). At the same time, `task_assignment` system notifications fired for the [PAS] lifecycle tasks. Multiple agents acted on the system notifications **before or instead of** the plain-text dispatch.

This is a precedence problem: agents treat structured `task_assignment` payloads as authoritative and treat plain-text messages as preamble.

### Reproduction

1. Spawn a teammate.
2. From the team-lead, immediately send a `SendMessage` plain-text dispatch ("your assignment is X").
3. From the team-lead, run `TaskUpdate(taskId, owner: "team-lead")` — broadcasts `task_assignment` to all teammates including the one you just dispatched to.
4. Observe: the teammate often acts on the `task_assignment` first.

### Impact

The team-lead can dispatch correctly, and the agent still does the wrong thing. Even after explicit clarification ("ignore task_assignment notifications") agents continue receiving them on every subsequent `TaskUpdate`.

### Suggested fix

A combination of:

- Document an explicit precedence rule in `lifecycle.md`: **plain-text `SendMessage` from team-lead always supersedes any `task_assignment` system notification**.
- Add to the agent template / spawn prompt a one-liner: *"Treat `task_assignment` notifications as informational only. Wait for explicit plain-text dispatch before claiming any task."*
- Consider whether the harness should suppress `task_assignment` broadcasts entirely when the team-lead is supervising via plain-text messages.

### Source

Cycle 14 execution. Affected agents: feedback-analyst (twice), community-manager (once).

---

## Issue 3 — Phase-order is not enforced; phases can advance without prior phase deliverables present

**Title:** No enforcement that phases advance in order — `Phase: planning` can complete before `Phase: discovery` deliverables exist

**Labels:** `bug`, `lifecycle`, `meta-evidence-for-#49`, `dogfood`

**Body:**

### Symptom

Cycle 14's task tracker showed `[PAS] Phase: discovery` and `[PAS] Phase: execution` both in `in_progress` simultaneously, and at one point `Phase: planning` was marked complete while `Phase: discovery` was still `in_progress` and discovery output files were still being written.

This is not a bug in any single hook — it is the absence of a between-phase gate. Issue #49 fixes the *intra-phase* deliverable check (output_files present before phase task completion). This issue is *inter-phase*: even with #49, nothing prevents a downstream phase task from being marked `in_progress` or `completed` while upstream phases are unfinished.

### Reproduction

1. Run any pas-development cycle.
2. Observe the task list during discovery — planning and execution phase tasks can be claimed/completed in any order.

### Impact

- Phases interleave when the orchestration pattern intends strict ordering.
- Validation can run against an incomplete execution; release can fire before validation passes.
- The 60-test harness, status.yaml schema, and `verify-task-completion` hook collectively cannot catch this — they only enforce per-task deliverables, not phase ordering.

### Suggested fix (M4 design discussion)

Extend `verify-task-completion.sh` (or add a sibling hook on `TaskUpdate`) to:

- Read the phase order from process.md / status.yaml.
- Block `Phase: planning` from `in_progress` until `Phase: discovery` is `completed`.
- Block `Phase: execution` from `in_progress` until `Phase: planning` is `completed`.

Alternative: encode phase ordering as `blockedBy` task dependencies at workspace bootstrap so the existing TaskList tooling enforces it natively (`blockedBy: [<previous_phase_task_id>]`).

The second option is lighter-weight and reuses existing harness mechanics. Recommend prototyping it during M4.

### Source

Cycle 14 execution. Meta-evidence companion to #49.

---

## Issue 4 — Subagent self-eval filename mismatch — skill says `{agent}-{session_id}.md`, hooks accept `{agent}.md`

**Title:** Self-evaluation filename contract is ambiguous — `{agent}-{session_id}.md` vs `{agent}.md`

**Labels:** `bug`, `feedback-system`, `dogfood`

**Body:**

### Symptom

`library/self-evaluation/SKILL.md` (line 22 in cycle-14 source) prescribes:

> Write signals to `workspace/{process}/{slug}/feedback/{your-agent-name}-{session_id}.md`

But the cycle-14 workspace contains feedback files written under multiple shapes:

- `feedback/feedback-analyst.md` (no session ID)
- `feedback/orchestrator-cycle13.md` (cycle ID, not session ID)
- `feedback/orchestrator-S2.md` (session shorthand)
- `feedback/aa2190c327218adb9.md` (session ID alone, no agent name)
- `feedback/a4cb1041f550fb26f.md` (session ID alone)

The `verify-completion-gate.sh` hook only checks for `orchestrator-{SESSION_SHORT}.md`. Subagent self-evals can land under any of the above shapes and the hook accepts all of them — but the inconsistency means downstream tooling (feedback-analyst's backlog reconciliation, applying-feedback skill) has to handle five shapes.

Cycle-13's `dx-specialist` self-eval landed as `dx-specialist/feedback/backlog/2026-04-16-a4cb1041f550fb26f-OQI-02.md` — agent-rooted backlog path, session ID embedded in filename, no `{agent}-{session}` shape — yet another variation.

### Impact

- Tooling that scans the feedback dir cannot reliably attribute a file to an agent or a session.
- Cross-cycle reconciliation (this cycle's feedback-analyst job) requires fuzzy matching.
- Hook enforcement is loose enough that agents have written self-evals under names the gate would have accepted as valid for *another* agent's check.

### Suggested fix

- Pick one canonical shape and enforce it everywhere: recommend `feedback/{agent-name}-{session-short}.md` per the existing skill text.
- Update `check-self-eval.sh` and `verify-completion-gate.sh` to reject any other shape with a clear error pointing at the skill.
- Update the skill to cover the no-work-done case (agent shut down idle): per cycle-13 `dx-specialist` OQI-02, write `No issues detected.` to the canonical filename immediately after READY handshake.
- Decide whether subagent self-evals (one-shot agents) write to backlog or workspace — current state has both.

### Source

Cycle 14 feedback dir scan; cycle 13 dx-specialist OQI-02; cycle 14 dx-specialist OQI-02 (`agents/dx-specialist/feedback/backlog/2026-04-16-a4cb1041f550fb26f-OQI-02.md`).
