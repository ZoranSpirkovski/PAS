# Ecosystem Scan — Cycle 9

**Date**: 2026-03-08
**Agent**: ecosystem-analyst

---

## New Claude Code Capabilities

### Agent Teams (Experimental, shipped with Opus 4.6 — Feb 2026)

Native multi-agent orchestration built into Claude Code. One session acts as team lead, spawning teammates that work independently in their own context windows and communicate directly with each other via shared task list + mailbox system.

Key details:
- **Experimental**, disabled by default (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)
- Teammates share a task list with pending/in-progress/completed states and dependency tracking
- Direct inter-agent messaging (not just report-back like subagents)
- Display modes: in-process (default) or split-pane (tmux/iTerm2)
- Quality gates via hooks: `TeammateIdle` and `TaskCompleted` events
- Limitations: no session resumption, no nested teams, one team per session, lead is fixed
- Tools: TeamCreate, SendMessage, TaskCreate, TaskGet, TaskList, TaskUpdate

**PAS relevance**: HIGH. Agent Teams is the platform feature closest to what PAS builds. PAS already does formal multi-agent orchestration with defined phases, feedback loops, and process definitions. Agent Teams provides the runtime primitives PAS relies on. As Teams matures out of experimental, PAS should align its orchestration patterns with the native API rather than fighting it.

