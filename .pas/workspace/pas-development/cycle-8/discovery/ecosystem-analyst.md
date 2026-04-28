# Ecosystem Assessment — Cycle 8 (12-Month Roadmap)

## Current Claude Code Platform State (March 2026)

### Core Extension Architecture
Claude Code provides 7 extension types: CLAUDE.md (persistent context), Skills (reusable workflows), MCP (external services), Subagents (isolated workers), Agent Teams (multi-session coordination), Hooks (deterministic scripts), and Plugins (packaging/distribution). PAS currently leverages all 7.

### Recent Platform Additions (Since Cycle 7)
- **HTTP hooks**: POST JSON to a URL instead of running a shell command. Opens hook-based enforcement to remote services.
- **/loop command + cron scheduling**: Recurring prompts within a session. Enables automated periodic tasks (monitoring, sync checks).
- **Tool Search for MCP**: Lazy-loads MCP tool definitions, cutting context usage by ~85%. Critical for plugins that bundle MCP servers.
- **Worktree enhancements**: `worktree` field in status line hooks (name, path, branch, original repo). Project configs and auto memory shared across worktrees.
- **Agent teams improvements**: Still experimental, but actively iterated. Known limitations: no session resumption, no nested teams, high token cost.
- **Opus 4.6 default**: Medium effort for Max/Team subscribers. Model capability continues advancing.
- **Claude 5 expected Q2-Q3 2026**: Planned "Dev Team" multi-agent collaboration mode — could significantly impact PAS's agent team orchestration.

### Plugin Ecosystem Scale
- **9,000+ plugins** in the ecosystem as of February 2026
- **43 marketplaces** registered
- **Official Anthropic marketplace** (claude-plugins-official) is the curated tier
- Plugin adoption metrics are now tracked across GitHub repos (quemsah/awesome-claude-plugins)

## Competitive Landscape

### Tier 1: Direct Competitors (Agentic Workflow Frameworks)

#### Superpowers (obra/superpowers) — 42,000+ GitHub stars
The most adopted agentic plugin. Teaches Claude structured software development methodology:
- Socratic brainstorming before coding
- Test-driven development (red-green-refactor)
- Four-phase debugging methodology
- Subagent-driven development with code review
- Ability to author new skills

**What they do well:** Developer experience is exceptional. The brainstorming-first approach prevents premature implementation. Strong TDD integration. Accepted into the official Anthropic marketplace.

**What PAS does better:** PAS has structured multi-agent processes with defined phases, gates, and orchestration patterns. Superpowers is a methodology plugin — it teaches Claude how to work. PAS is a framework — it defines reusable, composable workflows that coordinate multiple agents. Superpowers has no equivalent to PAS's process.md, no feedback system, no self-evaluation, no lifecycle hooks.

**Key difference:** Superpowers optimizes a single agent's behavior. PAS orchestrates teams of agents through structured processes. These are complementary, not competitive.

#### everything-claude-code (affaan-m/everything-claude-code) — ~50,000 GitHub stars
Comprehensive configuration plugin with 13 agents, 40+ skills, 32 shortcut commands:
- Hierarchical agent delegation (Orchestrator agents dispatch specialized agents)
- Stop Hook that extracts coding patterns and stores them for cross-session learning
- `/evolve` command aggregates learned patterns into reusable skills
- Covers backend, frontend, language-specific, DevOps, and advanced features

**What they do well:** Massive breadth. Learning system that accumulates experience across sessions is genuinely novel. Strong adoption.

**What PAS does better:** PAS has formal process definitions with phases, gates, and validation. everything-claude-code's "orchestration" is implicit agent routing — there's no process.md, no phase gates, no structured feedback system. PAS's feedback loop is structured (signal types, routing, application) vs. their pattern extraction from Stop hooks. PAS processes are reusable and distributable; their agents are hardcoded to development workflows.

**Key difference:** everything-claude-code is a batteries-included development environment. PAS is a meta-framework for building any workflow.

#### Ruflo (ruvnet/ruflo) — Agent Orchestration Platform
Enterprise-oriented with 60+ specialized agents, "Hive Mind" coordination, 87 MCP tools:
- Queen-led hierarchical coordination with worker specializations
- Distributed swarm intelligence with consensus mechanisms
- RAG integration and shared memory
- MCP-native architecture (tools exposed via mcp__claude-flow__ namespace)

**What they do well:** Scale ambition is high. MCP-native architecture is forward-looking. Security model for multi-agent systems.

**What PAS does better:** PAS is radically simpler. A PAS process is a markdown file, not an enterprise platform. PAS's feedback system actually works and improves over cycles. Ruflo's complexity may be its weakness — it's solving problems most users don't have yet.

**Key difference:** Ruflo targets enterprise multi-agent orchestration. PAS targets composable workflow definition for any user. Different market segments.

### Tier 2: Adjacent Tools

#### claude-orchestration (mbruhler/claude-orchestration)
Multi-agent workflow orchestration plugin. Less mature than PAS but validates that process orchestration is a real need in the ecosystem.

