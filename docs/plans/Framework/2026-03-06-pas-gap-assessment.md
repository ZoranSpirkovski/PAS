# PAS Framework — Gap Assessment

> Created: 2026-03-06
> Input: PAS design v3→v4, MAPS future vision, Agent Skills open standard (agentskills.io)
> Process: Assess each gap → resolve with design decisions → update PAS design doc → enter plan mode for next gap

## How This Document Works

Gaps are listed in build-order priority. Each gap has:
- **Context**: Why this matters and what depends on it
- **Options**: 2-3 approaches with trade-offs
- **Resolution**: The chosen design decision (filled in during assessment)
- **Status**: `unresolved` | `resolved` | `deferred`

After each gap is resolved, the PAS design doc is updated with the decision.

---

## Resolved in Session 3 (Brainstorming)

These gaps were resolved through conversation before individual assessment began. Resolutions are captured in PAS design v4.

### Gap R1: Agent Skills Spec Alignment

**Status:** resolved

**Resolution:** PAS IS an Agent Skill with internal granularity. It's not a different thing from the Agent Skills spec — it takes the existing skill format (which already supports bundled sub-skills, see superpowers plugin) and adds agentic capabilities (spawning agents, orchestrating teams, collecting feedback) plus granularity so feedback can attach to the right element.

Library skills follow the Agent Skills spec format (SKILL.md with YAML frontmatter + markdown). Optional directories (scripts/, references/, assets/, evals/) are created when a skill actually needs them, not scaffolded empty. PAS additions (feedback/, changelog.md) sit alongside spec directories.

### Gap R2: When NOT to Use PAS

**Status:** resolved (dissolved)

**Resolution:** Everything the user wants to DO is a process. PAS makes process creation effortless (brainstorming-style conversation), so the overhead of "defining a process" is just answering a few questions. There's no threshold where something is "too small for PAS." If the user says `/pas` and describes any goal, PAS creates whatever is needed.

Users who want to "just do the thing" without PAS simply don't invoke `/pas`. PAS doesn't insert itself into non-PAS workflows.

### Gap R3: `/pas` Router Intelligence

**Status:** resolved

**Resolution:** The router IS the brainstorming conversation. `/pas` reads the user's message, applies the crystal clarity principle (never assume, ask until clear), and routes internally to process creation, feedback application, or process modification. It uses brainstorming-style one-question-at-a-time dialogue.

No menu. No sub-commands. The user describes what they want. PAS figures out which internal capability to use.

### Gap R4: First-Run Onboarding

**Status:** resolved

**Resolution:** Every interaction is the same, first time or hundredth time. The user invokes `/pas` and describes what they want. If no `pas-config.yaml` exists, PAS creates one with defaults (`feedback: enabled`). No onboarding wizard, no preference menus, no explanation of PAS concepts.

The first-run experience IS the normal experience: "What are you trying to achieve?"

### Gap R5: PAS Skills Portability / Multi-Scope

**Status:** resolved

**Resolution:** PAS artifacts (processes, agents, skills) default to project-level. No scope decisions are presented to casual users. For returning users, PAS can notice reusable patterns across projects and offer to promote artifacts to user-level (`~/pas/`). Power users can extract skills as standalone Agent Skills for marketplace distribution.

Progressive scope promotion, not upfront architecture decisions.

### Gap R6: Feedback Preferences

**Status:** resolved

**Resolution:** Feedback is always-on by default via a global `self-evaluation` skill carried by all agents, collected via hooks. No upfront preference questions.

Opt-out is conversational: PAS explains feedback is local-only and user-controlled. If user insists, `feedback: disabled` is set in `pas-config.yaml` with timestamp. PAS never mentions feedback again unless the user shows frustration signals ("you keep making the same mistakes"), at which point PAS offers reactivation.

```yaml
# pas-config.yaml
feedback: enabled          # enabled | disabled
feedback_disabled_at: ~    # ISO timestamp, set when user opts out
```

### Gap R7: Entry Point Design

**Status:** resolved

