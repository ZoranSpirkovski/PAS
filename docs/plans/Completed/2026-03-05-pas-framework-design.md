# PAS Framework — Design (v6)

> Updated after brainstorming sessions 1, 2, 3, 4, 5, and 6 (2026-03-06)
> Session 3: Gap assessment, Agent Skills spec alignment, UX philosophy, feedback design
> Session 4: Recursive process architecture, orchestrator agent, local-first skills, resumability
> Session 5: Status tracking format, error handling chain, agent lifecycle (two-tier model), phase parallelism
> Session 6: Self-evaluation skill content, feedback applicator behavior, hook implementation, feedback saturation prevention, recursive feedback boundary, skill granularity, changelog format, creating-agent-teams absorption, process-local agents, testing strategy
> Future evolution: see `2026-03-05-maps-framework-design.md` for the MAPS vision

## Summary

PAS (Process, Agent, Skill) is a modular framework for building agentic workplaces. It replaces the current monolithic `/article` pipeline with composable primitives that can be created, tested, improved, and combined into any process.

PAS is not a different thing from Agent Skills — it IS an Agent Skill with internal granularity. The Agent Skills spec (agentskills.io) defines how skills are structured. PAS takes the next step: separate Process, Agent, and Skill so feedback can attach to the right granular element and improve through usage. Skills already support bundled sub-skills (see superpowers plugin). PAS incorporates agentic capabilities (spawning agents, orchestrating teams, collecting feedback) to create a self-improving system.

Long-term goal: an open-source, domain-agnostic framework anyone can use to get good operational results at any skill level. PAS is the foundation; MAPS (Mission, Agents, Processes, Skills) is the future evolution.

## The Problem

The current system is monolithic. `/article` is a 127-line skill that handles everything from input gathering to team cleanup. Feedback extraction is hardcoded. Prompts are standalone files agents read directly. Nothing is composable or independently improvable. Result: you can't fix one thing without touching everything.

## Core Philosophy

**Clean separation of responsibilities:**

| Concept | Role | One-liner |
|---|---|---|
| **Process** | WHY + WHAT + WHEN | The goal and the plan to achieve it |
| **Agent** | WHO | The specialist who does the work |
| **Skill** | HOW | The technique they use |

**One sentence:** A Process assigns Agents work toward a goal, and Agents use Skills to do it.

- **Skills** are composable instruction sets. They define HOW to do a specific thing. Skills are agent-facing only. Users never interact with skills directly. Skills follow the Agent Skills open standard (SKILL.md format, progressive disclosure, optional scripts/references/assets/evals directories). Skills live inside their process or agent by default. Only skills with proven reuse across 2+ processes/agents are graduated to the global library.
- **Agents** are specialists with identities, tools, and skills they carry. An agent KNOWS how to do its job because it owns the relevant skills. Agents can also contain processes and skills. Every process has an **orchestrator agent** responsible for its success — it handles phases directly or delegates to specialist agents. **Agents are always process-local** (resolved in Session 6) — no global agents, no shared agents across processes. Each process owns its agents fully. New processes can reference existing agents for inspiration but always create their own copy.
- **Processes** define WHAT needs to happen, in WHAT ORDER, to achieve a specific GOAL. They assign work to agents, define phase gates, and manage flow. The process is the entry point — users describe what they want to DO, and PAS extrapolates the agents and skills needed. **Processes are recursive** — a process can contain sub-processes, agents, and skills.

### Recursive Composition (Resolved in Session 4)

PAS is a recursive, tree-like structure. Each layer can contain any other layer:

- **Process** → can contain processes, agents, skills
- **Agent** → can contain processes, skills
- **Skill** → instructions (leaf node)

This gives maximum feedback granularity. Feedback attaches to the exact level where the issue lives — a sub-process, a specific agent, or a particular skill. The tree structure makes it possible to provide and apply feedback in complex agentic pipelines at the appropriate position.

### Start Lean, Grow Through Feedback (Resolved in Session 4)

PAS creates the minimum viable agent set for the process scope. A social media post might need just an orchestrator with a writing skill. A full newsroom needs an orchestrator plus specialist agents. More structure is added only when usage establishes the need. Quick wins first, depth later.

### Process-First Design (Resolved in Session 3)

The process is always the starting point because it captures the user's intent. Users don't create skills then agents then processes. They describe a goal, and PAS creates the process definition, then determines what agents and skills are needed to execute it.

```
User describes goal
  → PAS asks clarifying questions (brainstorming-style)
  → PAS extrapolates required agents and skills
  → Creates process + agents + skills in one flow
  → User runs the process
  → Feedback improves the granular pieces over time
```

### Crystal Clarity Principle (Resolved in Session 3)

PAS never pretends to understand what the user wants. Before creating a system or applying feedback:

- **Evaluate definitiveness**: Is this feedback/request clear enough to act on?
- **Apply Occam's razor**: Choose the answer with the fewest assumptions.
- **Ask until clear**: Bring the user to a crystal clear decision before proceeding.

This applies to both process creation ("What exactly do you want to achieve?") and feedback application ("This change would affect X, Y, Z — is that what you want?").

## Actor Model

```
USER
  |
  |  /pas "I want to build a crypto newsroom"
  |
  v
PAS (brainstorming-style conversation)
  |
  |  Understands goal → creates process + agents + skills
  |
  v
ORCHESTRATOR AGENT (runs the process)
  |
  |-- Reads workspace status to determine where to resume
  |-- Handles phases directly using its own skills (sourcing, editorial)
  |-- Delegates to SPECIALIST AGENTS (who carry their own skills)
  |-- Manages gates with USER (supervised mode)
  |-- Collects feedback via always-on self-evaluation skill
  |-- Updates workspace status continuously
  |
  v
SESSION ends -> hook fires -> feedback routing -> cleanup
```

