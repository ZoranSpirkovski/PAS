# Self-Evaluation — community-manager (cycle-15, session 99f211ea)

[OQI-01]
Target: skill:pr-management
Degraded: PR #145 scope violates the documented PR-scope contract — it contains 100 files including `.pas/workspace/`, `.pas/library/`, `.pas/feedback/` paths that CLAUDE.md and `skills/pr-management/SKILL.md` Step 3 explicitly state must never appear in a PR diff.
Root Cause: Either (a) cycle-15 executed a deliberate deviation from the single-PR-per-cycle + plugin-only-diff contract without updating the skill, or (b) the pr-management skill's "every file MUST be under `plugins/pas/` or `.claude-plugin/`" guard was not enforced during PR creation. My discovery-phase perspective explicitly flagged this risk and proposed a 3-PR staging plan; the cycle shipped a single PR anyway.
Fix: Either update `plugins/pas/processes/pas/agents/orchestrator/skills/pr-management/SKILL.md` Step 3 to allow dev-artifact inclusion for architectural-shift cycles (with explicit gating criteria), or hard-enforce the plugin-only-diff rule via a pre-PR check script. The current state — a documented rule that is silently overridden — is the worst of both options.
Evidence: `gh pr view 145 --json files` returns 100 files; first non-plugin files include `.claude/CLAUDE.md`, `.pas/config.yaml`, `.pas/feedback/framework-routing.log`, `.pas/library/**`, `.pas/workspace/pas-development/cycle-4..cycle-14/**`. PR title: "Cycle 15 / M4: Marketplace-authoritative architecture". The pr-management SKILL.md Common Mistakes section lists "Including workspace or process files in the PR" as a known failure mode.
Priority: HIGH

[OQI-02]
Target: agent:community-manager
Degraded: I received out-of-phase task-list notifications during Round 1 (task #2 "Planning phase — framework-architect (solo) turns priorities.md into planning/implementation-plan.md" and task #7 "Route framework signals") while I was waiting for the discussion prompt. I correctly declined both, but this is the same symptom described in open issues #105, #106, #115.
Root Cause: `task-list` teammate broadcasts task_assignment notifications to all agents regardless of owner/role. The task-list system does not filter by agent role before delivering.
Fix: Filter task_assignment broadcasts by `owner` field before delivery, or require explicit `to:` routing. Consolidate #105, #106, #115 into a single actionable issue; they are three symptoms of one bug.
Evidence: Two distinct task-list messages delivered to me in this session before the round-1 prompt. Task #2 was a framework-architect planning task; task #7 was a post-shutdown orchestrator routing task. Neither is community-manager work.
Priority: MEDIUM

[OQI-03]
Target: skill:issue-triage
Degraded: The skill's process step 1 says `--limit 50`, but the repo has 76 open issues. A default invocation would silently skip the oldest 26 issues (#29-#51 range — exactly the issues most likely to be stale or already-shipped).
Root Cause: Hardcoded limit does not scale with the backlog.
Fix: Either paginate with `--paginate` (gh supports it) or raise the limit to a value above current backlog (e.g., 200) in `skills/issue-triage/SKILL.md` step 1. The higher number is cheap and forward-compatible.
Evidence: `gh issue list --state open --limit 200 --json number --jq '. | length'` → 76. SKILL.md line 19 hardcodes `--limit 50`.
Priority: MEDIUM

[STA-01]
Target: skill:issue-triage
Strength: OBSERVED
Behavior: Grouping triage into A (resolved-by-change), B (residuals), C (spam/hygiene), D (orthogonal features), E (deferred) gave the discussion a workable frame instead of 76 isolated tickets. The discussion skill's synthesis explicitly picked up several of these groupings.
Context: Large architectural-shift cycles will keep producing this class of multi-dozen-issue triage. Preserving the group-based structure over a flat "priority-ordered list" keeps the output useful to downstream phases.

[PPU-01]
Target: process:pas-development
Frequency: Stated once in my perspective (under "PR scoping recommendation"), explicitly validated by the cycle completing with a single 100-file PR that violates the documented constraint.
Evidence: My perspective file, section "PR scoping recommendation", argued explicitly for staged PRs citing cycle-14's dogfooding hazard (#113). The cycle shipped single-PR anyway. Either my recommendation was rejected on merit (in which case the rationale should land in the cycle-15 changelog), or the constraint was forgotten mid-execution (in which case the skill needs a hard guard). Owner-preference clarification needed: under what cycle types is single-PR acceptable even when it violates the plugin-only-diff rule?
Priority: MEDIUM
Preference: Before future large architectural cycles, make the PR-scoping decision explicit at the end of Planning (document: "This cycle will ship as N PRs. Rationale: ..."). Do not let PR scope be decided at Release time by default.

---

Route: none (all signals are process/agent/skill-local; no framework:pas targets identified in this session).