**Resolution:** `/pas` is the only user-facing command. Internal routing targets (creating-processes.md, creating-agents.md, creating-skills.md, applying-feedback.md) are never exposed to users. The process-first design means most interactions route to process creation, which internally triggers agent and skill creation as needed.

### Gap R8: Build Order

**Status:** resolved

**Resolution:** Internal build order follows process-first design:
1. Process creation (the core — it also triggers agent and skill creation)
2. Agent creation (called by process creation or router)
3. Skill creation (called by agent or process creation)
4. Feedback system (self-evaluation skill, message-routing skill, hooks)
5. `/pas` entry point (intelligent router, brainstorming conversation)

---

## Tier 1: Build-Blocking (must resolve before Phase 1-3)

### Gap 1: Agentless Phase Execution

**Status:** resolved (Session 4)

**Resolution:** `agent: none` is eliminated from the design. Every process has an **orchestrator agent** responsible for delivering the outcome. The orchestrator handles phases directly by reading its own skills (sourcing, editorial-review) or delegates to specialist agents.

The original three options were superseded by a deeper architectural decision: processes are recursive, skills are local to their process/agent, and every process has an orchestrator. The question "how does agentless execution work?" dissolved because there are no agentless phases.

**Key decisions:**
- Every process gets an orchestrator agent with its own identity, skills, feedback collection, and changelog
- The orchestrator reads its skills directly in its context (no subagent spawn for orchestrator-owned work)
- The orchestrator's role adapts to the orchestration pattern: hub-and-spoke = orchestrator, discussion = moderator, solo = operator
- Skills live inside their process or agent. Global library is only for skills with proven reuse across 2+ processes/agents
- Processes are recursive: a process can contain sub-processes, agents, and skills
- PAS starts lean (minimum viable agents) and grows through feedback

**Also resolved:** Gap 3 (Editor Role) — the editor becomes the orchestrator agent for the article process.

### Gap 2: Status Tracking States and Transitions

**Status:** resolved (Session 5)

**Resolution:** status.yaml is a **performance log per instance**, not just state tracking. It captures rich metadata to feed the feedback system with real performance data over time.

**Key decisions:**

- **Valid states:** Minimal by default — `pending`, `in_progress`, `completed`. Orchestrator can add process-specific states if needed by the user.
- **Metadata per phase:** status, agent, started_at, completed_at, duration_seconds, attempts, output_files, quality (score 1-10 + free-text notes). Duration is stored explicitly for easy cross-session comparison.
- **Quality self-assessment:** Simple score + notes. Agent self-reports at phase completion. No structured dimensions. A future global `library/reporting/` skill aggregates across instances.
- **Workspace separation:** Instances live at `workspace/{process}/{slug}/`, NOT inside the process definition directory. Blueprint (process definition) and runtime (workspace instances) are cleanly separated.
- **Sub-process rollup:** Hybrid. Each process/sub-process writes its own status.yaml within the instance. Parent references children via `subprocess:` field pointing to child status file path. Orchestrator reads child files for detail, sees high-level picture from parent alone.

**YAML format:**
```yaml
process: article
instance: 2026-03-06-sec-ruling
started_at: 2026-03-06T13:45:00Z
completed_at: ~
status: in_progress

phases:
  sourcing:
    status: completed
    subprocess: sourcing/status.yaml
    agent: orchestrator
    started_at: 2026-03-06T13:45:12Z
    completed_at: 2026-03-06T13:48:30Z
    duration_seconds: 198
    attempts: 1
    output_files:
      - research/source-analysis.md
    quality:
      score: 8
      notes: "Identified 3 primary sources, strong angle"
  research:
    status: in_progress
    subprocess: research/status.yaml
    agent: researcher
    started_at: 2026-03-06T13:49:00Z
    completed_at: ~
    duration_seconds: ~
    attempts: 1
    output_files: []
    quality: ~
```

**Workspace instance structure:**
```
workspace/
  article/
    2026-03-06-sec-ruling/
      status.yaml
      sourcing/
        status.yaml
      research/
        status.yaml
      verification/
        status.yaml
      research/
      article/
      media/
      promotional/
      feedback/
```