#### Claude-Code-Workflow (catlog22/Claude-Code-Workflow)
JSON-driven multi-agent cadence-team development framework. Validates JSON/YAML process definition as a pattern.

#### Deep Trilogy (/deep-project, /deep-plan, /deep-implement)
Structured decomposition from ideas to code. Similar to PAS's Discovery-Planning-Execution flow but as separate skills, not a unified process.

### Tier 3: Platform-Level Competition
- **OpenCode**: Open-source CLI competitor to Claude Code. Growing but significantly behind in ecosystem maturity.
- **Cursor/Windsurf**: IDE-integrated agents. Different UX paradigm (visual vs. terminal) but solving similar orchestration needs.
- **Claude Cowork**: Anthropic's own desktop agentic tool. Currently macOS-only, focused on knowledge work beyond coding. Could eventually absorb some plugin functionality.

## Ecosystem Trends

### 1. Process-as-Markdown is Winning
The ecosystem has converged on markdown + YAML frontmatter as the standard for defining agent behavior, skills, and workflows. PAS was early to this pattern and remains the most structured implementation. Multiple community projects (claude-code-workflows, claude-orchestration, Claude-Code-Workflow) validate that users want formal process definitions, not just ad-hoc skills.

**Implication for PAS:** This is PAS's core strength. The roadmap should double down on making process definition more powerful, not pivot away from it.

### 2. Cross-Session Learning is Emerging
everything-claude-code's Stop Hook pattern extraction and `/evolve` command represent a trend: agents that learn from their own work across sessions. PAS's feedback system is more structured but less automated — signals are written manually during self-evaluation rather than extracted automatically.

**Implication for PAS:** PAS's feedback system is architecturally superior (typed signals, routing, application) but operationally heavier. The roadmap should explore automated signal detection to complement manual self-evaluation.

### 3. Hook-Driven Enforcement Over Instruction-Driven Guidance
The community is shifting from "tell the model what to do in CLAUDE.md" to "prevent the model from doing what it shouldn't via hooks." PAS has hooks (5 registrations across 4 lifecycle events) but still relies heavily on CLAUDE.md for behavioral constraints.

**Implication for PAS:** The deferred cycle-7 backlog items (PreToolUse guard for plugins/pas/, PostToolUse library sync) are aligned with this trend and should be prioritized.

### 4. MCP as the Integration Layer
MCP Tool Search (lazy loading, 85% context reduction) makes it practical to bundle MCP servers in plugins without context cost. The ecosystem is moving toward MCP as the standard for external service integration.

**Implication for PAS:** PAS currently has zero MCP integration. As processes grow beyond code-only workflows (e.g., deploying, monitoring, communicating), MCP becomes the natural extension point. The roadmap should include MCP server support in process definitions.

### 5. Agent Teams Maturing (But Not There Yet)
Agent teams are still experimental with real limitations (no session resumption, no nested teams, high token cost). PAS already uses teams for its own development process. Claude 5's planned "Dev Team" mode may change the coordination model significantly.

**Implication for PAS:** PAS should build abstractions that work with both the current team API and potential future changes. The orchestration patterns should be the stable layer, not the underlying team mechanics.

### 6. Observability is the Next Frontier
The broader agentic AI industry is converging on trace-level observability (every reasoning step, tool call, decision captured). PAS's self-evaluation system is a primitive form of this, but there's no runtime observability during process execution.

**Implication for PAS:** A process execution dashboard or trace viewer would differentiate PAS from every competitor. The visualize-process skill (cycle-6) laid groundwork — the next step is runtime visualization.

## Gaps: What PAS Does Not Do That the Ecosystem Needs

### Gap 1: Process Templates / Starter Library
PAS can create processes from scratch, but there's no library of ready-to-use process templates. Users must understand the full PAS model before they get value. Superpowers gets adoption because you install it and it works immediately. PAS requires learning a framework.

### Gap 2: Process Composition
No way to compose processes — calling one process from another, or having a process phase delegate to a sub-process. Real workflows are hierarchical.

### Gap 3: Runtime Observability
No visibility into process execution while it's happening. The visualize-process skill shows the static structure; nothing shows the dynamic state (which phase, which agents, what's blocked, token usage).

### Gap 4: Cross-Process Learning
Feedback is process-local. There's no mechanism for patterns learned in one process to benefit another process. The `/evolve` pattern from everything-claude-code points to this need.

### Gap 5: MCP Integration in Processes
Process definitions can't declare MCP server dependencies. As workflows extend beyond code (database queries, API calls, browser automation), this becomes a real limitation.

### Gap 6: Onboarding Path
No guided first experience. New users face: install plugin, learn PAS concepts (processes, agents, skills, modes, orchestration patterns, feedback), create something useful. The activation energy is too high.

## What PAS Should Look Like in March 2027

### The Vision
PAS should be the standard way to define, run, observe, and improve multi-agent workflows in Claude Code. Not just the best framework — the category-defining one.

