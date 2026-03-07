# PAS Development Process Design

**Date:** 2026-03-07
**Goal:** Create a dedicated process for evolving the PAS framework toward becoming the de-facto best way to build agentic workflows in Claude Code.
**Approach:** Use PAS itself to build the team and process that develops PAS.

## Process Definition

| Field | Value |
|-------|-------|
| Name | `pas-development` |
| Goal | Evolve PAS into the best way to build agentic workflows in Claude Code |
| Orchestration | Hub-and-spoke (with discussion pattern in Phase 1) |
| Sequential | true |
| Modes | Supervised (human approves at every gate) |

## Agents

### Orchestrator
- **Role:** Process coordinator and human interface. Runs phases, dispatches agents, presents decisions. Never does domain work itself.
- **Model:** Opus
- **Tools:** Agent, SendMessage, TeamCreate, Read, Glob, Grep
- **Skills:** orchestration, message-routing, self-evaluation

### Feedback Analyst
- **Role:** Processes accumulated feedback signals (PPU/OQI/GATE/STA) across all PAS artifacts. Identifies patterns, recurring issues, and priority clusters. In Discovery, presents data-driven insights. In Execution, marks addressed signals and updates changelogs.
- **Model:** Sonnet
- **Tools:** Read, Glob, Grep, Write, Edit
- **Skills:** feedback-analysis, self-evaluation

### Community Manager
- **Role:** External interface to the GitHub community. Reads incoming issues, triages them, engages with contributors, opens PRs for completed work, and links issue discussions back into Discovery.
- **Model:** Sonnet
- **Tools:** Read, Glob, Grep, Bash (gh CLI)
- **Skills:** issue-triage, gh-engagement, pr-management, self-evaluation

### Framework Architect
- **Role:** Core design authority. Evaluates architecture, proposes structural changes, designs new capabilities. In Discovery, provides technical perspective. In Planning, produces implementation plans. In Execution, implements architectural changes.
- **Model:** Opus
- **Tools:** Read, Write, Edit, Glob, Grep, Bash
- **Skills:** framework-assessment, implementation-planning, self-evaluation

### DX Specialist
- **Role:** Developer experience advocate. Thinks like a first-time user. Evaluates onboarding friction, documentation clarity, naming, ergonomics. In Discovery, flags usability gaps. In Execution, writes docs, tutorials, and improves skill readability.
- **Model:** Sonnet
- **Tools:** Read, Write, Edit, Glob, Grep
- **Skills:** dx-audit, self-evaluation

### Ecosystem Analyst
- **Role:** Tracks Claude Code's evolving capabilities, competitive landscape, and ecosystem opportunities. In Discovery, brings external context.
- **Model:** Sonnet
- **Tools:** Read, Glob, Grep, WebSearch, WebFetch
- **Skills:** ecosystem-scan, self-evaluation

### QA Engineer
- **Role:** Quality gate. Reviews all changes for consistency, regressions, convention violations, and completeness against the plan.
- **Model:** Opus
- **Tools:** Read, Glob, Grep, Bash
- **Skills:** change-validation, self-evaluation

## Phases

### Phase 1: Discovery (Discussion Pattern)

**Agents:** Feedback Analyst, Community Manager, Framework Architect, DX Specialist, Ecosystem Analyst
**Moderator:** Orchestrator

**Two entry modes:**
- **Feedback-driven:** No directive from the product owner. Feedback Analyst opens with internal signal analysis, Community Manager presents GitHub issue triage. Others respond with their perspectives. Team converges on priorities.
- **Owner-directed:** Product owner comes in with "I want X." Directive enters the discussion. Team pressure-tests it, enriches it, flags risks, adds context from their domains.

**Turn order:** Feedback Analyst and Community Manager first (ground the discussion in data), then Framework Architect, DX Specialist, Ecosystem Analyst. Multiple rounds allowed.

**Output:** Prioritized list of issues/opportunities with team analysis.
**Gate:** Product owner approves, modifies, or cuts priorities.

### Phase 2: Planning (Solo)

**Agent:** Framework Architect

Takes approved priorities and produces a scoped implementation plan:
- What changes to which files
- What new artifacts to create (if any)
- Dependencies between changes
- What can be parallelized in Execution

**Output:** Implementation plan with file-level specificity.
**Gate:** Product owner approves the plan or sends it back for revision.

### Phase 3: Execution (Hub-and-Spoke)

**Agents:** Framework Architect, DX Specialist, Feedback Analyst, Community Manager
**Coordinator:** Orchestrator

Orchestrator dispatches work items from the plan to the right agents in parallel where possible:
- Framework Architect: architectural changes (process definitions, orchestration patterns, core skills)
- DX Specialist: documentation, tutorials, skill readability improvements
- Feedback Analyst: marks addressed signals, updates changelogs
- Community Manager: opens PRs, links issues to changes

**Output:** Implemented changes.
**Gate:** Product owner reviews changes before validation.

### Phase 4: Validation (Solo)

**Agent:** QA Engineer

Reviews all changes against:
- The approved plan (completeness)
- PAS conventions (feedback/backlog dirs, changelogs, SKILL.md format)
- Consistency (no contradictions between artifacts)
- Regressions (existing processes still work)

If issues found, routes back to Execution for fixes. If clean, reports to Orchestrator.

**Output:** Validation report (pass/fail with specific issues).
**Gate:** Product owner approves the release (version bump, changelog update, commit).

## Skills

### Existing (from library)
- `self-evaluation` — All agents, shutdown feedback
- `message-routing` — Orchestrator, gate classification
- `orchestration` — Orchestrator, pattern execution

### New Skills to Create

| Skill | Agent | Purpose |
|-------|-------|---------|
| `feedback-analysis` | Feedback Analyst | Scan feedback/backlog/ directories, classify and cluster signals, identify patterns, produce prioritized report |
| `framework-assessment` | Framework Architect | Audit PAS artifacts against conventions, identify architectural gaps, compare capabilities to goals |
| `implementation-planning` | Framework Architect | Produce scoped, parallelizable implementation plan with file-level specificity from approved priorities |
| `dx-audit` | DX Specialist | Evaluate PAS from a new user's perspective — onboarding, naming, docs, readability |
| `ecosystem-scan` | Ecosystem Analyst | Research Claude Code capabilities, competing frameworks, ecosystem trends. Produce opportunity report |
| `change-validation` | QA Engineer | Review changes against plan, conventions, consistency, regressions. Produce pass/fail report |
| `issue-triage` | Community Manager | Read open GitHub issues, classify (bug/feature/question/framework feedback), assess priority, produce triage report |
| `gh-engagement` | Community Manager | Comment on issues for clarification, acknowledge reports, link to docs. Helpful and concise tone |
| `pr-management` | Community Manager | Open PRs for completed work with descriptions linking to issues and implementation plan |

## Human Role

**Product Owner** (Zoran) gates every phase transition. Can inject directives at Discovery or let the team drive from accumulated data. The Orchestrator is the sole interface — individual agents do not present to the product owner directly.
