# Framework Architect Assessment — Cycle 4 Discovery

## 1. Structural Health

### What's Solid

**Plugin structure is clean and coherent.** The `plugins/pas/` layout follows a logical hierarchy: `skills/pas/SKILL.md` as the entry point, `processes/pas/` for the self-management process, `library/` for reusable skills, `hooks/` for lifecycle enforcement. Each concern has a clear home.

**Orchestration patterns are comprehensive.** The four patterns (hub-and-spoke, discussion, solo, sequential-agents) cover the realistic design space well. The decision matrix in `SKILL.md` is clear. All four patterns now include full startup sequences, shutdown sequences, and completion gates — this is a major improvement from the earlier state where discussion and sequential-agents were incomplete.

**The creation skill chain is well-designed.** `creating-processes` orchestrates the full flow: clarify goal, design phases, determine agents, select pattern, generate, create agents, verify. Each step is well-scoped. `creating-agents`, `creating-skills`, and `creating-hooks` are properly factored as composable pieces that the process creator invokes.

**Hook infrastructure is architecturally sound.** The 5-hook system (SessionStart, SubagentStop, TaskCompleted x1, Stop x2) covers the critical lifecycle points. The hooks.json schema is correct, scripts use proper boilerplate, and the event catalog reference is thorough.

**Self-evaluation signal taxonomy is strong.** PPU/OQI/GATE/STA covers the feedback space well — preferences, quality issues, change gates, and stability anchors. The routing chain (agent writes locally, hook routes to backlog, applicator processes) is a clean separation of concerns.

### What's Missing

**No process versioning or migration story.** When process definitions change (new phases, reorganized agents), there's no mechanism to handle existing workspaces created under the old definition. A workspace from cycle-3 has a different phase structure than cycle-4 might — the framework has no concept of this.

**No cross-process communication.** Processes are fully isolated. There's no mechanism for one process to trigger another, or for a subprocess to report back to a parent. The `subprocess: {path}/status.yaml` reference in hub-and-spoke is mentioned but not specified.

**No error recovery beyond single-session scope.** The resumability section in hub-and-spoke handles interrupted sessions, but there's no mechanism for a process that fails across multiple sessions to escalate or change strategy. The retry logic is single-session: self-recover, orchestrator retry, escalate to user. If the user comes back next week, the framework treats it as a fresh resume, not a continued failure.

### What's Fragile

**Active workspace detection via most-recent-mtime status.yaml.** Every hook uses the same `find + sort -rn` pattern to locate the active workspace. This breaks when multiple workspaces exist with similar modification times. If two process instances run close together (or a user edits an old status.yaml), the wrong workspace gets selected. This is duplicated across 5 scripts with no shared implementation.

**The `route-feedback.sh` path resolution divergence.** The deployed script at `plugins/pas/hooks/route-feedback.sh` includes a `plugins/` fallback search that the reference version in `pas-feedback-hooks.md` does not. The deployed version is more complete (it searches `$CWD/plugins` as fallback for process, agent, and skill targets), but this divergence between reference and deployed code will cause confusion. Issue #6 specifically called out this problem.