| Term | What it is |
|---|---|
| **User** | The human. Describes goals, reviews at gates, provides feedback. |
| **PAS** | The framework, invoked via `/pas` only |
| **Process** | A definition file, the blueprint. Can contain sub-processes, agents, and skills. |
| **Orchestrator** | The agent responsible for delivering the process outcome. Every process has one. Adapts role to orchestration pattern (orchestrator, moderator, operator). |
| **Agent** | A specialist who carries skills and receives work from the orchestrator. Can contain processes and skills. |
| **Skill** | A composable instruction set, loaded by agents (not user-facing). Lives inside its process or agent by default. |

## Entry Point: `/pas` Only (Resolved in Session 3)

A single intelligent entry point. No sub-commands for users. Internally, PAS routes to the right capability:

```
/pas                        The only user-facing command
```

The user writes `/pas` followed by whatever they want. PAS figures out the rest:

- "I want to build a crypto newsroom" → process creation flow
- "The researcher keeps going down rabbit holes" → feedback application
- "I need to add a fact-checking step" → process modification

Internal routing targets (not user-facing):
```
.claude/skills/pas/
  SKILL.md                  # Entry point, intelligent router
  creating-processes.md     # Internal: process creation
  creating-agents.md        # Internal: agent creation
  creating-skills.md        # Internal: skill creation
  applying-feedback.md      # Internal: feedback review and application
```

## Multi-Scope Architecture (Resolved in Session 3)

PAS artifacts (processes, agents, skills) can exist at multiple scopes. Default is project-level. Users are never burdened with scope decisions upfront.

### Scope Levels

| Scope | Location | Purpose |
|---|---|---|
| **Project** | `processes/`, `library/` | Specific to this repo (default) |
| **User** | `~/pas/processes/`, `~/pas/library/` | Reusable across all projects |

Note: Agents are always process-local (resolved in Session 6). They do not promote to user scope. Only skills and processes can be promoted. `library/` is for skills only.

### Progressive Scope Promotion

Scope decisions happen naturally, not upfront:

| User type | Scope behavior |
|---|---|
| **Try-once** | Everything project-level. No scope questions asked. |
| **Returning** | PAS notices patterns across projects: "This researcher agent looks similar to one in project X. Want to promote it to user-level?" |
| **Power user** | Curates user-level library. Can extract skills as standalone Agent Skills for marketplace. |

The logic for cross-project discovery scans `~/pas/` and other project directories the user has worked in. This is deferred until a user has multiple PAS projects.

### Marketplace Extraction

Power users can extract any PAS artifact as a standalone Agent Skill compatible with the open standard (agentskills.io). PAS can assist with packaging for the GitHub marketplace. This is a future feature, not a launch requirement.

## Directory Structure

```
.claude/                         # Claude Code platform requirement
  skills/                        # Thin launchers for slash commands
    pas/                         # PAS framework (single entry point)
      SKILL.md                   # /pas — intelligent router
      creating-processes.md      # Internal routing target
      creating-agents.md         # Internal routing target
      creating-skills.md         # Internal routing target
      applying-feedback.md       # Internal routing target
    article/SKILL.md             # Thin launcher -> reads processes/article/
  settings.json                  # Project hooks

processes/                       # Self-contained process packages
  article/
    process.md                   # Top-level process definition
    agents/
      orchestrator/              # The orchestrator agent for this process
        agent.md
        skills/
          sourcing/SKILL.md
          editorial-review/SKILL.md
        feedback/
          backlog/
        changelog.md
      researcher/
        agent.md
        skills/
          research-planning/SKILL.md
          research-execution/SKILL.md
          internal-links/SKILL.md
        feedback/
          backlog/
        changelog.md
      fact-checker/
        agent.md
        skills/
          verification/SKILL.md
        feedback/
          backlog/
        changelog.md
      journalist/
        agent.md
        skills/
          writing/SKILL.md
          audit/SKILL.md
        feedback/
          backlog/
        changelog.md
      publisher/
        agent.md
        skills/
          seo/SKILL.md
          image-generation/SKILL.md
          song-generation/SKILL.md
          distribution/SKILL.md
        feedback/
          backlog/
        changelog.md
    processes/                   # Sub-processes (recursive)
      sourcing/
        process.md
        skills/...
        feedback/
          backlog/
      research/
        process.md
        agents/...
        skills/...
        feedback/
          backlog/
      verification/
        process.md
        agents/...
        feedback/
          backlog/
      writing/
        process.md
        agents/...
        feedback/
          backlog/
      editorial-review/
        process.md
        skills/...
        feedback/
          backlog/
      publishing/
        process.md
        agents/...
        feedback/
          backlog/
    modes/
      supervised.md
      autonomous.md
    config/
      publications/
        crypto-news-net/
          publication.md
          style-guide.md
          seo-rules.md
          categories.md
          evergreen-links.md
          image-style.md
    reference/
      reuters-principles.md
      reuters_handbook_of_journalism.md
    tools/
      make-video.sh
    feedback/
      backlog/                   # Top-level process feedback
    changelog.md

workspace/                         # Runtime instances (separate from process definitions)
  article/                         # Instances grouped by process
    {date-slug}/                   # One instance per run
      status.yaml                  # Performance log, updated continuously
      sourcing/
        status.yaml                # Sub-process status
      research/
        status.yaml
      verification/
        status.yaml
      research/                    # Agent output folders
      article/
      media/
      promotional/
      feedback/                    # Session inbox, agents write raw feedback here
      partial/                     # Quarantined partial output from failed phases

library/                         # Global skills only (graduated after 2+ reuses)
  orchestration/
    SKILL.md                     # Decision guide, which pattern to use
    hub-and-spoke.md             # Execution rules for hub-and-spoke
    discussion.md                # Execution rules for discussion mode
    solo.md                      # Rules for single-agent execution
    sequential-agents.md         # One agent at a time, handoff between phases
  message-routing/
    SKILL.md                     # Classifies user messages at gates
  self-evaluation/
    SKILL.md                     # Always-on feedback collection skill
  # Other global skills added here only when proven reuse across 2+ processes/agents

pas-config.yaml                  # User preferences, persisted across sessions

reference/                       # Global reference docs (not process-specific)
  claude-code-capabilities.md    # PAS building blocks reference (timestamped)
  suno.md
  suno-experiments.md
  macedonian-songwriting.md

legacy/                          # Old system (frozen, moved here immediately)
  prompts/
  config/
  workspace/
  existing_prompts/
  experiments/
  tools/
```

