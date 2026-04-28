# Ecosystem Analyst — Discovery Report (Cycle 4)

## 1. Market Positioning

**Problem PAS solves:** Building complex AI workflows with Claude Code today means monolithic prompts — no modularity, no targeted feedback, no reuse. When one part breaks, you touch everything. PAS decomposes agentic workflows into three composable primitives (Process, Agent, Skill), each with its own feedback backlog and changelog.

**Differentiation:**
- **Feedback-first architecture.** Every artifact collects structured improvement signals (PPU, OQI, GATE, STA). No other Claude Code framework treats feedback as a first-class lifecycle concern with signal types, routing hooks, and completion gates.
- **Recursive composition.** Processes contain agents contain skills, and each layer can nest the others. This mirrors how real organizations delegate work.
- **Self-improving system.** PAS uses itself to develop itself (the pas-development process on `dev` branch). This is both a demonstration and a forcing function — PAS must work well enough to produce its own upgrades.
- **Standards-based.** Skills follow the Agent Skills open standard (SKILL.md format with YAML frontmatter). This is forward-looking: if Agent Skills gains traction, PAS artifacts are portable.

**Core value proposition:** PAS is the only framework that gives you modular agentic pipelines *and* a built-in mechanism for those pipelines to improve over time.

## 2. Plugin Maturity

**Version:** 1.3.0 (marketplace.json says 1.1.0, plugin.json says 1.2.0 — version drift indicates rapid iteration outpacing manifest updates).

**Stage: Late alpha / early beta.** Evidence:

| Indicator | Assessment |
|-----------|------------|
| Core abstractions (P/A/S) | Stable since v1.0.0 |
| Orchestration patterns (4 patterns) | Stable, heavily hardened in v1.1.0-1.3.0 |
| Feedback system | Functional after v1.3.0 fixes, but untested in production since the fix |
| Generation scripts | Shipped in v1.2.0, include --base-dir safety |
| Hook system | 5 hooks across 4 lifecycle events, significant v1.3.0 overhaul |
| Self-hosting | PAS develops itself via pas-development process |
| External user testing | None documented |
| Documentation | README is solid; no tutorials or walkthroughs |

**Trajectory:** Three releases in two days (1.0-1.3.0, all 2026-03-06 to 2026-03-07). This is extremely fast iteration. The changelog shows the team finding and fixing real structural problems (feedback not firing, hooks silently failing, workspace lifecycle gaps). The pattern is: build, use, discover structural gap, fix. This is healthy early-stage development.

**Version sync issue:** marketplace.json (1.1.0) and plugin.json (1.2.0) lag behind CHANGELOG.md (1.3.0). This will confuse marketplace users.

## 3. Adoption Readiness

**Not ready for external users.** Specific gaps:

1. **Untested feedback loop.** The v1.3.0 release fixes the feedback system, but Issues #11 and #12 are still open — the fixes haven't been validated in a real session yet. The core selling point (self-improving workflows) hasn't been proven to work end-to-end without user intervention.

2. **No getting-started tutorial.** The README shows install + quick start, but there's no walkthrough of "create your first process." A new user hitting `/pas:pas I want to build a code review pipeline` will encounter PAS's brainstorming mode with no context for what's happening.

3. **No example processes.** The only process is PAS's own self-management process. Users need to see a complete, simple example (e.g., a code review process) to understand what PAS creates.

4. **Version manifests are stale.** marketplace.json and plugin.json need to match the actual version.

5. **No test suite.** Generation scripts have `--base-dir` for isolation, but there are no automated tests. A user installing PAS has no way to verify it works in their environment.

6. **Open issues indicate ongoing instability.** Issues #6, #11, #12 all describe fundamental workflow problems. These need to be closed and verified before inviting external users.

## 4. Ecosystem Integration

**Integration with Claude Code plugin system:**

- PAS uses the plugin marketplace format correctly (marketplace.json catalog, plugin.json metadata, skills with SKILL.md).
- Hook system leverages Claude Code's hooks.json auto-discovery — no manual configuration needed. This is clean.
- Skills use `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PLUGIN_ROOT}` variables correctly for path resolution.
- The `/pas:pas` entry point follows Claude Code's slash command convention.

**Gaps:**

- **Plugin.json version drift** (1.2.0 vs actual 1.3.0). If the marketplace reads plugin.json for version info, users see stale metadata.
- **No plugin dependency declaration.** PAS doesn't declare what Claude Code version it requires. Hook lifecycle events (SessionStart, SubagentStop, TaskCompleted, Stop) are relatively recent — older Claude Code versions may not support them.
- **Library bootstrap copies files.** PAS copies its library skills into the user's project on first run. This works but creates a sync problem — when PAS updates its library, user copies are stale. No mechanism exists to detect or resolve this drift.