### Gap 3: Process-Level Agents / Editor Role

**Status:** resolved (Session 4)

**Resolution:** Every process has an **orchestrator agent** — a real agent with identity, skills, feedback collection, and changelog. For the article process, the legacy "editor" becomes the orchestrator.

The orchestrator:
- Owns skills for phases it handles directly (sourcing, editorial-review)
- Delegates to specialist agents for other phases
- Interfaces with the user at gates
- Is responsible for the process outcome
- Adapts its role to the orchestration pattern (hub-and-spoke = orchestrator, discussion = moderator, solo = operator)

This eliminates `agent: none` entirely. See Gap 1 resolution for full details.

### Gap 4: Error Handling

**Status:** resolved (Session 5)

**Resolution:** A four-step error handling chain with agent-first recovery and orchestrator escalation.

**Error handling chain:**
1. **Agent self-recovers first** — retries failed steps, works around issues internally
2. **Orchestrator monitors for hangs** — uses historical duration data from status.yaml for increasingly accurate hang detection over time
3. **Orchestrator retries once** — spawns a fresh agent if self-recovery fails
4. **Escalate to user** — if retry also fails, present full context (what failed, what was tried, partial output location)

**Failure scenario resolutions:**
- **Partial output:** Quarantine to `partial/` subfolder within the phase workspace. Retry starts clean but can reference quarantined output. Work is preserved, not lost.
- **Token budget exceeded:** The phase/skill is too complex and needs splitting. This is a design-time fix flagged via the feedback system, not a runtime fix. The framework is model-agnostic (200K Claude, 1M Gemini, etc.).
- **External dependency failure:** Agent tries alternatives first (different source, cached version). If stuck, report error and suggest by-the-book workarounds. Collaborate with user. Every external failure is logged in status.yaml quality notes.
- **Non-responsive agent:** Critical incident — should never happen. Orchestrator writes feedback on the agent's behalf, flagging non-responsiveness as high-severity requiring immediate remediation.

**Error policy location:** Global default in `library/orchestration/`, per-process override in `process.md`.

**Agent lifecycle — two-tier spawn model:**
- **Team members** (TeamCreate): Process-level agents. Persistent for full process lifecycle. Stay alive after their phase to receive downstream feedback at process end, write self-evaluation with full context, then all shut down together. Zero idle cost.
- **Subagents** (Agent tool): Ephemeral task helpers spawned by team members for subtasks. Fire-and-forget. Team members CAN spawn subagents (e.g., researcher spawns subagents for parallel web fetches).
- Process.md defines which agents are team members at design time.
- Context overhead per spawn: ~7-10k tokens (system prompt + compact buffer, unavoidable). Subagent use should be justified by parallelizable work offsetting the spawn cost.

**Shutdown sequence:**
1. All phases complete
2. Orchestrator sends each team member their downstream feedback
3. Each agent writes self-evaluation (quality score + notes) with full work context
4. All agents shut down together
5. Orchestrator finalizes parent status.yaml

### Gap 5: Phase Dependencies / Parallelism

**Status:** resolved (Session 5)

**Resolution:** The orchestrator infers parallelism from input/output dependencies. No explicit dependency graph in the YAML schema.

**Key decisions:**
- **No `depends_on` or `parallel` fields.** Phases are listed in default order. The orchestrator reads each phase's `input:` and `output:` fields to determine what can run in parallel.
- **Optional `sequential: true`** flag at process level to force linear execution even if I/O allows parallelism. Useful when deterministic ordering matters.
- Process authors control parallelism through I/O design: if phase B lists phase A's output as input, they run sequentially. If two phases share the same input but don't depend on each other, the orchestrator can run them in parallel.

**Example inference:**
```yaml
phases:
  sourcing:
    input: source material
    output: research/source-analysis.md
  research:
    input: research/source-analysis.md
    output: research/research-brief.md
  internal-links:
    input: research/source-analysis.md
    output: research/internal-links.md
  writing:
    input:
      - research/research-brief.md
      - research/internal-links.md
    output: article/draft.md
```