**Key distinctions:**
- `.claude/skills/` = Claude Code platform requirement, thin launchers only (user-facing slash commands)
- `processes/` = self-contained process packages. Agents and skills live inside their process. Processes can contain sub-processes (recursive).
- `library/` = global skills only. A skill is graduated to the library when it is used in 2+ processes/agents. Starts with framework-level skills (orchestration, message-routing, self-evaluation).
- `pas-config.yaml` = user preferences, referenced from CLAUDE.md
- Every PAS artifact (skill, agent, process) has its own `feedback/backlog/` and `changelog.md`
- Skills follow Agent Skills spec format (YAML frontmatter + markdown). May optionally include `scripts/`, `references/`, `assets/`, `evals/` subdirectories.

## Process Definition Format (Declarative)

```yaml
# processes/article/process.md

name: article
goal: Produce a publish-ready news article from source material
version: 1.0
orchestration: hub-and-spoke
sequential: false                # Optional: set true to force linear execution
modes: [supervised, autonomous]

input:
  - publication: which publication config to use
  - mode: supervised or autonomous
  - source: X feed, press release, or story URL

phases:
  sourcing:
    process: sourcing
    agent: orchestrator
    input: source material from user
    output: research/source-analysis.md
    gate: user selects story

  research:
    process: research
    agent: researcher
    input: research/source-analysis.md
    output:
      - research/research-brief.md
      - research/internal-links.md
    gate: orchestrator reviews research brief

  verification:
    process: verification
    agent: fact-checker
    input: research/research-brief.md
    output: research/verification-report.md
    gate: orchestrator reviews red flags

  writing:
    process: writing
    agent: journalist
    input:
      - research/research-brief.md
      - research/verification-report.md
      - research/internal-links.md
    output:
      - article/draft.md
      - article/audit-report.md
    gate: orchestrator reviews draft

  editorial:
    process: editorial-review
    agent: orchestrator
    input: article/draft.md
    output: article/draft.md (revised)
    gate: user approves for publishing

  publishing:
    process: publishing
    agent: publisher
    input: article/draft.md
    output:
      - article/seo-metadata.md
      - article/final.html
      - media/image-prompt.md
      - media/song-prompt.md
      - media/video-image-prompt.md
    gate: user approves final package

status_file: workspace/article/{slug}/status.yaml
```

**Key changes from v4:**

- **No `agent: none`.** Every phase has an agent. The orchestrator handles phases directly (sourcing, editorial) using its own skills. It delegates other phases to specialist agents.
- **Each phase references a sub-process.** The `process:` field points to a sub-process in `processes/`. Sub-processes have their own status, agents, skills, and feedback. This gives maximum feedback granularity.
- **Agents and skills are local to the process.** They live inside `processes/article/agents/` and `processes/article/agents/{name}/skills/`. Only globally reusable skills live in `library/`.
- **Status is updated continuously.** The workspace status file is written at every state change, enabling the orchestrator to resume from any point if a session is interrupted.

## Process Execution Engine (Resolved)

The process.md is declarative. The execution engine is a **hybrid of two components**:

1. **process.md** = the WHAT (phases, sub-processes, agents, skills, gates, deliverables)
2. **Orchestration pattern skill** = the HOW (spawn order, parallelism, status tracking, error handling)

The process.md declares `orchestration: hub-and-spoke`, and the orchestrator loads `library/orchestration/hub-and-spoke.md` for execution rules. The thin launcher in `.claude/skills/article/SKILL.md` wires the two together:

```markdown
# Article

Read `processes/article/process.md` for the process definition.
Read the orchestration pattern from `library/orchestration/` as specified in the process.
Execute.
```

No generic executor needed. Claude interprets the YAML as structured instructions and the orchestration skill provides execution patterns.

### Orchestrator Agent (Resolved in Session 4)

Every process has an orchestrator agent responsible for delivering the outcome. The orchestrator:

- Reads the process definition and orchestration pattern
- Handles phases directly by reading its own skills (e.g., sourcing, editorial-review)
- Delegates phases to specialist agents via team members (see Agent Lifecycle below)
- Interfaces with the user at gates (supervised mode)
- Updates workspace status continuously
- Reads workspace status on startup to resume from where a previous session stopped
- Collects feedback via the self-evaluation skill
- Monitors agents for hangs using historical duration data

The orchestrator's role adapts to the orchestration pattern:

| Pattern | Orchestrator role |
|---|---|
| hub-and-spoke | Orchestrator — central hub, all agents communicate through it |
| discussion | Moderator — facilitates multi-agent discussion |
| solo | Operator — single agent, no delegation |

### Agent Lifecycle — Two-Tier Spawn Model (Resolved in Session 5)

PAS uses two mechanisms for spawning agents, determined at design time in process.md:

| Tier | Mechanism | Lifecycle | Use case |
|---|---|---|---|
| **Process agents** | TeamCreate | Persistent — alive for full process | Researcher, Journalist, Fact-Checker |
| **Task helpers** | Agent tool (spawned by team members) | Ephemeral — fire-and-forget | A researcher's helper to check one specific source |

**Why teams, not subagents:** The expensive part of agent creation is the upfront spawn cost (~7-10k tokens for system prompt + compact buffer). Once alive, idle agents cost zero tokens. Keeping agents alive as team members means:
- They retain full work context for richer self-evaluation
- They can receive downstream feedback from later phases
- No re-spawn cost if they're needed again
- Team members CAN spawn their own subagents for parallelizable subtasks

**Shutdown sequence:**
1. All phases complete
2. Orchestrator sends each team member their downstream feedback
3. Each agent writes self-evaluation (quality score + notes) with full work context
4. All agents shut down together
5. Orchestrator finalizes parent status.yaml

### Resumability (Resolved in Session 4)