**check-self-eval.sh has two different behaviors.** The deployed version at `plugins/pas/hooks/check-self-eval.sh` uses `exit 2` to block the subagent (it's a SubagentStop hook that CAN block). The reference version in `pas-feedback-hooks.md` uses `exit 0` and just logs a warning. These should be the same. The deployed version is correct — SubagentStop supports blocking via exit 2.

## 2. Hook Architecture Review

### Current Hook Design

| Hook | Event | Purpose | Can Block? |
|------|-------|---------|-----------|
| `pas-session-start.sh` | SessionStart | Inject PAS lifecycle context, record session ID | No |
| `check-self-eval.sh` | SubagentStop | Block subagent if no self-eval written | Yes |
| `verify-task-completion.sh` | TaskCompleted | Block [PAS] tasks if deliverables missing | Yes |
| `verify-completion-gate.sh` | Stop | Block orchestrator stop if feedback missing | Yes |
| `route-feedback.sh` | Stop | Route feedback signals to artifact backlogs | No (runs after gate) |

### Assessment

**The hook chain is well-ordered for Stop.** `verify-completion-gate.sh` fires first and blocks if feedback is missing. `route-feedback.sh` fires second to route whatever exists. This is correct — gate before routing.

**SessionStart context injection is the right approach.** Rather than relying on agents to remember to read lifecycle instructions, the hook injects them into every session. The active workspace detection and session ID tracking are valuable.

**TaskCompleted enforcement is smart.** Using `[PAS]` prefix as a matcher-free discriminator is elegant — it avoids interfering with non-PAS tasks while enforcing PAS lifecycle tasks.

### Gaps

**No SessionEnd hook.** The `SessionEnd` event exists in the catalog but PAS doesn't use it. This matters because `route-feedback.sh` runs on `Stop` — but if the session ends via `clear`, `logout`, or `prompt_input_exit` (non-Stop termination), feedback routing never runs. A SessionEnd hook that runs the same routing logic would be a safety net for non-graceful exits.

**No SubagentStart hook.** When the orchestrator spawns team members, the spawn prompt must include PAS lifecycle context (workspace path, self-evaluation instructions, feedback status). This is currently documented in the orchestration patterns but not enforced. A SubagentStart hook could inject minimal PAS context into every subagent, reducing the reliance on orchestrators following spawn prompt conventions correctly.

**The infinite-loop prevention in `verify-completion-gate.sh` is a single boolean check.** `stop_hook_active: true` means "I already blocked once, let them stop." This prevents infinite blocking but also means a second stop attempt always succeeds even if the deliverables are still missing. The orchestrator could fail to write feedback, get blocked, write nothing, and stop on the second attempt. A more robust approach would check whether any progress was made between the two stop attempts.

**check-self-eval.sh checks for ANY .md file in the feedback directory**, not a file specific to the stopping agent. If agent A wrote feedback, agent B would pass the check without writing anything. The deployed script should check for a file matching the `agent_id` pattern, not just any .md file.

## 3. Orchestration Pattern Completeness

### Coverage Assessment

| Pattern | Real-World Tested? | Notes |
|---------|-------------------|-------|
| hub-and-spoke | Yes (pas-development) | Primary pattern, most detailed |
| solo | Yes (PAS self-management) | Simple and correct |
| discussion | Partially (Discovery phase uses it conceptually) | Never run as a standalone process |
| sequential-agents | No | Only documented, never tested in production |

### Missing Guidance

**No guidance on pattern switching mid-process.** A process might start as solo during prototyping and upgrade to hub-and-spoke as it matures. The solo pattern mentions "When to Upgrade" but doesn't specify HOW — what changes in process.md, what happens to existing workspaces, whether migration is automatic.

**No guidance on hybrid patterns within a single process.** The pas-development process itself is a hybrid: Discovery uses discussion, Planning uses solo (one agent), Execution uses hub-and-spoke, Validation uses solo. The `orchestration: hub-and-spoke` declaration in process.md doesn't capture this. The orchestrator must infer the sub-pattern from the phase definition (`pattern: discussion`), but only the Discovery phase declares this. The behavior is correct in practice (the orchestrator reads process.md and handles each phase appropriately), but the documentation doesn't explain this multi-pattern composition.

**Parallel dispatch is embedded in hub-and-spoke but not available to other patterns.** The Intra-Phase Parallel Dispatch section is written as part of hub-and-spoke. Sequential-agents processes might also need parallel dispatch within a phase — an agent receiving a phase could split its work into parallel subagents. This guidance should be pattern-agnostic.

**No guidance on process-level error budgets.** Individual error handling (agent self-recovers, orchestrator retries, escalate) is well-specified. But there's no concept of "this process has failed too many times across sessions, consider a different approach." The resumability section handles multi-session continuation but not multi-session failure escalation.

## 4. Plugin Coherence

### Structure

```
plugins/pas/
  .claude-plugin/plugin.json     -- Plugin identity
  pas-config.yaml                -- Framework config
  skills/pas/SKILL.md            -- Entry point with routing
  processes/pas/                  -- Self-management process
    process.md
    modes/{supervised,autonomous}.md
    agents/orchestrator/
      agent.md
      skills/{creating-*,applying-feedback}/
  library/                       -- Reusable skills
    orchestration/               -- 4 patterns + decision guide
    self-evaluation/             -- Feedback signal generation
    message-routing/             -- Gate message classification
  hooks/                         -- Lifecycle enforcement
    hooks.json + 5 scripts
```

### Assessment

**The entry point routing is well-designed.** `SKILL.md` routes by intent (creating, hooks, feedback, modifying, running, querying) without exposing PAS internals to the user. The crystal clarity principle and brainstorming mode create good UX defaults.

**The library has the right three skills.** Orchestration (how to run processes), self-evaluation (how to generate feedback), and message-routing (how to handle gates) are the three cross-cutting concerns that every process needs. No bloat.

**One organizational concern: the creating-hooks skill references are heavy.** The `creating-hooks/references/` directory has 4 reference files (event-catalog.md, hooks-schema.md, pas-feedback-hooks.md, script-patterns.md) totaling significant content. The `creating-skills/references/` directory contains the entire `skill-creator` tool (20+ files including Python scripts, HTML viewers, eval tooling) and `superpowers` (another 7+ files). These large reference directories inflate the plugin size significantly. The skill-creator and superpowers content should be evaluated for whether it belongs in the PAS plugin or should be external references.

**Process modes are minimal but sufficient.** `supervised.md` and `autonomous.md` clearly define gate behavior in 10-15 lines each. No over-engineering.

## 5. Technical Debt

### Active Debt (from open issues)

**Issue #6 — Feedback system structural gaps (HIGH).** The umbrella issue. Sub-problems 1-5 have been partially addressed by the hook implementation. Remaining gaps:
- Sub-problem 2 (route-feedback.sh path resolution): partially fixed in deployed code but reference doc is stale
- Sub-problem 6 (creating-processes lost hooks step): still missing — `creating-processes/SKILL.md` goes from step 7 (Create Agents) directly to step 8 (Verify Against Source Material) with no hook determination step
- Sub-problem 7 (generation scripts generate into CWD): the scripts still generate to `$CWD/processes/` with no `--base-dir` protection

**Issue #11 — Orchestrator ignores existing workspace (HIGH).** SessionStart hook now surfaces active workspaces, but the skill chain (particularly `executing-plans` which lives outside PAS) has no PAS lifecycle awareness. This is a boundary problem: PAS hooks inject context, but non-PAS skills don't read it.

**Issue #12 — Self-evaluation skipped 5 consecutive sessions (HIGH).** The hooks should now enforce this, but the issue explicitly says "this tracks whether the hooks actually solve the problem." This is untested — cycle 4 is the first real test of hook enforcement.

### Structural Debt

**Duplicated workspace detection logic across 5 hook scripts.** The `find + stat + sort -rn + head -1` pattern appears identically in all 5 scripts. A shared `pas-find-workspace.sh` utility would reduce maintenance burden and ensure consistent behavior.

**No hook testing infrastructure.** There's no way to test hooks without running a full PAS session. A hook test harness (pipe mock JSON input, check exit code and stdout/stderr) would catch regressions early. The generation script testing issue (#6 sub-problem 7) highlights this — scripts that modify the filesystem need isolated testing.

**The pas-config.yaml feedback toggle is read by scripts but not by orchestration patterns.** The hooks check `feedback: enabled` in pas-config.yaml. But the orchestration patterns say "when feedback is enabled" without specifying how to check. Agents read `pas-config.yaml` because the SessionStart hook tells them to, not because the patterns instruct it.

**Reference/deployed divergence.** The `pas-feedback-hooks.md` reference contains script versions that differ from the deployed scripts. This will cause the `creating-hooks` skill to generate outdated versions when creating new processes.

## 6. Priority Recommendation

### Highest Impact (Structural)

1. **Validate hook enforcement end-to-end.** Issues #11 and #12 are the acid test — do the hooks actually change agent behavior? This cycle should produce a definitive answer. If hooks work, close the issues. If not, the enforcement model needs rethinking (possibly prompt-level hooks or agent-level frontmatter hooks instead of global plugin hooks).

2. **Fix check-self-eval.sh agent-specificity.** The script checks for ANY .md in the feedback directory, not a file matching the stopping agent's ID. This means the first agent to write feedback causes all subsequent agents to pass unchecked. Fix: check for `$FEEDBACK_DIR/${AGENT_ID}.md` or `$FEEDBACK_DIR/*${AGENT_ID}*.md`.

3. **Restore the hooks step in creating-processes.** Issue #6 sub-problem 6. The skill lost step 8.5 (Determine Hooks) during simplification. Without it, new processes are created without hook consideration.

### High Impact (Reliability)

4. **Extract shared workspace detection utility.** Factor the duplicated `find + sort + stat` logic into `plugins/pas/hooks/pas-find-workspace.sh` that all 5 scripts source. Single point of fix when the detection logic needs improvement.

5. **Sync reference docs with deployed code.** The `pas-feedback-hooks.md` reference is stale. Either regenerate it from deployed scripts or establish a convention that deployed scripts ARE the reference (and remove the embedded code from the reference doc).

6. **Add SessionEnd hook for non-graceful exit routing.** Feedback signals are lost if the session ends via clear/logout instead of Stop. A lightweight SessionEnd version of route-feedback.sh would catch these.

### Medium Impact (Completeness)

7. **Document multi-pattern composition.** The pas-development process proves that real processes mix patterns (discussion for Discovery, solo for Planning, hub-and-spoke for Execution). This should be documented as a first-class pattern rather than left as implicit orchestrator behavior.

8. **Add generation script safety (--base-dir).** Issue #6 sub-problem 7. The `pas-create-*` scripts need output location control to prevent the process artifact destruction that happened during v1.2.0 development.

## Summary

The PAS framework has a coherent architecture with well-designed separation of concerns. The plugin structure, orchestration patterns, creation skill chain, and feedback taxonomy are solid foundations. The primary risk area is the hook enforcement layer — it's architecturally correct but unvalidated in production. The three open issues all converge on the same question: does the new hook infrastructure actually change agent behavior? Cycle 4 should answer this definitively. Secondary concerns are code quality (duplicated logic, reference/deployed divergence) and completeness gaps (no SessionEnd hook, missing hooks step in creating-processes, no multi-pattern documentation).
