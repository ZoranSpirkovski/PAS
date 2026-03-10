# Framework Assessment — Cycle 9

## Convention Compliance

**Artifacts audited**: 22 (1 plugin entry point, 5 hook scripts, 5 library skills, 1 process definition, 1 agent definition, 5 creation/feedback skills, 3 creation scripts, 1 visualization script)

**Violations found**: 0 structural violations. All artifacts have `feedback/backlog/` and `changelog.md`. All skills follow the Agent Skills spec (YAML frontmatter + markdown body). Agents are process-local. Library skills are genuinely reused (self-evaluation carried by every agent, orchestration carried by every orchestrator, message-routing carried by orchestrators).

**Observation**: The empty changelogs for `self-evaluation`, `message-routing`, and the PAS orchestrator agent (`plugins/pas/processes/pas/agents/orchestrator/changelog.md`) indicate these haven't been revised since creation. Not a violation, but worth noting — these are high-traffic artifacts that should accumulate feedback.

## Completeness

**Processes checked**: 1 (`plugins/pas/processes/pas/`)
- All agents referenced in process.md exist (orchestrator)
- All skills referenced in agent.md exist (5 creation skills + self-evaluation + message-routing)
- Mode files exist with correct frontmatter (supervised: gates enforced, autonomous: gates advisory)
- Phase I/O forms valid DAG (understand-intent -> execute, sequential)

**No issues** in the delivered plugin structure.

## Capability Gaps

### Tier 1: Blocks Everything Else

**1. Library mirror drift — no single source of truth**
- File: `plugins/pas/library/` vs project-level `library/`
- The bootstrap design copies library skills from plugin to project at first-run (`SKILL.md` lines 31-35). After that, the copies diverge. The plugin copy is the canonical source, but user processes reference the project copy. There is no mechanism to detect or reconcile drift.
- **Actual drift found**: `library/visualize-process/feedback/backlog/` has 2 feedback files not in the plugin copy. This is mild, but the architecture guarantees this gets worse over time.
- **Impact**: Plugin upgrades silently conflict with local modifications. Users who customize library skills lose changes on upgrade. Users who don't customize get stale copies.
- **Architectural fix needed**: Either (a) processes reference library skills via the plugin directly (no copy), or (b) a version-aware sync mechanism that detects conflicts. Option (a) is simpler and eliminates the problem entirely.

**2. No process composition (subprocess invocation)**
- File: `plugins/pas/library/orchestration/hub-and-spoke.md` line 170 mentions `subprocess: {path}/status.yaml` — but this is a status-tracking convention only. There is no mechanism for a process to invoke another process.
- **Impact**: Complex workflows require monolithic processes. PAS cannot express "run the article process for each topic in the batch" or "run QA validation as a subprocess of the deployment pipeline." This limits PAS to single-process workflows.
- **Architectural fix needed**: A `subprocess` phase type or library skill that handles: spawning a child process, tracking its status, passing input/output, and merging feedback back to the parent.

**3. Agent spawn timing race condition**
- File: All orchestration patterns (`hub-and-spoke.md`, `discussion.md`, `sequential-agents.md`)
- Documented in memory as a known issue. Agents spawned via TeamCreate read their `agent.md` before processing mailbox. Messages sent during spawn are lost. Every multi-agent cycle requires re-sending prompts.
- **Impact**: Every hub-and-spoke and discussion cycle wastes tokens and time on re-sends. This is a platform-level issue (Claude Code TeamCreate behavior), not fixable within PAS alone.
- **Architectural mitigation**: Add a "ready handshake" protocol to orchestration patterns: after spawning agents, orchestrator waits for each agent to send a "ready" message before sending work. This doesn't fix the platform issue but makes PAS resilient to it.

### Tier 2: High Value, Not Blocking