Every process instance writes status to `workspace/{process}/{slug}/status.yaml` continuously as work progresses. If a session is interrupted (context limits, user leaves), the orchestrator reads the status file on the next session start and picks up from the last completed point. The orchestrator is responsible for completing the process to a high degree of quality regardless of how many sessions it takes.

### Status Tracking Format (Resolved in Session 5)

status.yaml is a **performance log per instance**, not just state tracking. It captures rich metadata that feeds the feedback system with real performance data over time.

**Valid states:** Minimal by default — `pending`, `in_progress`, `completed`. Orchestrator can add process-specific states if deemed necessary by the user.

**Metadata per phase:** status, agent, started_at, completed_at, duration_seconds, attempts, output_files, quality (score 1-10 + free-text notes).

**Sub-process rollup:** Each process/sub-process writes its own status.yaml. Parent references children via `subprocess:` field.

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
```

A future global `library/reporting/` skill will aggregate performance data across instances for trend analysis (agent speed, quality averages, phase duration comparisons).

### Error Handling (Resolved in Session 5)

**Error handling chain:**
1. **Agent self-recovers first** — retries failed steps, works around issues internally
2. **Orchestrator monitors for hangs** — uses historical duration data from status.yaml for increasingly accurate detection
3. **Orchestrator retries once** — spawns a fresh agent if self-recovery fails
4. **Escalate to user** — if retry also fails, present full context

**Failure scenarios:**
- **Partial output:** Quarantine to `partial/` subfolder. Retry starts clean but can reference quarantined output.
- **Token budget exceeded:** Phase/skill is too complex, needs splitting. Design-time fix via feedback system. Framework is model-agnostic (200K Claude, 1M Gemini, etc.).
- **External dependency failure:** Agent tries alternatives first, then reports error with by-the-book workaround suggestions. Collaborate with user.
- **Non-responsive agent:** Critical incident. Orchestrator writes feedback on their behalf flagging non-responsiveness as high-severity.

**Error policy:** Global default in `library/orchestration/`, per-process override in `process.md`.

### Phase Parallelism (Resolved in Session 5)

The orchestrator infers parallelism from input/output dependencies declared in process.md. No explicit `depends_on` or `parallel` fields needed.

- Phases sharing the same input but not depending on each other can run in parallel
- Phases listing another phase's output as input must wait for it
- Optional `sequential: true` flag at process level forces linear execution

```yaml
# Orchestrator infers: research and internal-links can run in parallel
# (both depend only on sourcing output). Writing waits for both.
phases:
  sourcing:
    output: research/source-analysis.md
  research:
    input: research/source-analysis.md
    output: research/research-brief.md
  internal-links:
    input: research/source-analysis.md
    output: research/internal-links.md
  writing:
    input: [research/research-brief.md, research/internal-links.md]
    output: article/draft.md
```

## Mode File Format (Resolved)

Modes are defined in separate files under `modes/`. They have a **structured header + prose behavior rules**:

```yaml
# processes/article/modes/supervised.md

---
name: supervised
description: User reviews and approves at every phase gate
gates: enforced
---

## Behavior

- After each phase completes, STOP and present the output to the user
- Do NOT launch the next phase until the user says "go" or "approved"
- Present a summary of what was produced, key findings, and any concerns
- If the user requests changes, route them to the appropriate agent

## Gate Protocol

At each gate:
1. Show phase output summary (not raw files unless asked)
2. Flag any quality concerns or red flags
3. Ask: "Approve and continue, or request changes?"
```

The structured header gives the orchestration skill machine-readable data (are gates enforced?). The prose section gives Claude the nuanced behavioral instructions it needs.

## Agent Definition Format (Resolved)

Agents own their core skills. Skills live inside the agent's directory. Agent definitions include identity, behavioral traits, owned skills, and known pitfalls (where feedback accumulates). Agents live inside their process directory, not at the project root.

```yaml
# processes/article/agents/researcher/agent.md

---
name: researcher
description: Deep research specialist with web access
tools: [Read, Write, Edit, Grep, Glob, WebSearch, WebFetch]
skills:
  - skills/research-planning/SKILL.md
  - skills/research-execution/SKILL.md
  - skills/internal-links/SKILL.md
---

# Researcher

## Identity
You are a research specialist. You gather, verify, and synthesize
information from multiple sources into structured research briefs.

## Behavior
- Prioritize primary sources over secondary
- Always note source URLs and access timestamps
- Flag confidence levels on each finding
- Write structured output, not stream-of-consciousness

## Deliverables
- research-brief.md (structured findings with sourced claims)