## 5. Competitive Landscape

The Claude Code agentic workflow space is nascent. Most "competition" is really different approaches to the same problem:

| Approach | Description | PAS Advantage | Their Advantage |
|----------|-------------|---------------|-----------------|
| **CLAUDE.md conventions** | Hand-written instructions in project files | PAS is structured, composable, improvable | Zero overhead, no install |
| **Custom skills** (Agent Skills standard) | Individual SKILL.md files for specific tasks | PAS adds orchestration, agents, feedback | Simpler, no framework dependency |
| **Prompt chains** (manual) | Developers chain prompts manually across sessions | PAS automates the coordination | Full control, no abstractions |
| **MCP servers** | External tool integrations via Model Context Protocol | PAS orchestrates workflows; MCP provides tools. Complementary. | Broader ecosystem, language-agnostic |
| **Agentic frameworks** (LangChain, CrewAI, AutoGen, etc.) | Code-first multi-agent frameworks | PAS is zero-code, plugin-native, feedback-first | More mature, larger communities, language flexibility |

**Key insight:** PAS's real competition is not other frameworks — it's the "good enough" approach of hand-crafted CLAUDE.md files and ad-hoc skill collections. PAS needs to demonstrate that its overhead pays for itself through the feedback loop.

**MCP integration opportunity:** PAS doesn't currently leverage MCP servers. Agents could be configured to use specific MCP tools, making PAS a coordination layer above MCP's tool layer.

## 6. Growth Trajectory

Based on the changelog, PAS is evolving in this direction:

```
v1.0.0: Core primitives (P/A/S), plugin structure, entry point
v1.1.0: Feedback from first real use → hardened orchestration, self-eval, library bootstrap
v1.2.0: Generation scripts → reduce manual scaffolding, faster process creation
v1.3.0: Feedback enforcement → hooks, gates, completion blocking
```

**Pattern:** Each release addresses the most painful gap exposed by the previous release. The trajectory is: establish primitives, then use them, then fix what breaks, then automate what's tedious, then enforce what gets skipped.

**Is it the right direction?** Yes, with a caveat. The inward focus (fixing PAS's own feedback loop) is necessary and correct for this stage. But the next releases need to shift outward — proving PAS works for *someone else's* use case, not just its own self-development.

**Risk:** PAS is optimizing for its own development workflow. The pas-development process has 7 agents and 4 phases — this is complex. A typical first-time user wants to create a 2-agent pipeline. PAS needs to prove it handles simple cases elegantly, not just its own meta-case.

## 7. Priority Recommendation

**What would make PAS most compelling to adopt, in order:**

### P0: Validate the feedback loop works (pre-requisite for everything)
Close Issues #11 and #12. Run a complete session where feedback is collected, routed, and applied without user intervention. Until this works, PAS's core promise is unproven.

### P1: Ship one polished example process
Create a simple, complete example process (e.g., code-review, PR-summarizer, or test-generator) that a user can install and run immediately. This serves as:
- Proof that PAS creates useful things
- A template for users to model their own processes
- A test case for the full PAS lifecycle

### P2: Sync version manifests
Update marketplace.json and plugin.json to match the actual version. This is trivial but critical for trust — users seeing version mismatches will question quality.

### P3: Write a 5-minute tutorial
A single document: "Create your first PAS process in 5 minutes." Walk through a real example end-to-end. This is the highest-leverage documentation investment.

### P4: Add Claude Code version requirement
Declare minimum Claude Code version in plugin.json. PAS relies on hooks (SessionStart, SubagentStop, TaskCompleted, Stop) that may not exist in older versions.

### P5: Explore MCP integration
Position PAS as the orchestration layer that coordinates agents using MCP tools. "MCP gives you tools. PAS gives you workflows." This is a natural ecosystem fit and a compelling narrative.

## Summary

PAS is a genuinely novel framework with a strong core idea: modular agentic workflows that improve through structured feedback. It's at the late-alpha stage — the primitives are stable, the orchestration is hardened, but the feedback loop (its core differentiator) hasn't yet been proven to work without user intervention. The immediate priority is validating the feedback system end-to-end, then shifting focus from self-development to external adoption through examples, tutorials, and ecosystem integration. PAS's biggest risk is not competition — it's that the overhead of learning PAS doesn't clearly pay off compared to hand-crafted CLAUDE.md files. The feedback loop is the answer to that, which is why proving it works is the single most important thing.