**4. No test coverage for hooks or scripts**
- Files: `plugins/pas/hooks/` (5 scripts), `plugins/pas/processes/pas/agents/orchestrator/skills/*/scripts/` (3 scripts), `plugins/pas/library/visualize-process/generate-overview.sh`
- 9 bash scripts totaling ~1100 lines with zero automated tests. These scripts handle critical lifecycle operations (session tracking, self-eval enforcement, feedback routing, artifact creation).
- `route-feedback.sh` is the most complex at 201 lines with signal parsing, target resolution, and GitHub issue filing. A bug here silently drops feedback.
- **Impact**: Any change to hooks risks silent regression. The hook scripts are the enforcement backbone of PAS — if they break, the feedback loop breaks.
- **Fix**: Create a test harness using bash with mock inputs (JSON piped to stdin). Priority files: `route-feedback.sh`, `verify-completion-gate.sh`, `check-self-eval.sh`.

**5. No process portability (cross-repo sharing)**
- File: `plugins/pas/skills/pas/SKILL.md` lines 30-36 (first-run detection hardcodes local paths)
- PAS processes are tightly coupled to the repo they live in. Paths are relative, library references are local copies, workspace paths are hardcoded. There is no mechanism to share a process definition across repos or import someone else's process.
- **Impact**: Every user starts from scratch. No process marketplace, no community templates, no "install this article-writing process."
- **Architectural fix needed**: A process packaging format that bundles process.md + agents + skills + required library skills into a portable unit that PAS can install into any project.

**6. Feedback signal types lack versioning and schema**
- File: `plugins/pas/library/self-evaluation/SKILL.md`
- Signal types (PPU, OQI, GATE, STA) are defined by prose in SKILL.md. The routing hook (`route-feedback.sh` line 128) parses signals with regex (`^\[(PPU|OQI|GATE|STA)-[0-9]+\]`). Adding a new signal type requires changing: the skill doc, the routing hook regex, and the applying-feedback skill.
- **Impact**: Extending the feedback system (e.g., adding a "performance metric" signal type) requires coordinated changes across 3+ files with no validation.
- **Fix**: Define a signal schema (even just a YAML spec in `library/`) that all three consumers reference. Parse signals with a shared utility rather than inline regex.

**7. Orchestration pattern duplication**
- Files: `hub-and-spoke.md` (250 lines), `solo.md` (93 lines), `discussion.md` (119 lines), `sequential-agents.md` (115 lines)
- All four patterns duplicate: workspace creation (identical mkdir + status.yaml), task creation (identical [PAS] prefix convention), completion gate (identical 4-condition check), shutdown sequence (nearly identical). Combined, ~300 lines of the ~577 total are duplicated.
- **Impact**: Every fix must be applied 4 times (already happened twice — see changelog). This was the root cause of `sequential-agents.md` having no startup/shutdown sections until cycle 5.
- **Fix**: Extract shared protocol into a `library/orchestration/lifecycle.md` that all patterns include. Pattern files define only their unique behavior (parallelism rules, handoff protocol, turn-taking).

### Tier 3: Worth Doing in 6 Months

**8. No runtime state inspection**
- Process status is tracked via `status.yaml` files scattered across `workspace/`. There is no `pas status` command that shows: active processes, their phases, completion percentage, or pending feedback.
- **Impact**: Users must manually find and read status files. The orchestrator must scan for active workspaces using find commands (which `workspace.sh` does with stat-based sorting).

**9. Plugin configuration is minimal**
- File: `plugins/pas/pas-config.yaml` — only 2 fields: `feedback` and `feedback_disabled_at`
- No configuration for: default model tier, default orchestration pattern, workspace location, library skill preferences, or custom signal types.
- **Impact**: Every process must redundantly specify defaults. Users cannot set project-wide preferences.

**10. Visualization is process-only**
- File: `plugins/pas/library/visualize-process/generate-overview.sh` (887 lines)
- The visualizer generates HTML for a single process. There is no cross-process view, no feedback dashboard, no signal accumulation visualization.
- **Impact**: Users cannot see PAS holistically. As processes accumulate, there's no bird's-eye view.