## Known Pitfalls
(Populated by feedback over time)
- Tends to create overly ambitious research plans when not scoped
- Can duplicate work that was already done in sourcing phase
```

The orchestrator spawn prompt says: "You are the researcher (read your agent.md and your skills). Write output to workspace/{slug}/research/."

## User Interaction Model

### What the User Does

The user's job is simple:
1. **Invoke `/pas`** and describe what they want
2. **Answer clarifying questions** until PAS has crystal clarity
3. **Review output at gates** (supervised mode)
4. **Provide feedback when something's wrong**

That's it. Users never interact with skills directly. Skills are agent-facing. Users never need sub-commands. PAS routes internally.

### Feedback as First-Class Interaction

When the user provides feedback at a gate, the orchestrator (session) uses the `library/message-routing/` skill to classify the message:

| Classification | What happens |
|---|---|
| **Approval** | "looks good, continue" -> proceed to next phase |
| **Feedback/complaint** | "this is too promotional" -> fix in session + queue as permanent improvement |
| **Question** | "why this angle?" -> answer, then continue |
| **Instruction** | "also include the SEC filing" -> incorporate, then continue |

When feedback is detected, the framework does two things:
1. **Fixes the current session** (always, this is just doing the work)
2. **Queues for permanent improvement** (silently, if feedback is enabled)

### Self-Evaluation Skill Content (Resolved in Session 6)

The `library/self-evaluation/SKILL.md` is carried by all agents. It instructs agents to write structured improvement signals at shutdown (step 3 of the shutdown sequence — after receiving downstream feedback, before final shutdown). Zero token cost during productive work.

**Four signal types:**

| Type | Code | Purpose | Drives action? |
|---|---|---|---|
| Persistent Preference Update | PPU | User preferences with long-term implications ("stop doing X", "always do Y") | Yes — apply to artifact |
| Output Quality Issue | OQI | Issues that degraded output (factual errors, instruction non-compliance, inefficiency) | Yes — fix in artifact |
| Stability Gate | GATE | Changes that should NOT be implemented (frustration-driven, safety-degrading) | No — blocks bad changes |
| Stability Anchor | STA | Behavior confirmed to work well, must be preserved during future upgrades | No — protects good behavior |

PPU and OQI push change. GATE and STA resist change. The tension between them prevents regression during improvement.

**Each signal includes:**
- Signal type and ID (e.g., `[OQI-01]`)
- `Target:` pointing to exact PAS artifact (`skill:{name}`, `agent:{name}`, `process:{name}`)
- `Evidence:` quote or description from the session
- `Priority:` HIGH / MEDIUM / LOW
- Type-specific fields: `Degraded:`/`Root Cause:`/`Fix:` for OQI, `Frequency:` for PPU, `Strength:` (CONFIRMED_BY_USER / OBSERVED) for STA, `Why Rejected:`/`Alternative:` for GATE

**Agents detect, the applicator evaluates.** The self-eval skill tells agents: "Report what you observed. Include evidence and target. Don't evaluate whether it's worth fixing." The quality improvement framework (Efficiency Test, Accuracy Test, Alignment Test, UX Test) lives in the feedback applicator, which has cross-session context to judge what's worth changing.

**Feedback saturation prevention:** OQI and PPU are the primary signals. STA is rare and defensive — only written when success occurred in a risky context that future changes might break. A smooth session produces a minimal note ("No issues detected"), not a list of positives. The correct outcome of a perfect session is minimal or no feedback.

### Recursive Feedback Boundary (Resolved in Session 6)

Hard boundary: the feedback system never automatically generates feedback about itself. The loop is strictly: **work → feedback → apply → work**. Never: work → feedback → feedback-about-feedback.

Exception: user-initiated only. The user CAN point PAS at its own feedback system (e.g., "the routing keeps misclassifying signals"). That's normal user feedback routed to PAS's own artifacts. The feedback system CAN be upgraded, but only when the user explicitly asks PAS to look at itself.

### Feedback: Always-On Default (Resolved in Session 3)

Feedback collection is enabled by default. It's a global skill (`self-evaluation`) used by all agents, gathered via hooks. The user is never asked about feedback preferences upfront.

```yaml
# pas-config.yaml

feedback: enabled          # enabled | disabled
feedback_disabled_at: ~    # ISO timestamp, set when user opts out
```

**Opt-out flow (conversational, not a config toggle):**

1. Feedback gathers silently by default
2. User says "I don't want feedback collected"
3. PAS explains: "Feedback is stored locally in your project folders. You can review it anytime. It's only applied when you explicitly ask. Nothing is sent anywhere."
4. User insists → PAS respects the choice, sets `feedback: disabled` in pas-config.yaml
5. Later, if user shows frustration ("you keep making the same mistakes", "I'm tired of repeating myself") → PAS offers to reactivate feedback or apply improvements immediately

PAS reads `pas-config.yaml` on session start. If `feedback: disabled`, PAS never mentions feedback. The only trigger to revisit is user frustration signals.

### Feedback Routing (Orchestrator Skill, Not Hook)

The orchestrator already receives every user message at gates. It uses `library/message-routing/SKILL.md` to classify and route. No hook needed for in-session feedback — the orchestrator IS the router.

Hooks are reserved for post-session tasks (collecting agent self-evaluations, routing workspace feedback to backlogs).

## Feedback System (Three Stages)

### Stage 1: Collect (during session)

**Agent self-evaluations:** Each agent carries the `self-evaluation` skill (global, always-on when feedback enabled). Agents write raw feedback to the workspace inbox during execution:

```
workspace/{slug}/feedback/
  researcher.md          # Self-eval, issues, token notes
  journalist.md
  fact-checker.md
  publisher.md
  session.md             # Process-level observations from the session