### Concrete Position
1. **Process marketplace**: A curated library of ready-to-use PAS processes (code review, deployment, content creation, data analysis) that users install and run immediately. The framework becomes valuable on day one.
2. **Runtime dashboard**: HTML-based real-time view of process execution — phase progress, agent status, token usage, decision log. The visualize-process skill evolves from static overview to live execution viewer.
3. **Feedback network**: Cross-process learning where patterns validated in one process automatically inform others. PAS becomes the only framework that genuinely gets better with use.
4. **Composable processes**: Processes that call other processes. A "release" process that invokes "test", "review", and "deploy" sub-processes. Real workflow hierarchies.
5. **MCP-aware processes**: Process definitions that declare MCP dependencies and configure them at process startup. PAS manages the full execution environment.
6. **Hook enforcement layer**: Complete hook-based guard system for process integrity — preventing out-of-process edits, enforcing phase gates, auto-syncing mirrors.
7. **5-minute onboarding**: Install PAS, run a template process, see it work, understand the model. Then customize.

## Opportunities — Ranked by 12-Month Impact

### O1: Process Template Library (HIGH — Q2 2026)
Create 3-5 ready-to-use process templates that ship with the plugin. Code review, PR workflow, content creation, project setup. Reduces activation energy from hours to minutes. This is the single highest-impact thing PAS can do for adoption.

### O2: Runtime Process Dashboard (HIGH — Q3 2026)
Extend visualize-process into a runtime execution viewer. Show phase progress, agent status, feedback signals, and decision log. Uses the existing HTML generation pattern. Differentiates PAS from every competitor.

### O3: Hook Enforcement Layer (MEDIUM-HIGH — Q2 2026)
Implement the deferred cycle-7 items: PreToolUse guard for plugin edits, PostToolUse library sync, and generalize these into a "process guard" pattern that any process can use to protect its artifacts.

### O4: Process Composition (MEDIUM — Q3-Q4 2026)
Allow processes to invoke sub-processes. Define a `subprocess:` field in phase definitions that delegates to another process. Enables real workflow hierarchies.

### O5: Cross-Process Feedback Network (MEDIUM — Q4 2026)
Create a feedback aggregation layer that identifies patterns across processes. When the same signal type (e.g., "agent forgot to check X") appears in multiple process instances, promote it to a library-level fix.

### O6: MCP-Aware Process Definitions (MEDIUM — Q1 2027)
Add `mcp_servers:` field to process.md. At process startup, verify required MCP servers are connected and configure them. At process shutdown, clean up.

### O7: Guided Onboarding Experience (MEDIUM — Q1 2027)
Interactive first-run that walks users through creating and running their first process. `/pas` detects first-time users and offers a guided path instead of the current brainstorming mode.

## Risks

### R1: Claude 5 "Dev Team" Mode Could Subsume Agent Teams
If Claude 5 ships native multi-agent coordination, PAS's orchestration patterns may need significant rework. **Mitigation:** Keep orchestration patterns as the abstraction layer. If the underlying mechanism changes, only the pattern implementations need updating, not user-facing process definitions.

### R2: Agent Teams API Instability
PAS's development process depends on experimental agent teams. API changes could break the process. **Mitigation:** PAS processes should degrade gracefully to sequential subagent execution if teams are unavailable.

### R3: Plugin Ecosystem Saturation
9,000+ plugins mean discovery is harder. PAS could get lost in the noise despite being architecturally unique. **Mitigation:** Process templates (O1) provide immediate value that differentiates PAS from skills-only plugins. Marketplace presence in the official Anthropic marketplace would help significantly.

### R4: Superpowers + everything-claude-code Adoption Moat
Combined ~90,000 GitHub stars vs. PAS's current scale. Network effects favor incumbents. **Mitigation:** PAS is not competing for the same niche. Superpowers optimizes single-agent behavior; PAS orchestrates multi-agent processes. The strategy should be complementary positioning, not head-to-head competition. A PAS process template could even recommend Superpowers as a skill.

### R5: Hook JSON Schema Instability
PAS hooks depend on specific input fields that are not formally versioned. A Claude Code update could break hook behavior silently. **Mitigation:** Version-pin hook dependencies and add integration tests that verify hook contracts on each Claude Code update.

## Sources

- [Claude Code Features Overview](https://code.claude.com/docs/en/features-overview)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Claude Code Plugins](https://code.claude.com/docs/en/plugins)
- [Claude Code Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Claude Code Changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- [Superpowers Plugin](https://github.com/obra/superpowers) — 42,000+ stars, official marketplace
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — ~50,000 stars, 13 agents, 40+ skills
- [Ruflo Agent Orchestration](https://github.com/ruvnet/ruflo) — enterprise multi-agent platform
- [Claude Code Release Notes March 2026](https://releasebot.io/updates/anthropic/claude-code)
- [Awesome Claude Code](https://github.com/hesreallyhim/awesome-claude-code)
- [Awesome Claude Plugins Adoption Metrics](https://github.com/quemsah/awesome-claude-plugins)
- [Agentic Workflow Architectures 2026](https://www.stackai.com/blog/the-2026-guide-to-agentic-workflow-architectures)
- [AI Agent Observability 2026](https://www.n-ix.com/ai-agent-observability/)
