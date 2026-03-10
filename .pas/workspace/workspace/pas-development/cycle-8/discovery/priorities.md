# Cycle 8 Discovery Priorities

## Cycle Type
Owner directive: Create a 12-month roadmap for PAS framework development

## Directive
Build a comprehensive, actionable 12-month roadmap (March 2026 - March 2027) covering architecture, DX, community, and ecosystem strategy. Output: `docs/plans/roadmap-2026-2027.md`

## Discovery Summary

### Converging Themes (all 5 agents aligned)

**Theme 1: Onboarding & First Experience (ALL agents)**
- Zero stars, zero forks, zero external contributors — no adoption yet
- Time to first process: 1-2 hours today → target 5-15 minutes
- No quickstart, no tutorial, no `/pas help`, no example processes
- Single most impactful investment for adoption

**Theme 2: Testing & Quality Infrastructure (Architect, Feedback Analyst)**
- Zero test coverage for hooks, bash scripts, generated artifacts
- All QA is manual (qa-engineer agent)
- Biggest structural risk as plugin grows
- Foundation must come before features

**Theme 3: Release & Sync Automation (Architect, Feedback Analyst)**
- Library mirror drift caused real bugs (cycle-6, cycle-7)
- Branch management was manual until cycle-7 fix
- Cycle-7 backlog: PreToolUse guards, PostToolUse sync, worktree release
- Need hooks and scripts, not just process documentation

**Theme 4: Runtime Observability (DX Specialist, Ecosystem Analyst)**
- No `/pas status` during process execution
- Feedback system is invisible to users — most distinctive feature can't be seen working
- Runtime dashboard would be a unique differentiator vs. competitors

**Theme 5: Process Distribution & Composition (Architect, Ecosystem, Community)**
- Can't share processes across repos or users
- Can't call processes from processes (no subprocess invocation)
- No process marketplace/registry
- Needed for ecosystem growth beyond single-user

**Theme 6: Platform Integration Depth (Ecosystem, Feedback)**
- Claude 5 "Dev Team" mode expected Q2-Q3 2026
- MCP Tool Search enables practical bundling
- Hook enforcement replacing instruction-based guidance
- PAS must prepare for platform shifts while maintaining abstraction

### Competitive Landscape
- Superpowers (42K stars): single-agent methodology — complementary, not competitive
- everything-claude-code (50K stars): batteries-included dev environment
- Ruflo: enterprise swarm orchestration
- PAS unique value: formal, composable process definitions with structured feedback loops

### Key Architectural Decisions (shape the roadmap)
1. Library mirror strategy: sync script vs. symlinks vs. single source
2. Process distribution unit: how are processes packaged and shared?
3. Hook implementation language: bash (current) vs. Node.js vs. mixed
4. Backward compatibility strategy: semver, migration scripts, or breaking releases?

### Quarterly Milestone Targets
- Q1 (Apr-Jun 2026): 25 stars, first external issue, 2-3 example processes shipping
- Q2 (Jul-Sep 2026): 100 stars, 3 contributors, docs site, templates
- Q3 (Oct-Dec 2026): 300 stars, 10 contributors, process registry, runtime dashboard
- Q4 (Jan-Mar 2027): 750+ stars, ecosystem established, process marketplace

## Agent Contributions
- Feedback Analyst: 30 signals analyzed, 5 strategic themes, phasing recommendation
- Community Manager: GitHub metrics, marketplace analysis, quarterly adoption milestones
- Framework Architect: Architecture assessment, 6 fragility areas, 3-phase structure, 4 key decisions
- DX Specialist: Onboarding audit, 7 DX gaps, time-to-value analysis
- Ecosystem Analyst: Competitive landscape, 7 ranked opportunities, Claude 5 risk assessment