```

**User feedback at gates:** Classified by the orchestrator's message-routing skill. Session fixes applied immediately. Permanent improvements queued silently to workspace feedback inbox.

### Stage 2: Route (hook-triggered, after session)

On session end, a hook calls the feedback agent with:
- Which process just completed
- Where the workspace feedback is

The feedback agent reads the workspace inbox, classifies each observation, and routes to the correct artifact's backlog within the process tree:

```
processes/article/feedback/backlog/                              <- top-level process issues
processes/article/processes/research/feedback/backlog/            <- sub-process issues
processes/article/agents/researcher/feedback/backlog/             <- agent issues
processes/article/agents/journalist/skills/writing/feedback/backlog/  <- skill issues
```

### Stage 3: Apply (user-invoked via `/pas`) (Updated in Session 6)

User invokes `/pas` and describes wanting to review/apply feedback (or PAS suggests it when backlogs reach 5+ reports for an artifact — a suggestion trigger, not a gate).

**Applicator works one artifact at a time.** No cross-artifact bundling. Feedback targeting a skill lives in the skill's backlog. Feedback targeting an agent lives in the agent's backlog. Correctly targeted signals mean no duplicate root causes across artifacts.

**When user triggers an apply, the applicator asks their preference:**
1. "Apply all feedback for this artifact" (full sweep, remember this preference going forward)
2. "Apply all feedback just this once" (full sweep, ask again next time)
3. "Apply just this feedback" (targeted fix only)
4. "Show me what's accumulated, I'll decide" (review first — applicator reads the backlog anyway to check for related signals)

The applicator always reads the full backlog to understand context, but only processes what the user selected. If user picks option 1, the preference is remembered and future applies do full sweeps without asking.

**Apply workflow (adapted from the Delta Applicator pattern):**
1. Parse all signals from the artifact's backlog
2. Sanity checks on each signal (resolved in Session 6, Gap 8):
   - **Target validation:** Does this signal actually belong to this artifact, or was it mis-targeted? Re-route if needed.
   - **Signal quality:** Is the evidence specific enough to act on?
   - **Duplicate detection:** Is this the same issue already flagged in a previous report?
   - **Conflict check:** Does this signal contradict a stability anchor (STA) on the same artifact?
3. Identify cross-report patterns (same issue flagged in 3+ reports = strong pattern, 2 reports with HIGH priority = moderate pattern)
3. Resolve contradictions (most recent wins, highest frequency wins, context-conditional merge, or escalate to user)
4. Evaluate definitiveness — is the feedback clear enough to act on?
5. Apply Occam's razor — fewest assumptions
6. If ambiguous: ask user for crystal clarity before proceeding
7. Apply changes with consolidation-first approach (prefer tightening existing instructions over adding new ones)
8. Check stability anchors (STA signals) — warn if proposed changes could affect behavior confirmed to work well
9. Present upgraded artifact + changelog for approval
10. Update the artifact's `changelog.md`
11. Clear processed signals from the backlog

## First-Time User Experience (Resolved in Session 3)

Every interaction starts the same way, whether first time or hundredth time:

1. **User invokes `/pas`** and describes what they want to achieve
2. **PAS detects no `pas-config.yaml`** → creates one with defaults (`feedback: enabled`)
3. **PAS asks clarifying questions** (brainstorming-style, one at a time)
4. **PAS creates process + agents + skills** based on understood goal
5. **User runs their first process** in supervised mode

No onboarding wizard. No preference menus. The same conversational flow handles new users, returning users, and power users. PAS asks about the goal, not about PAS itself.

## Internal Sub-Skill Descriptions

### SKILL.md (Entry Point)

Intelligent router for the PAS framework. Reads user's message, applies crystal clarity principle (never assume, ask until clear), routes to the right internal capability. Uses brainstorming-style conversation to understand user intent before creating anything.

### creating-processes.md (Internal)

Creates a process from a user's goal description.

1. Ask clarifying questions until the goal is crystal clear
2. Read `reference/claude-code-capabilities.md` for format rules
3. Determine phases needed to achieve the goal
4. Determine agents needed per phase (create new or reference existing)
5. Determine skills needed per agent (create new or reference existing)
6. Read `library/orchestration/SKILL.md` to select orchestration pattern
7. Scaffold process directory (process.md, modes/, config/, reference/, tools/, feedback/, changelog.md, workspace/)
8. Create agent directories for any new agents
9. Create library skills for any new skills
10. Create thin launcher in `.claude/skills/{name}/SKILL.md`
11. Offer to run the process immediately

### creating-agents.md (Internal)

Creates or edits an agent. Usually called by creating-processes.md, not directly by the router.

1. Read `reference/claude-code-capabilities.md` for format rules
2. Determine role, tool access, base behavior, core skills
3. Check existing agents within the process for overlap
4. Generate agent definition (identity + tools + skills + behavior + deliverables)
5. Create agent directory with agent.md, skills/, feedback/backlog/, changelog.md
6. Write to `processes/{name}/agents/{agent-name}/`

### creating-skills.md (Internal)

Creates or edits a composable skill. Usually called by creating-agents.md or creating-processes.md.

1. Read `reference/claude-code-capabilities.md` for format rules
2. Determine purpose, consumers, degrees of freedom
3. Check existing skills within the process/agent for overlap
4. Check global `library/` for existing skills that match
5. Generate SKILL.md with proper frontmatter, progressive disclosure
6. Scaffold optional directories as needed (scripts/, references/, assets/, evals/)
7. Write to the owning process or agent's `skills/` directory with feedback/ and changelog.md
8. If skill duplicates one already in another process/agent, consider graduating to `library/`

### applying-feedback.md (Internal)

Reviews and applies accumulated feedback from backlogs across all PAS artifacts.

1. Survey backlogs recursively within `processes/` (process, sub-process, agent, and skill backlogs) and `library/`
2. Present accumulation summary, prioritized by volume and severity
3. If targeted: focus on one artifact. If not: recommend where to start.
4. Read target artifact + its backlog
5. Evaluate definitiveness — is the feedback clear enough to act on?
6. Apply Occam's razor — fewest assumptions
7. If ambiguous: ask user for crystal clarity
8. Present upgraded artifact + changelog for approval
9. Update artifact's `changelog.md`

## Hooks (Resolved in Session 6)

Configured in `.claude/settings.json`. When `feedback: disabled` in pas-config.yaml, the entire feedback pipeline is off — no self-eval skill loaded, no signals written, no hooks fire. Complete silence. User can still manually request feedback via `/pas` conversation (user-initiated, not automatic).

| Hook | Event | Type | Purpose |
|---|---|---|---|
| Self-eval safety net | `SubagentStop` | command | Checks if agent wrote self-eval file. If missing, logs warning. |
| Feedback routing | `Stop` | command | Routes workspace feedback signals to artifact backlogs. |

**Self-eval safety net (SubagentStop):** Shell script. Checks if the agent wrote a self-eval file to `workspace/{slug}/feedback/`. If missing, logs a warning note. If present, exits cleanly (no-op). Lightweight, no LLM calls. The primary self-eval mechanism is the shutdown sequence (step 3), not this hook.

**Session feedback is not a hook.** The orchestrator writes `session.md` to `workspace/{slug}/feedback/` as part of shutdown step 5. Always writes, even if brief when context-constrained. Subject to the saturation rule: if nothing went wrong, minimal note only.

**Feedback routing (Stop):** Shell script. Guard: checks if feedback files exist in `workspace/{slug}/feedback/`. If none, exits 0 — no config parsing needed (if feedback is disabled, no files were written). For each feedback file: parses structured signals and their `Target:` fields, appends each signal to the target artifact's `feedback/backlog/`, cleans up the workspace feedback inbox after successful routing. The `Target:` field makes routing deterministic — just file operations, no intelligence needed.

## Skill Granularity (Resolved in Session 6)

No universal rule. Three heuristics guide granularity decisions. Default to one skill (simpler). Split when any heuristic triggers.

1. **Feedback heuristic:** Can you improve one part without touching the other? If yes, separate skills.
2. **Reuse heuristic:** Could another agent/process use one part but not the other? If yes, separate skills.
3. **Size trigger:** If a skill exceeds 5000 tokens, automatically flag for evaluation — split, restructure, or explicitly justify the size.

## Changelog Format (Resolved in Session 6)

Git-derived with feedback context. Git commits track what changed. The changelog captures what git can't: the *why* from feedback. The feedback applicator writes changelog entries automatically as part of its apply workflow.

```markdown
## 2026-03-06 — Scoped research plans to story complexity
Triggered by: OQI-01 (2026-03-06-sec-ruling), OQI-03 (2026-03-04-eth-merge)
Pattern: Research plans consistently too ambitious for single-angle stories
Change: Added scoping heuristic matching source count to story type
```

## Testing Strategy (Resolved in Session 6)

Testing is built into PAS's creation workflows. Each creation skill owns its testing. No external plugin dependencies. The feedback system improves tests over time.

| Level | What's tested | Method | Created by |
|---|---|---|---|
| **Skill** | Individual skill output quality | Eval framework (`evals/evals.json` with assertions) | `creating-skills.md` |
| **Agent** | Agent behavior with its skills | Eval scenario (representative task, check output) | `creating-agents.md` |
| **Process** | End-to-end pipeline output | Integration test (run process, grade output) | `creating-processes.md` |
| **Feedback system** | Signals collected, routed, applied correctly | TDD cycle (RED/GREEN/REFACTOR) | Manual during Phase 4 |

Each creation skill includes a testing step: when PAS creates an artifact, it also creates a basic eval or test scenario. TDD for discipline-enforcing skills, eval framework for output-quality skills. Both approaches are complementary.

## Bootstrap Strategy

PAS is itself a process, but it can't create itself before it exists.

1. **Bootstrap phase** (Phases 1-3): Hand-build PAS as skills in `.claude/skills/pas/`
2. **Self-hosting phase**: Once PAS can create processes, use PAS to recreate itself as `processes/pas/`
3. **Retire bootstrap**: Replace hand-written version with the self-hosted one

## Repo Split (Immediate)

Move old system to `legacy/` immediately. Build PAS at root alongside it.

```
.claude/skills/          # Platform requirement, PAS launchers
  pas/                   # PAS framework (single entry point + internal routing)
  article/               # Points to processes/article/ when ready