Source: [Agent Teams docs](https://code.claude.com/docs/en/agent-teams)

### Enhanced Subagent System

Subagents now support:
- **Persistent memory** (`memory: user|project|local`) — cross-session learning with auto-managed MEMORY.md
- **Isolation via worktrees** (`isolation: worktree`) — run in temporary git worktree
- **Background execution** (`background: true`) — concurrent non-blocking subagents
- **Scoped hooks** — PreToolUse/PostToolUse/Stop hooks defined per-subagent in frontmatter
- **Skill preloading** (`skills:` field) — inject skill content into subagent context at startup
- **Tool restriction granularity** — `Agent(worker, researcher)` syntax to control which subagent types can be spawned
- **Model routing** — `model: sonnet|opus|haiku|inherit` per subagent
- **Permission modes** — `default|acceptEdits|dontAsk|bypassPermissions|plan` per subagent

**PAS relevance**: HIGH. These map directly to PAS agent definitions. PAS agents already define tools, skills, and behavioral constraints. Subagent persistent memory is especially relevant — PAS could leverage this for agent-level learning across cycles without custom implementations.

Source: [Subagents docs](https://code.claude.com/docs/en/sub-agents)

### Plugin System (Mature, v1.0.33+)

Plugins can now bundle: skills, agents, hooks, MCP servers, LSP servers, and default settings. Key features:
- **Plugin manifest** (`.claude-plugin/plugin.json`) with semantic versioning
- **Marketplace system**: official Anthropic marketplace (auto-available), plus custom/team/enterprise marketplaces
- **Plugin namespacing**: `/plugin-name:skill-name` prevents conflicts
- **LSP integration**: language server plugins for code intelligence (11 official language plugins)
- **Settings override**: `settings.json` can set a default agent for a plugin
- **Enterprise marketplace**: announced Feb 2026, with org-managed plugin distribution
- **Auto-updates**: marketplace auto-update with configurable behavior
- **9,000+ extensions** across official + community marketplaces

**PAS relevance**: HIGH. PAS is already a plugin. The maturing marketplace and enterprise features create a distribution channel. LSP integration and settings override (especially `"agent"` key to set main thread agent) open new possibilities.

Source: [Plugins docs](https://code.claude.com/docs/en/plugins), [Discover plugins](https://code.claude.com/docs/en/discover-plugins)

### Hooks System (12 Lifecycle Events)

Three handler types:
1. **Command hooks**: shell scripts receiving JSON via stdin
2. **Prompt hooks**: single-turn LLM evaluation
3. **Agent hooks**: spawn subagents with tool access for deep verification

Key events: PreToolUse (only blocking hook), PostToolUse, Stop, SubagentStart, SubagentStop, TeammateIdle, TaskCompleted. Async execution supported.

**PAS relevance**: MEDIUM. PAS already uses hooks for self-eval and feedback routing. Agent hooks (spawning subagents for verification) could improve PAS's validation phase. TeammateIdle and TaskCompleted hooks are directly relevant for PAS orchestration quality enforcement.

Source: [Hooks reference](https://code.claude.com/docs/en/hooks)

### Headless Mode / Agent SDK

Claude Code can run programmatically via CLI (`-p` flag) or Python/TypeScript SDK. Key capabilities:
- Structured JSON output via schema enforcement
- Permission modes for unattended operation
- Server-side compaction for 30+ hour sustained operation
- 60%+ of Claude Code teams use non-interactive mode

**PAS relevance**: MEDIUM. Opens the door for PAS processes to be triggered from CI/CD, scheduled runs, or external automation rather than interactive terminal sessions only.

Source: [Headless docs](https://code.claude.com/docs/en/headless)

---

## Competitive Landscape

### Superpowers (53K+ GitHub stars, 52K+ marketplace installs)

**What it is**: A structured software development methodology plugin. Enforces brainstorm-first, plan-second, execute-third with mandatory TDD, sub-agent code review, and Socratic questioning.

**What it does well**: Single-agent methodology enforcement. Clean, opinionated workflow that prevents "code first, think later." Strong community and marketplace adoption. Accepted into official Anthropic marketplace Jan 2026.

**What PAS does better**: PAS handles multi-agent orchestration with formal process definitions, phase-based workflows, and structured feedback loops. Superpowers is single-agent methodology; PAS is multi-agent process management. They operate at different levels of abstraction.

**Opportunity**: Superpowers validates that developers want structured methodology. PAS could position its single-process mode as complementary — or even integrate Superpowers-style methodology within a PAS skill.

Source: [Superpowers GitHub](https://github.com/obra/superpowers)

### Ruflo (formerly Claude Flow) — v3.5, 5,800+ commits

**What it is**: Enterprise swarm orchestration platform for Claude. Deploys 60+ specialized agents, 215 MCP tools, self-learning neural routing, 3-tier model cost optimization.

**What it does well**: Scale and enterprise features. Self-learning task routing, cost optimization via model tiering, RAG integration, distributed agent coordination.

**What PAS does better**: PAS offers formal, composable, human-readable process definitions. Ruflo is infrastructure-heavy; PAS is definition-light and portable. PAS processes are markdown files that version-control naturally. Ruflo requires significant setup and infrastructure.

**Threat**: If Ruflo becomes the default enterprise choice, PAS's more lightweight approach may be seen as "not enterprise-ready." However, Ruflo's complexity is also its weakness — many teams want structure without infrastructure.

Source: [Ruflo GitHub](https://github.com/ruvnet/ruflo)

### everything-claude-code

**What it is**: Batteries-included agent harness with code quality automation, instinct-based learning, cross-harness compatibility (Claude Code, Cursor, OpenCode, Codex).

**What it does well**: Cross-tool compatibility, automated code quality (3-phase lint/format/fix), instinct learning that clusters patterns into skills automatically.

**What PAS does better**: PAS provides formal process structure. everything-claude-code is a collection of enhancements, not a process framework. PAS's feedback loops and phased orchestration are absent from everything-claude-code.

**Opportunity**: The "instinct learning" concept (auto-discovering patterns and graduating them to skills) aligns with PAS's local-first skill philosophy. Worth watching.

Source: [everything-claude-code GitHub](https://github.com/affaan-m/everything-claude-code)

### Ralph Loop (57K+ marketplace installs)

**What it is**: Autonomous coding loop plugin. Runs sustained multi-task sessions with git commit tracking and context resets between iterations.

**What it does well**: Long-running autonomous execution. Context resets between tasks prevent context pollution. Popular in the marketplace.

**What PAS does better**: PAS provides structured multi-agent orchestration, not just looped single-agent execution. PAS has formal phases, feedback, and agent specialization.

Source: [Firecrawl top plugins list](https://www.firecrawl.dev/blog/best-claude-code-plugins)

### Code Review Plugin (50K+ installs, official)

**What it is**: Multi-agent code review with confidence scoring. Spawns multiple AI agents to review from different angles (security, testing, quality).

**Relevance**: Validates multi-agent review as a pattern. PAS could offer more structured, process-defined review workflows that go beyond code review into any domain.

---

## Ecosystem Trends

### Multi-Agent is Mainstream

Gartner reported a 1,445% surge in multi-agent system inquiries from Q1 2024 to Q2 2025. The pattern is now table stakes: Claude Code's native Agent Teams, Ruflo's 60+ agent swarms, and multi-agent code review all confirm this. PAS's multi-agent process definitions are well-positioned.

Source: [Deloitte agentic AI report](https://www.deloitte.com/us/en/insights/industry/technology/technology-media-and-telecom-predictions/2026/ai-agent-orchestration.html)

### Protocol Standardization

Three competing standards for agent communication:
- **MCP** (Anthropic): tool/data integration — already in Claude Code
- **A2A** (Google): agent-to-agent communication
- **ACP** (open): RESTful agent collaboration

PAS currently uses Claude Code's native messaging. As protocols mature, PAS could benefit from or be disrupted by standardized agent communication.

### Plugin Ecosystem Explosion

9,000+ extensions, 29M daily VS Code installs, official marketplace with enterprise features. The plugin ecosystem is large and growing fast. PAS needs to be findable within this ecosystem.

Source: [AI Tool Analysis](https://aitoolanalysis.com/claude-code-plugins/)

### Domain-Specific Specialization

Anthropic launched 11 official Cowork plugins for non-dev domains (Legal, Sales, Marketing, Finance) in Jan 2026. The pattern of structured agent workflows is expanding beyond software development. PAS's domain-agnostic process framework could serve these verticals.

### Headless/CI-CD Adoption

60%+ of teams use Claude Code in non-interactive mode. 45% reduction in code review time for large projects. The trend toward automation means PAS processes should be runnable headlessly, not just interactively.

---

## Opportunities (Ranked by Impact)

### 1. Native Agent Teams Integration (HIGH impact)

PAS orchestration patterns (hub-and-spoke, solo, discussion) should map directly to Agent Teams primitives. Currently PAS builds its own orchestration abstractions. Aligning with native Teams API would reduce friction, leverage platform improvements, and make PAS feel native rather than bolted-on.

**Action**: Refactor PAS orchestration to use TeamCreate/SendMessage/TaskCreate as the runtime layer, with PAS providing the process definition and phase management on top.

### 2. Marketplace Visibility (HIGH impact)

With 9,000+ plugins and 52K+ installs for the top plugin, PAS needs a marketplace presence. Currently PAS has a `.claude-plugin/marketplace.json` but is not in the official Anthropic marketplace.

**Action**: Submit PAS to the official Anthropic marketplace. Write clear, discoverable descriptions. Categorize appropriately.

### 3. Headless Process Execution (MEDIUM-HIGH impact)

PAS processes currently require interactive sessions. With 60%+ headless adoption, PAS should support `claude -p "run /pas-development discovery"` style invocations for CI/CD integration and scheduled runs.

**Action**: Add headless-compatible entry points. Define structured output schemas for process results.

### 4. Subagent Persistent Memory for Agent Learning (MEDIUM impact)

Native `memory: user|project|local` on subagents means PAS agents could accumulate knowledge across cycles without custom memory implementations. Agent-level memory (what the ecosystem-analyst learned, what the QA engineer caught) could persist and improve over time.

**Action**: Add `memory:` configuration to PAS agent definitions. Define memory hygiene practices per agent role.

### 5. Process Templates for Non-Dev Domains (MEDIUM impact)

Anthropic's Cowork plugins show demand for structured workflows outside engineering. PAS's process-agent-skill model is domain-agnostic. Template processes for content review, incident response, onboarding, or compliance could expand PAS's addressable market significantly.

**Action**: Create 2-3 template processes for non-engineering domains to validate the pattern.

### 6. Settings Override for Default Agent (LOW-MEDIUM impact)

Plugins can now set `settings.json` with `"agent": "orchestrator"` to make a PAS orchestrator the default agent for the main thread when the plugin is active. This could make PAS the default workflow layer rather than an opt-in command.

**Action**: Evaluate whether PAS should ship a default agent that provides lightweight process management on every session.

---

## Risks

### 1. Agent Teams Goes GA and Subsumes PAS Orchestration

If Claude Code's native Agent Teams matures to include phase management, feedback loops, and process definitions, PAS's orchestration layer becomes redundant. Agent Teams is experimental now, but Anthropic has strong incentive to make it production-ready.

**Mitigation**: PAS's value is in the *process definition* and *feedback system*, not in the raw orchestration primitives. Keep PAS's differentiator as the formal, composable process layer on top of whatever runtime Anthropic provides. Do not compete on plumbing.

### 2. Plugin Ecosystem Crowding

9,000+ plugins means discoverability is a problem. PAS could get lost in noise. Top plugins have 50K-96K installs; PAS has zero external adoption currently.

**Mitigation**: Clear positioning (PAS is not a methodology or a tool — it's a process framework), marketplace submission, and demonstrable use cases.

### 3. Breaking Changes in Plugin API or Hook System

PAS relies on hooks for self-evaluation and feedback routing. If hook behavior changes (e.g., handler types, lifecycle events, input schemas), PAS could break silently.

**Mitigation**: Pin to documented behavior, not undocumented internals. Add version checks. Monitor Claude Code changelogs.

### 4. Subagent Nesting Limitation

"Subagents cannot spawn other subagents." This is a hard constraint. PAS agents running as subagents cannot delegate to further subagents. Agent Teams allows peer communication but not nesting either. This limits process depth.

**Mitigation**: Use Agent Teams for multi-agent processes (peer topology) rather than subagent chains (hierarchical topology). PAS already uses hub-and-spoke pattern which maps to Teams well.

### 5. Cost Pressure

Agent Teams and multi-agent processes use significantly more tokens than single sessions. As token costs are scrutinized, PAS's multi-agent approach could be seen as expensive.

**Mitigation**: Support model routing (use Haiku for research agents, Opus for decision-making). Document cost profiles for different process configurations. Offer solo-mode as a lightweight option.
