# Cycle 9 Discovery Priorities

## Directive
Owner directive: Create a 6-month roadmap for PAS. Identify missing features, improve UX, increase usability and effectiveness. Team has full creative freedom and ownership.

## Discovery Summary

### Process
- Pattern: discussion (5 agents)
- Round 1: All 5 agents produced independent assessments
- Round 2: 4 targeted debate questions on key tensions — all 4 responses received
- All tensions resolved: lightweight mode (sound), Agent Teams alignment (definition layer), feedback scope (keep separate)

### Converging Themes (high agreement across agents)

**Theme 1: Product Quality Over Process Quality**
- Feedback analyst's sharpest finding: all 29 feedback signals are about process quality (how agents work), ZERO about product quality (whether PAS is good software)
- DX specialist's audit found 10 concrete product issues no signal ever captured
- The feedback loop is entirely internal and meta — the biggest structural blind spot
- Fix: periodic DX audit as a recurring activity (dx-specialist proposal), separate from operational feedback

**Theme 2: Onboarding & First Experience**
- All 5 agents flagged this. No README, no quickstart, no tutorial, no examples
- DX specialist found 4 CRITICAL friction points: no real quickstart, confusing `/pas:pas` syntax, unclear install, invisible filesystem changes
- Community manager: predicted first external report is "What is this?"
- Framework architect caution: don't build tutorials for users who don't exist yet
- DX specialist resolution: "pas-development IS the first-time experience for the next user" — quick DX wins benefit the current user too
- Consensus: fix real friction now (minutes of work), defer heavy onboarding content until adoption signals exist

**Theme 3: Architectural Foundations**
- Framework architect identified 3 Tier-1 blockers: library mirror drift, no subprocess invocation, agent spawn timing race
- Library mirror drift already caused real bugs (cycles 6-7). Copy-on-bootstrap model guarantees divergence
- Agent spawn timing flagged in cycle-7 AND cycle-8, still unfixed — every multi-agent cycle loses messages
- Orchestration pattern duplication: ~300 of 577 lines identical across 4 patterns, every fix applied 4x
- Fix: library dedup, lifecycle extraction, ready-handshake protocol

**Theme 4: Testing & Reliability**
- Zero test coverage: 9 bash scripts (~1100 lines), no tests
- `route-feedback.sh` (201 lines) is most critical — a bug silently drops feedback
- Community manager: test cleanup destroyed 53 files in one incident
- All validation has been manual (QA engineer agent)
- Fix: test harness for hooks and bash scripts

**Theme 5: Native Platform Alignment**
- Ecosystem analyst: Agent Teams (experimental, Feb 2026) is closest platform feature to PAS orchestration
- PAS already uses TeamCreate/SendMessage — natural alignment
- Risk: Agent Teams goes GA and subsumes PAS orchestration layer
- Opportunity: PAS positions as process definition layer on top of native primitives
- Ecosystem analyst (revised after debate): filter everything through "does this make PAS better for the one person actually using it?"

**Theme 6: Feedback System Evolution**
- Feedback analyst: existing signal types (PPU/OQI/GATE/STA) only capture operational issues
- DX specialist: don't add a 5th signal type — keep operational and product feedback separate
- Proposal: periodic DX audit checkpoint in pas-development process, every N cycles
- Product-level findings tracked separately (product-feedback/ or differently-tagged GitHub issues)

### Key Tensions Resolved

1. **Lightweight mode vs complexity**: DX specialist wants simpler processes; framework architect wants subprocess invocation. Resolution: both valid, sequenced — simplify first (months 1-2), then expand capabilities (months 3-4)
2. **External focus vs internal quality**: Ecosystem analyst originally ranked marketplace #2; revised to "when ready" milestone after architect pushback. Consensus: product readiness before external visibility
3. **One-user focus vs onboarding**: Not competing priorities — fixing real DX friction benefits the current user. Quick wins now, heavy content later

### Tensions Resolved in Round 2

1. **Lightweight process mode** (framework-architect): Architecturally sound. Hooks already `exit 0` when no workspace found — zero hook changes needed. Add `lifecycle: lightweight` option to process.md frontmatter. Skip workspace/status/tasks/completion-gate. Keep process structure, gates, feedback (written to process backlog instead of workspace). Upgrade path to `lifecycle: full` when multi-session resumability needed.

2. **Agent Teams alignment** (framework-architect): PAS should define WHAT happens (phases, gates, feedback) and delegate HOW agents execute to native primitives. The 300 duplicated orchestration lines are almost entirely lifecycle protocol — extracting lifecycle into a shared module leaves pattern files at 30-50 lines of pure process-definition logic. That's PAS's differentiated layer. If Claude Code adds native "phase" or "gate" concepts, PAS adopts them rather than competing.

3. **Feedback system scope** (feedback-analyst): Do NOT extend signal system for product quality. Evidence: 10 DX findings in one focused audit vs 0 product signals in 8 cycles of self-evaluation. The signal types are designed for agent self-reflection at shutdown, not product assessment. Instead: periodic DX audits as a separate recurring activity in pas-development. Product issues become planning-phase work items, not feedback signals. Feedback system stays focused on process quality (well-calibrated for that purpose).

### Remaining Open Questions
1. **QA activation timing**: Currently end-of-pipeline, always gets squeezed. No concrete proposal yet.
2. **Agent spawn timing fix**: Ready-handshake protocol agreed upon but implementation details TBD.

### Agent Contributions
- **Feedback analyst**: 29 signals analyzed, 5 clusters, blind spots observation (strongest finding this cycle)
- **Community manager**: 8 closed issues analyzed, 7 gap predictions, honest self-correction on metrics
- **Framework architect**: 22 artifacts audited, 11 capability gaps in 3 tiers, dependency-ordered 6-month sequence
- **DX specialist**: 10 friction points (4 critical), 5 prioritized recommendations, debate resolution on one-user tension
- **Ecosystem analyst**: Platform changes documented, 6 opportunities ranked, honest self-correction on marketplace timing

## Proposed 6-Month Roadmap Structure

Based on discovery synthesis, dependencies create a natural order:

### Month 1-2: Foundation & Quick Wins
- Fix all DX quick wins (PPU inconsistency, define "slug", filesystem warning, confusing naming)
- Library dedup: processes reference plugin library directly, project-level override mechanism
- Extract shared lifecycle from orchestration patterns (300 duplicated lines → shared module)
- Implement agent ready-handshake protocol (recurring bug, 3 cycles unfixed)
- Add periodic DX audit as formal checkpoint in pas-development process

### Month 2-3: Reliability
- Test harness for bash hooks and scripts (priority: route-feedback.sh)
- Graceful error handling (silent failures → informative messages)
- Feedback signal schema formalization (currently prose + inline regex)
- README with end-to-end example (one compelling process a stranger can understand)

### Month 3-4: Capability Expansion
- Subprocess invocation (process calling process)
- Evaluate lightweight process mode for simple solo-pattern workflows
- Native Agent Teams alignment assessment (as platform matures)

### Month 4-5: Process Portability
- Process packaging format for cross-repo sharing
- Import mechanism for external processes
- Subagent persistent memory exploration

### Month 5-6: Polish & Positioning
- Runtime status tooling (`/pas status`)
- Expanded configuration with documented schema
- Marketplace readiness assessment (not submission — assessment of readiness)
- Process templates if adoption signals warrant

### Filtering Principle
Every item must pass: "Does this make PAS better for the owner's actual workflows?" External positioning follows product quality, not the other way around.