processes/               # NEW, self-contained process packages (agents + skills inside)
library/                 # NEW, global skills only (graduated after 2+ reuses)
reference/               # Global reference docs (stays)
pas-config.yaml          # User preferences

legacy/                  # OLD, frozen system, moved here
  .claude/skills/        # Old skill definitions
  .claude/agents/        # Old agent definitions
  prompts/
  config/
  workspace/
  existing_prompts/
  experiments/
  tools/
  feedback/
```

Old system remains accessible in `legacy/` if needed during transition.

## Build Order (Revised in Session 3)

Internal build order follows process-first design: process → agent → skill.

### Phase 0: Foundation
- [x] `reference/claude-code-capabilities.md` (done, updated with Agent Skills spec)
- [x] This design doc (v4)
- [x] MAPS future design doc
- [x] Gap assessment document
- [ ] Repo split: move old system to `legacy/`

### Phase 1: Process Creation (`creating-processes.md`)
- Build the process-creation internal skill (bootstrap)
- This is the core — it also triggers agent and skill creation
- Read `library/orchestration/` for patterns
- Test by scaffolding `processes/article/`

### Phase 2: Agent Creation (`creating-agents.md`)
- Build the agent-creation internal skill (bootstrap)
- Called by creating-processes.md or directly by router
- Test by creating one agent with the new directory format

### Phase 3: Skill Creation (`creating-skills.md`)
- Build the skill-creation internal skill (bootstrap)
- Called by creating-agents.md or creating-processes.md
- Test by creating a library skill

### Phase 4: Feedback System (`applying-feedback.md`)
- Build the feedback internal skill (bootstrap)
- Build `library/self-evaluation/` skill (always-on global skill)
- Build `library/message-routing/` skill for in-session feedback classification
- Configure hooks in `.claude/settings.json`
- Test against existing feedback data (in `legacy/feedback/`)

### Phase 5: `/pas` Entry Point (SKILL.md)
- Build the intelligent router
- Brainstorming-style conversation flow
- Crystal clarity principle
- First-run detection (no pas-config.yaml → create with defaults)
- Frustration detection for feedback reactivation

### Phase 6: Rebuild Article Pipeline
- Use PAS to create `processes/article/` with full process.md
- Agents and skills created as part of process creation flow
- Create thin launcher `.claude/skills/article/SKILL.md`
- Verify article pipeline works end-to-end

### Phase 7: Self-Hosting
- Use PAS to recreate itself as `processes/pas/`
- Replace bootstrap with self-hosted version

### Phase 8: Activate Feedback Loop
- Configure all hooks
- Run a real article session
- Verify: agents write to workspace inbox -> hook routes to backlogs -> user feedback at gates classified and routed -> feedback application works
- Production use begins generating improvement data

Each phase is a git commit point. Old system accessible in `legacy/` throughout.

## Unresolved Gaps

See `2026-03-06-pas-gap-assessment.md` for detailed gap analysis with options and trade-offs.

### Build-Blocking (Tier 1)

All Tier 1 gaps are resolved. Phase 1 (process creation) can begin.

### Build-Important (Tier 2)

All Tier 2 gaps are resolved. Phase 4 (feedback system) can begin.

### Philosophical (Tier 3)

All Tier 3 gaps are resolved. All gaps across all tiers are now resolved.

| Gap | Resolution |
|---|---|
| Skill granularity | Three heuristics: feedback (can you improve parts independently?), reuse (could another agent use one part?), size trigger (>5000 tokens flags automatic evaluation). Default to one skill, split when heuristics trigger. |
| Changelog format | Git-derived with feedback context. Dated entries linking changes to the feedback signals that triggered them. Written by the feedback applicator. Not Keep a Changelog (too rigid) or pure free-form (too inconsistent). |
| Orchestration vs creating-agent-teams | PAS fully absorbs creating-agent-teams. Team composition → creating-processes.md. Model tier selection → creating-agents.md. Orchestration patterns → library/orchestration/. The superpowers skill becomes redundant after PAS is built. |
| Cross-process agent feedback | Dissolved by design. Agents are always process-local. No global agents, no shared agents. Each process owns its agents fully. New processes copy and tailor agents, never reference shared ones. Library is for skills only. |
| Testing strategy | Built into creation workflows. Four levels: skill evals (evals.json), agent eval scenarios, process integration tests, feedback system TDD. Each creation skill creates tests for its artifacts. No external plugin dependencies. |

### Resolved in Session 6

| Gap | Resolution |
|---|---|
| Self-evaluation skill content | Four signal types: PPU (persistent preferences), OQI (output quality issues), GATE (blocked changes), STA (stability anchors). Structured format with target fields pointing to PAS artifacts. Agents detect and report; the applicator evaluates and applies. Written at shutdown. Applicator works one artifact at a time, asks user preference (apply all/all once/just this/review), remembers preference if requested. 5-report suggestion trigger, not a gate. Saturation prevention: smooth sessions produce minimal feedback. Recursive boundary: feedback system never auto-generates feedback about itself; user-initiated meta-feedback only. |
| Hook implementation | Two command hooks remain. Self-eval safety net (SubagentStop): checks if agent wrote eval, logs warning if missing. Feedback routing (Stop): shell script parses Target fields, routes signals to artifact backlogs. Session feedback is not a hook — orchestrator writes session.md at shutdown step 5. When feedback disabled, entire pipeline is off. |
| Legacy coexistence | Move immediately at Phase 0. No gradual migration, no parallel running. Single commit moves old files to `legacy/`. Old `/article` stops working. PAS builds at root. `legacy/` stays as read-only reference, deleted when PAS article pipeline is stable. |
| Feedback routing intelligence | Classification problem dissolved. Agents write Target fields; routing is mechanical (shell script). Intelligence lives in the applicator: sanity checks (target validation, signal quality, duplicate detection, conflict check with STAs) before applying any change. Mis-targeted signals re-routed by applicator. |

### Resolved in Session 5

| Gap | Resolution |
|---|---|
| Status tracking | Performance log per instance. Minimal states (pending/in_progress/completed), rich metadata (timestamps, duration, attempts, quality score+notes). Workspace separated from process definitions at `workspace/{process}/{slug}/`. Sub-process rollup via `subprocess:` references. |
| Error handling | Four-step chain: agent self-recovers → orchestrator monitors for hangs → orchestrator retries once (fresh spawn) → escalate to user. Partial output quarantined to `partial/`. Token budget exceeded = skill needs splitting. Non-responsive agent = critical incident. Global default policy, per-process override. |
| Phase dependencies | Orchestrator infers parallelism from I/O dependencies. No `depends_on` fields. Optional `sequential: true` to force linear execution. |
| Agent lifecycle | Two-tier spawn model: team members (TeamCreate, persistent) for process agents, subagents (Agent tool, ephemeral) for task helpers. Agents stay alive until process ends to receive downstream feedback and write rich self-evaluations. Zero idle cost. ~7-10k token overhead per spawn. |

### Resolved in Session 4

| Gap | Resolution |
|---|---|
| Agentless phase execution | Eliminated. Every process has an orchestrator agent. No `agent: none`. The orchestrator handles phases directly using its own skills or delegates to specialist agents. |
| Editor role | Resolved as orchestrator agent. Every process gets an orchestrator responsible for its success. Role adapts to orchestration pattern (orchestrator, moderator, operator). |
| Skills locality | Skills live inside their process or agent by default. Global library is only for skills with proven reuse across 2+ processes/agents. |
| Recursive processes | Processes can contain sub-processes, agents, and skills. Agents can contain processes and skills. Maximum feedback granularity at every level. |
| Resumability | Workspace status updated continuously. Orchestrator reads status on session start to resume from last completed point. |
| Lean process philosophy | PAS creates minimum viable agents. Start simple, grow through feedback and usage. Quick wins first. |

### Resolved in Session 3

| Gap | Resolution |
|---|---|
| Agent Skills spec alignment | PAS IS an Agent Skill with internal granularity. Library skills follow spec format. |
| When NOT to use PAS | Dissolved — everything is a process, PAS makes creation effortless. |
| `/pas` router intelligence | Brainstorming-style conversation. Ask until crystal clear. |
| First-run onboarding | Same flow as any run — "what are you trying to achieve?" |
| PAS skills portability | Default project-level, progressive promotion to user-level, marketplace extraction for power users. |
| Multi-scope architecture | Project-level default, user-level for reusable artifacts, no upfront scope decisions. |
| Feedback preferences | Always-on by default, conversational opt-out stored in pas-config.yaml, frustration-triggered reactivation. |

## Open Questions (For Experimentation)

- **Orchestration knowledge distribution**: How does the session inform agents about their orchestration context? Start with simplest default (pass in spawn prompt), observe, optimize.
- **Shared config across processes**: If multiple processes serve the same publication, how do they share config? Deferred until it's needed.
- **Migration to separate repo**: When PAS skills stabilize, extract to own repo/plugin. Deferred.
- **Songwriting process**: Timeline for rebuilding as a PAS process. After article pipeline works.
- **Process definition format details**: YAML schema may need refinement as real processes are built.
- **Cross-project discovery UX**: How PAS scans other projects for reusable artifacts. Deferred until user has multiple PAS projects.
- **Skill-creator as reference**: Anthropic's skill-creator plugin has useful eval/iterate patterns. PAS builds its own testing into creation workflows (Session 6), but skill-creator can be referenced for methodology inspiration. Not a dependency.
- **Global reporting skill**: `library/reporting/` to aggregate performance data across instances (agent speed trends, quality averages, phase duration comparisons). Design when enough performance data exists.