Orchestrator sees: `research` and `internal-links` both depend only on `sourcing` output. They can run in parallel. `writing` depends on both, so it waits for both to complete.

---

## Tier 2: Build-Important (Phases 4-6)

### Gap 6: Self-Evaluation Skill Content

**Status:** resolved (Session 6)

**Context:** The design specifies `self-evaluation` as an always-on global skill carried by all agents. It's the foundation of the feedback system. But the design doesn't specify what the skill actually instructs agents to do.

**Resolution:** The self-evaluation skill is adapted from a proven two-part feedback system: a Signal Extractor (per-session, agents write structured signals) and a Delta Applicator (batch upgrade, applies accumulated signals to artifacts). PAS maps these to its three feedback stages: Collect (self-eval skill) → Route (feedback router) → Apply (applying-feedback.md).

**Signal types — four categories, two push change, two resist change:**

| Type | Code | Purpose | Drives action? |
|---|---|---|---|
| Persistent Preference Update | PPU | User preferences with long-term implications | Yes — apply to artifact |
| Output Quality Issue | OQI | Issues that degraded output quality | Yes — fix in artifact |
| Stability Gate | GATE | Changes that should NOT be implemented | No — blocks bad changes |
| Stability Anchor | STA | Behavior that worked well and should be preserved | No — protects good behavior |

**Signal format:** Each signal includes:
- Signal type and ID (e.g., `[OQI-01]`)
- Short label
- `Target:` field pointing to exact PAS artifact (`skill:{name}`, `agent:{name}`, `process:{name}`)
- `Evidence:` quote or description from the session
- `Priority:` HIGH / MEDIUM / LOW
- For OQI: `Degraded:` category (ACCURACY / EFFICIENCY / RELEVANCE / TONE / FORMAT), `Root Cause:`, `Fix:` suggestion
- For PPU: `Frequency:` (ONE_TIME / REPEATED_2X / REPEATED_3X+ / IMPLIED_BY_CORRECTIONS)
- For STA: `Strength:` (CONFIRMED_BY_USER / OBSERVED), `Context:` description
- For GATE: `Why Rejected:`, `Alternative:` if applicable

**When written:** At shutdown, during the shutdown sequence (step 3 — after receiving downstream feedback, before final shutdown). Agents have full work context at this point, so the reflection is richer. Zero token cost during productive work.

**Agents detect, the applicator evaluates.** The self-eval skill tells agents: "Report what you observed. Use the signal types. Include evidence and target. Don't evaluate whether it's worth fixing — that's not your job." The quality improvement framework (Efficiency Test, Accuracy Test, Alignment Test, UX Test) lives in the feedback applicator, where it has the full picture across multiple sessions.

**Feedback saturation prevention (refined in Session 6, Gap 7 brainstorming):**
- OQI and PPU are the primary signals (things to fix/change). GATE blocks bad changes. STA is rare and defensive — only written when success occurred in a risky context that future changes might break. STA is NOT a default "everything was fine" signal.
- A smooth session produces a minimal note ("No issues detected"), not a list of positives. The correct outcome of a perfect session is minimal or no feedback.

**Recursive feedback boundary (refined in Session 6, Gap 7 brainstorming):**
- Hard boundary: the feedback system never automatically generates feedback about itself. The loop is strictly: work → feedback → apply → work. Never: work → feedback → feedback-about-feedback.
- Exception: user-initiated only. The user CAN point PAS at its own feedback system (e.g., "the routing keeps misclassifying signals"). That's normal user feedback routed to PAS's own artifacts. The feedback system CAN be upgraded, but only when the user explicitly asks.