**11. No hook composition or ordering**
- File: `plugins/pas/hooks/hooks.json`
- The Stop event has two hook groups (verify-completion-gate, route-feedback) but their execution order depends on array position in JSON. There is no explicit priority or dependency system.
- **Impact**: If route-feedback ran before verify-completion-gate, it could route incomplete feedback. The current order happens to be correct, but it's implicit.

## Trajectory

**Actively improving (significant changelog activity):**
- Orchestration patterns — 3 major revisions in 2 days (self-eval enforcement, workspace HARD REQUIREMENT, task creation + hook enforcement)
- PAS entry point (`SKILL.md`) — self-setup, framework feedback mechanism, hook auto-discovery
- Hook infrastructure — session tracking, completion gate, feedback routing all built recently

**Stalled (no changes despite known issues):**
- Self-evaluation skill — empty changelog. Core to the feedback loop but never revised.
- Message-routing skill — empty changelog. No iteration since creation.
- Library mirror mechanism — known drift issue from cycle 6-7, no fix attempted.
- Agent spawn timing — flagged in cycle 7 AND cycle 8, not addressed.
- Test coverage — mentioned in multiple feedback signals, not started.

## Architectural Observations

### What PAS does well

The framework has a remarkably coherent design for its age (2 days since repo creation to v1.3.0). The layered architecture — plugin > processes > agents > skills — with library graduation and feedback loops is sound. The hook infrastructure for lifecycle enforcement is the strongest structural element: it turns aspirational guidelines into enforced contracts. The signal taxonomy (PPU/OQI/GATE/STA) is well-designed for its purpose.

### What needs to change architecturally for the 6-month vision

**1. Eliminate library duplication entirely.** The copy-on-bootstrap model was a reasonable v1 approach, but it creates guaranteed drift. Processes should reference plugin library skills directly (via `${CLAUDE_PLUGIN_ROOT}/library/`), with a project-level override mechanism for customization. This is foundational — every other improvement gets harder if library skills can silently diverge.

**2. Extract shared lifecycle protocol from orchestration patterns.** The current duplication is unsustainable. Every bug fix touches 4 files. Extract workspace creation, task creation, completion gate, and shutdown sequence into `library/orchestration/lifecycle.md`. Pattern files become 30-50 lines of unique behavior each.

**3. Build subprocess invocation.** This is the single largest missing capability. Without it, PAS can only express flat workflows. With it, PAS can express: batch processing, nested quality gates, reusable validation pipelines, and process templates that compose.

**4. Add a ready-handshake to the agent spawn protocol.** This is a workaround for a platform limitation, but it's the right workaround. Orchestration patterns should specify: spawn agent, wait for "ready" message, then send work. Add this to the shared lifecycle protocol (point 2) so it's implemented once.

**5. Build process packaging for cross-repo portability.** A `pas-package.yaml` manifest that lists: process.md, agents, skills, required library skills, and hook requirements. A `pas install` command that unpacks it into the target project. This enables a process ecosystem.

### Priority ordering for the 6-month roadmap

The dependencies create a natural sequence:

1. **Month 1-2**: Library dedup + lifecycle extraction (foundational, unblocks everything)
2. **Month 2-3**: Test harness for hooks + ready-handshake protocol (reliability)
3. **Month 3-4**: Subprocess invocation (capability expansion)
4. **Month 4-5**: Process packaging + cross-repo sharing (ecosystem)
5. **Month 5-6**: Runtime status tooling + expanded configuration (UX polish)

Each tier builds on the previous. Library dedup must come first because every subsequent change touches library skills. Test coverage must precede subprocess invocation because hooks get more complex. Process packaging requires subprocess invocation to be useful (packaged processes need to compose).

### Key risk

The biggest risk is over-engineering. PAS has one user. The 6-month roadmap should be filtered through: "does this make PAS better for the owner's actual workflows?" rather than "does this make PAS look like a mature framework?" Features like a process marketplace matter only if there are processes worth sharing. Focus on making PAS's own development process (pas-development) excellent first — that validates every architectural change against real usage.