**Feedback applicator behavior (resolved alongside):**
- Processes one artifact at a time. No cross-artifact bundling. If feedback targets a skill, it's in the skill's backlog. If it targets the agent, it's in the agent's backlog. Correctly targeted feedback means no duplicate root causes across artifacts.
- Threshold: 5 reports is a suggestion trigger, not a gate. User can apply anytime.
- When user triggers an apply, the applicator asks their preference:
  1. "Apply all feedback for this artifact" (full sweep, remember this preference)
  2. "Apply all feedback just this once" (full sweep, ask again next time)
  3. "Apply just this feedback" (targeted fix only)
  4. "Show me what's accumulated, I'll decide" (review first)
- Preference is remembered if user picks option 1. Otherwise asks each time.
- The applicator always reads the full backlog (to check for related signals), but only processes what the user selected.

**Relationship to Agent Skills eval framework:** The eval framework (evals/evals.json) tests skills with assertions and benchmarks — that's external testing. Self-evaluation is the agent's internal assessment during actual use. The two are complementary: evals test the skill in isolation, self-evaluation captures the agent's experience using it in production.

### Gap 7: Hook Implementation Details

**Status:** resolved (Session 6)

**Context:** The design defines three hooks (agent self-eval on SubagentStop, session feedback on Stop, feedback routing on Stop) but doesn't specify the actual commands or scripts.

**Resolution:** Gap 6's resolution that agents write self-eval during the shutdown sequence (step 3) eliminated the primary self-eval hook. Session feedback is handled by the orchestrator during finalization (step 5), not a hook. Only two hooks remain, both lightweight command hooks.

**Revised hook table (original 3 → 2 hooks):**

| Hook | Event | Type | Purpose |
|---|---|---|---|
| Self-eval safety net | SubagentStop | command | Checks if agent wrote self-eval file. If missing, logs warning. |
| Feedback routing | Stop | command | Routes workspace feedback signals to artifact backlogs. |

**Self-eval safety net hook (SubagentStop):**
- Shell script. Fires on SubagentStop for team member agents.
- Checks if the agent wrote a self-eval file to `workspace/{slug}/feedback/`.
- If missing: logs a warning note to the feedback inbox flagging the missing eval. The orchestrator's non-responsive agent handling (Gap 4) already covers this as a critical incident.
- If present: exits cleanly (no-op).
- Lightweight, no LLM calls.

**Session feedback (not a hook):**
- The orchestrator writes `session.md` to `workspace/{slug}/feedback/` as part of shutdown step 5.
- Always writes, even if brief when context-constrained.
- Subject to the saturation rule: if nothing went wrong, minimal note only.
- No fallback agent if orchestrator can't write it.

**Feedback routing hook (Stop):**
- Shell script. Guard: checks if feedback files exist in `workspace/{slug}/feedback/`. If none, exits 0. No config parsing needed — if feedback is disabled, no files were written, so there's nothing to process.
- For each feedback file: parses structured signals and their `Target:` fields, appends each signal to the target artifact's `feedback/backlog/` directory, cleans up the workspace feedback inbox after successful routing.
- Uses the structured format from Gap 6 (signal type, target, evidence, priority). The `Target:` field makes routing deterministic — no intelligence needed, just file operations.

**Feedback enabled/disabled behavior:**
- When `feedback: disabled` in pas-config.yaml: the entire feedback pipeline is off. No self-eval skill loaded, no signals written, no hooks fire (nothing to process). Complete silence.
- User can still manually request feedback about something specific via `/pas` conversation. That's user-initiated, not automatic.
- The config gate is at collection time (self-eval skill checks it), not routing time.

### Gap 8: Feedback Routing Intelligence

**Status:** resolved (Session 6)

**Context:** After a session ends, raw feedback (agent self-evaluations, session observations) needs to be classified and routed to the correct artifact's backlog: skill-level, agent-level, or process-level.

**Resolution:** The original classification problem dissolved. Gaps 6 and 7 established that agents write structured signals with explicit `Target:` fields pointing to exact PAS artifacts. The routing hook (Gap 7) just parses the target and moves the file. No intelligence needed at routing time.

**Routing is mechanical, intelligence lives in the applicator.** The feedback routing hook is a shell script that reads `Target:` fields and moves signals to the correct `feedback/backlog/` directory. The feedback applicator (`applying-feedback.md`) is where all intelligence lives. It performs sanity checks before applying any change:

1. **Target validation:** Does this signal actually belong to this artifact? (e.g., "writing was too long" landed on the writing skill, but the root cause might be the journalist agent's behavior rules — the applicator can re-route)
2. **Signal quality:** Is the evidence specific enough to act on, or is it vague?
3. **Duplicate detection:** Is this the same issue already flagged in a previous report?
4. **Conflict check:** Does this signal contradict a stability anchor (STA) on the same artifact?

If the applicator determines a signal was mis-targeted, it re-routes to the correct artifact's backlog and processes it there. Agent targeting is trusted as a best-effort first pass; the applicator validates with full context.

**Routed feedback file format:** Each signal is appended as a separate file in the artifact's `feedback/backlog/` directory. Filename convention: `{date}-{session-slug}-{signal-id}.md` (e.g., `2026-03-06-sec-ruling-OQI-01.md`). Content is the structured signal as written by the agent.

### Gap 9: Legacy Coexistence

**Status:** resolved (Session 6)

**Context:** Phase 6 rebuilds the article pipeline using PAS. During transition, the old system (flat agent files, prompts/, config/) coexists with the new PAS structure. The design says "move old system to legacy/" but the migration sequence matters.

**Resolution:** Move immediately at Phase 0. No gradual migration, no parallel running. The old system is not needed during PAS development.

**Migration sequence:**
1. Move old files to `legacy/` in a single commit (`.claude/agents/` flat files, `prompts/`, `config/`, `workspace/`, `existing_prompts/`, `experiments/`, `tools/`, `feedback/`)
2. Old `/article` skill stops working immediately. That's fine — PAS is the replacement.
3. Build PAS at root alongside `legacy/` (Phases 1-5)
4. Phase 6 rebuilds the article pipeline using PAS, referencing `legacy/` for content and structure where needed
5. `legacy/` remains as read-only reference throughout. Delete when PAS article pipeline is verified and stable.

No coexistence complexity. No dual-system testing. Clean break.

---

## Tier 3: Philosophical (may reshape design)

### Gap 10: Skill Granularity

**Status:** resolved (Session 6)

**Context:** The researcher agent currently has two skills: `research-planning` and `research-execution`. Should these be one `research` skill or stay as two?

**Resolution:** No universal rule. Three heuristics guide granularity decisions. Default to one skill (simpler). Split when any heuristic triggers.

**Three granularity heuristics:**

1. **Feedback heuristic:** Can you improve one part without touching the other? If yes, separate skills. If they always change together, one skill.
2. **Reuse heuristic:** Could another agent/process use one part but not the other? If yes, separate skills.
3. **Size trigger:** If a skill exceeds 5000 tokens, automatically flag for evaluation. The system prompts a review (skill-creator or feedback applicator) to evaluate: split, restructure, or explicitly justify the size.

Default to one skill. Split when usage proves it's needed. No hard line count as a rule — the 5000-token threshold is an automatic trigger for evaluation, not a hard limit.

### Gap 11: Changelog Format

**Status:** resolved (Session 6)

**Context:** Every PAS artifact (skill, agent, process) has a `changelog.md`. What goes in it?

**Resolution:** Git-derived with feedback context. Git commits already track what changed. The changelog captures what git can't: the *why* from feedback. When the feedback applicator upgrades an artifact, it writes a changelog entry linking the change to the feedback signals that triggered it.

**Format:**
```markdown
## 2026-03-06 — Scoped research plans to story complexity
Triggered by: OQI-01 (2026-03-06-sec-ruling), OQI-03 (2026-03-04-eth-merge)
Pattern: Research plans consistently too ambitious for single-angle stories
Change: Added scoping heuristic matching source count to story type
```

Dated entries with feedback provenance. Not Keep a Changelog (too rigid for AI-driven changes). Not pure free-form (too inconsistent). The feedback applicator writes these entries automatically as part of its apply workflow.

### Gap 12: Orchestration vs creating-agent-teams

**Status:** resolved (Session 6)

**Context:** The existing superpowers plugin has a `creating-agent-teams` skill with rich patterns for team composition, model tier selection, and agent type assignment. PAS plans `library/orchestration/` with hub-and-spoke, discussion, agentless, sequential-agents patterns.

**Resolution:** PAS fully absorbs the useful parts of `creating-agent-teams`. After PAS is built, the superpowers skill becomes redundant.

**What PAS absorbs:**
- **Team composition decisions** → `creating-processes.md` (when creating a process, PAS determines how many agents, what roles, team members vs subagents)
- **Model tier selection** → `creating-agents.md` (when creating an agent, PAS determines what model tier fits the role)
- **Orchestration pattern selection** → already in `library/orchestration/SKILL.md` (decision guide for which pattern to use)

After PAS is built, the user just invokes `/pas` and describes their goal. PAS handles team composition, model selection, and orchestration pattern internally. `creating-agent-teams` is not needed alongside PAS.

### Gap 13: Cross-Process Agent Feedback

**Status:** resolved (Session 6)

**Context:** If the same researcher agent is used in both an article process and a market-analysis process, feedback from both processes routes to the same backlog.

**Resolution:** Gap dissolved by design. Agents are always process-local. No global agents, no shared agents across processes. Every agent belongs to exactly one process.

**Key decisions:**
- If a new process needs a researcher, it creates a new researcher agent, possibly inspired by an existing one. But it's a copy, not a reference. Each process owns its agents fully.
- `library/` is for skills only. No global agent library.
- Progressive scope promotion (Session 3) applies to skills and processes, not agents.
- Cross-process agent feedback is impossible by design — the scenario never arises.
- Agent definitions stay clean with no conditional logic for different process contexts.
- New processes can reference existing agents for inspiration, but always create their own copy tailored to the process.

### Gap 14: Testing Strategy

**Status:** resolved (Session 6)

**Context:** How do we test PAS itself? The Agent Skills eval framework (evals/evals.json with assertions, benchmarks, iterations) provides a methodology for individual skills. But PAS also needs integration testing, sub-skill testing, and orchestration testing.

**Resolution:** Testing is built into PAS's creation workflows. Each creation skill owns its testing. No external plugin dependencies. The feedback system improves tests over time just like it improves everything else.

**Four testing levels:**

| Level | What's tested | Method | Created by | When |
|---|---|---|---|---|
| **Skill** | Individual skill output quality | Eval framework (`evals/evals.json` with input/output assertions) | `creating-skills.md` | Phase 3 |
| **Agent** | Agent behavior with its skills | Eval scenario (give agent representative task, check output + behavior) | `creating-agents.md` | Phase 2 |
| **Process** | End-to-end pipeline output | Integration test (run process, grade final output) | `creating-processes.md` | Phase 6 |
| **Feedback system** | Signals correctly collected, routed, applied | TDD cycle (RED: document wrong behavior, GREEN: fix, REFACTOR) | Manual during Phase 4 | Phase 4 |

**Key decisions:**
- Each creation skill includes a testing step: when PAS creates a skill, it also creates a basic eval. When it creates a process, it creates an integration test scenario.
- Eval format follows the Agent Skills spec (`evals/evals.json` with assertions) since PAS already aligns with that spec. But creation and execution of evals is PAS's own responsibility.
- TDD approach for discipline-enforcing skills (feedback system, orchestration). Eval framework for output-quality skills (writing, research).
- Both approaches are complementary. Start with basic tests at creation time, improve through feedback like everything else in PAS.

---

## Assessment Order

Work through gaps in this order. After each resolution:
1. Update this document with the decision
2. Update the PAS design doc (2026-03-05-pas-framework-design.md) with the resolved design
3. Enter plan mode for the next gap

**Tier 1 (build-blocking):**
1 → 2 → 3 → 4 → 5

**Tier 2 (build-important):**
6 → 7 → 8 → 9

**Tier 3 (philosophical):**
10 → 11 → 12 → 13 → 14
