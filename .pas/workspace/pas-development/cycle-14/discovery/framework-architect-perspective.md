# Framework Architect — Cycle 14 Discovery Perspective

Lens: technical/architectural feasibility and dependency ordering for Milestone 3 (Hook Safety & Stability), confirmed by reading the actual hook source under `plugins/pas/hooks/`.

## 1. Per-P0 issue technical briefs

### #64 — `pas-session-start.sh` `CLAUDE_PLUGIN_ROOT: unbound variable`
- **Root cause confirmed.** Script runs `set -euo pipefail`. Cached 1.3.2 builds had `${CLAUDE_PLUGIN_ROOT}` inside the heredoc; Claude Code substitutes it in `hooks.json` `command` paths but does not always export it to the child process. Current marketplace copy at `pas-session-start.sh:1-107` happens not to dereference it inside the body, but every other script that does so would crash the same way.
- **Fix shape.** Add a defensive default at the top of every hook: `CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"`. Centralize in `lib/guards.sh` so the four hook scripts pick it up via the `source` they already do.
- **Blast radius.** Trivial — purely defensive default. Cannot regress: only runs when var is unset.
- **Depends on.** None. Safe pre-req for everything else and the cleanest first commit.

### #54 — SessionStart crashes on missing `instance` field
- **Root cause confirmed.** `pas-session-start.sh:93-95` chains `grep | head | awk`. With `pipefail`, a missing `instance:` line makes `grep` exit 1 and aborts the script. Same risk for `status:` and `process:`.
- **Fix shape.** Append `|| true` to each of the three pipelines (or wrap in a `safe_grep_field` helper in `lib/guards.sh`). Pair with #58's "warn loudly with reasonable defaults" so the silent-but-broken display is fixed in the same commit.
- **Blast radius.** Tiny. Only path affected is the display block at `pas-session-start.sh:91-104`.
- **Depends on.** Should land bundled with #58 (same lines, opposing failure modes).

### #55 — `check-self-eval.sh` `grep -c` integer-comparison failure
- **Root cause confirmed.** `check-self-eval.sh:38`: `grep -c ... || echo 0`. When `grep -c` finds zero, it writes `0` to stdout AND exits 1; the `|| echo 0` then writes another `0`, so the captured value is `"0\n0"`. Line 39's `[ "$SIGNAL_COUNT" -gt 0 ]` then crashes under `set -e`.
- **Fix shape.** Issue's suggestion is correct: `SIGNAL_COUNT=$(grep -cE '...' "$AGENT_TRANSCRIPT" 2>/dev/null) || SIGNAL_COUNT=0`. Verify with a test that explicitly hits the zero-match path on a transcript file.
- **Blast radius.** Localized. Only changes the secondary detection path; the primary file-existence check at lines 24-34 is unchanged.
- **Depends on.** None. Independent commit.

### #38 / #67 / #68 / #71 — Hooks derail subagents
This is the most consequential P0 bundle. Four issues, one root cause: hooks treat *any* SubagentStop in a PAS project as if the subagent were a PAS-process agent.

- **Root cause confirmed.** `check-self-eval.sh:16-21` only gates on `guard_feedback_enabled` + `guard_active_workspace`. There is **no** check that the stopping agent is part of the active process's `agents/` set. Result: any Explore/general-purpose subagent spawned in a PAS project gets blocked, writes a junk feedback file into the wrong workspace (#67), and worse — its substantive plain-text response gets elided when the SubagentStop hook injects "SELF-EVALUATION MISSING" stderr into the parent's view (#71). Combined with the `SessionStart` heredoc text ("MUST follow this lifecycle / hooks will block you", `pas-session-start.sh:67-87`), subagents conclude they should write a feedback file instead of doing their task (#38, #68).
- **Fix shape.** Two-pronged:
  1. **Scope `SessionStart` injection to non-subagent contexts.** Claude Code 2.1.69 added `agent_id` in hook events (per project memory). If `agent_id` is non-empty in SessionStart input → the session is a subagent → emit minimal/no PAS context. Same guard for SubagentStop: only enforce when the agent name matches one defined in the active process's `agents/` directory.
  2. **Whitelist gate in `check-self-eval.sh`.** Add a `guard_agent_in_active_process` helper: read `process.md`'s phase agent assignments (already grep'd in `verify-completion-gate.sh:66`), exit 0 if `$AGENT_ID` is not in the list. Independently, soften the SubagentStop blocking message so a re-run does not elide substantive text (#71's heuristic: if substantive text was emitted, do not block — only block when both feedback file is missing AND last response is short/summary-only).
- **Blast radius.** Higher than the bash bugs. Touches the gate that protects the feedback contract. We must add tests for both the "PAS agent blocked correctly" and "non-PAS subagent passes through" paths to avoid weakening real enforcement.
- **Depends on.** #54/#55/#64 should land first so we are not stacking fixes on broken scripts. Independent of #70 worktree work.

### #52 — `verify-task-completion` checks wrong workspace
- **Root cause confirmed.** `guard_active_workspace` (in `lib/guards.sh:78-90` → `lib/workspace.sh`) returns "newest mtime" status.yaml. With sibling instances under one process, an unrelated stale `in_progress` workspace can outrank the one the current session is operating on. Same bug affects `verify-completion-gate.sh` and `route-feedback.sh`.
- **Fix shape.** Resolve workspace by *current session id* first, fall back to mtime. Read `current_session:` field across all status.yaml files; pick the one matching `$SESSION_ID` from hook input. If no match, fall back to the existing mtime heuristic with a warning. This is also half the answer to #70 finding 3.
- **Blast radius.** Medium. `find_active_workspace_status` is shared by three hooks. Behavior change in workspace selection, but only when multiple workspaces exist — single-workspace projects are unaffected.
- **Depends on.** Best landed alongside #70 finding 3 (race protection on shared `status.yaml`). They are the same conceptual fix viewed from two angles.

### #58 — Warn instead of silently degrading on malformed `status.yaml`
- **Root cause confirmed.** Issue's suggested implementation is sound. After #54 fix, fields are tolerated as empty; this issue says "tolerate but say so."
- **Fix shape.** Bundle directly into #54 commit. Add a `MISSING_FIELDS` accumulator in `pas-session-start.sh:91-104`; print a `⚠ status.yaml missing required fields:` line; default `INSTANCE` to `basename "$ACTIVE_WORKSPACE"`, `TOP_STATUS` to `unknown`.
- **Blast radius.** Display-only. Cannot break gate logic; the gate already treats unset = not-completed.
- **Depends on.** Tied to #54.

### #59 — Framework signals must not file on product repos
- **Root cause confirmed.** `route-feedback.sh:99-101`: `gh issue create --repo ZoranSpirkovski/PAS …` already hard-codes the PAS repo, so the *current* code is correct. The bug surfaced when an older variant (or a route that didn't go through `route_framework_signal`) filed onto the running repo. Defensive hardening still needed: the script must refuse to file *unless* it can verify the target repo is `ZoranSpirkovski/PAS`.
- **Fix shape.** Two safeguards:
  1. Make `--repo ZoranSpirkovski/PAS` an enforced constant pulled from `pas-config.yaml` (`framework_signal_repo: ZoranSpirkovski/PAS`); fall back to env var if config missing; refuse to file if neither resolves.
  2. Add a positive check: log the repo name into `framework-routing.log` before the `gh issue create` call so any future routing-to-wrong-repo regression is auditable.
- **Blast radius.** Tiny. Only touches the framework signal path; product-process feedback routing unaffected.
- **Depends on.** None.

### #70 — Worktree contract (RFC, 10 findings) — see Section 2 below

## 2. Issue #70 — split, not tackle whole

**Recommendation: split into sub-issues. Ship a tight subset (findings 1, 2, 4, 6, 7) in cycle 14. Defer findings 3, 5, 8, 9, 10 to cycle 14b or later milestones.**

Justification:

- Findings **1 (PAS_PROJECT_ROOT), 2 (silent-disable from worktrees), 4 (deadlock + opaque diagnostic), 6 (self-eval skill carries cwd-relative contract), 7 (SubagentStop taxes unrelated subagents — this is also #67/#68)** are P0 bug-shaped. They have concrete fixes, fit in a single PR with the rest of M3, and are pre-conditions for the bash bug fixes to actually take effect inside worktrees. Bundling them is correct because they all flow from the same change: introduce `PAS_PROJECT_ROOT` resolution and use it everywhere paths are built.
- Finding **3 (status.yaml races)** overlaps with #52. Solve via "session-id-first workspace resolution" in cycle 14, defer atomic-write hardening to a follow-up.
- Findings **5 (generator emits cwd-relative paths) and 8 (no skip-pas escape hatch)** are scope-extending: 5 belongs in M5 (Generator Correctness) where we are already touching the create scripts; 8 needs a config schema decision (`skip_pas_auto_pin`) that wants its own design discussion.
- Findings **9 (gitignored sidecar state) and 10 (subagent cwd guidance for downstream worktree processes)** are documentation/policy questions that do not block hook stability. Defer to M7 (Architectural Expansion) or close as won't-fix-in-framework.

A 10-finding PR would also blow PR scope discipline. Splitting lets us close finding-by-finding and ship a focused, reviewable cycle 14 PR.

## 3. Inter-milestone dependency analysis

- **M4 lifecycle skills (`/startup`, `/shutdown` from #51) — can be designed in parallel, MUST integrate after M3.** The skill *content* (workspace creation, status.yaml init, deliverable verification, signal routing call-out) is independent of the hook bugs and can be drafted in parallel. But the skills have to *call into* hook-verified contracts (`current_session` write, `feedback/{agent}-{session}.md` filename), so their final wiring depends on M3's `PAS_PROJECT_ROOT` and session-aware workspace resolution. Verdict: M4 design starts immediately, M4 implementation lands after M3 PR merges.
- **M5 generator fixes — sequential after M3.** The generator emits artifacts that reference paths and the self-eval skill. Once M3 changes the self-eval contract to use `PAS_PROJECT_ROOT`, the generator (`pas-create-process`, `pas-create-agent`, `pas-create-skill`) needs to emit the new contract. Doing M5 before M3 means re-doing it.
- **M6 feedback UX and M7 architectural RFCs — fully independent of M3.** Can be sequenced freely.

## 4. Risk register

- **Regression risk: weakening `check-self-eval.sh` enforcement.** The whitelist approach (only block PAS-process agents) could cause real PAS agents to slip past if the agent_id detection is wrong. Mitigation: explicit test cases for (a) PAS-process agent without feedback → blocked, (b) non-PAS subagent without feedback → passed through, (c) PAS-process agent with feedback file → passed through, (d) malformed agent_id → fall back to existing behavior.
- **Regression risk: workspace resolution change breaks single-workspace projects.** Mitigation: add a test that a project with one in-progress workspace and no `current_session` field still resolves correctly (back-compat with PAS 1.x layouts).
- **Regression risk: `PAS_PROJECT_ROOT` discovery walks too far up.** If we use `git rev-parse --git-common-dir`, a session run inside a sub-repo could resolve to the parent repo's `.pas/`. Mitigation: prefer "walk up from cwd until `.pas/config.yaml` found", git-aware lookup as fallback only.
- **Test coverage gap: harness has no worktree scenario.** The current `tests/test-hooks.sh` (771 lines, ~60 tests per project memory) does not exercise worktree cwd. Adding a worktree-creation fixture is non-trivial in shell tests but necessary to lock #70 fixes. Suggest a `tests/fixtures/worktree-setup.sh` helper.
- **Test coverage gap: no assertion that SessionStart context is *omitted* in subagent calls.** Without this, #38/#68 fixes can silently regress. Add a test that pipes a JSON input with non-empty `agent_id` and asserts no "PAS Framework Active" text.
- **Coordination risk: #59's repo-pinning fix vs. orchestrator's `gh issue create` calls outside hooks.** The orchestrator can also file issues directly (e.g., during the "Route framework signals" task) — that path is governed by `applying-feedback` skill, not `route-feedback.sh`. The hook fix protects against silent mis-routing, but the orchestrator's manual issue-filing path also needs the same `framework_signal_repo` constant or `--repo` enforcement. Out of scope for cycle 14 hook work, but should be flagged in the cycle 15 lifecycle skills.

---

Files referenced exist and were read: `plugins/pas/hooks/{pas-session-start.sh, check-self-eval.sh, verify-task-completion.sh, verify-completion-gate.sh, route-feedback.sh, hooks.json}`, `plugins/pas/hooks/lib/{guards.sh, workspace.sh}`, `plugins/pas/library/self-evaluation/SKILL.md`. Issue contents read via `gh issue view` for #70, #38, #67, #68, #71, #54, #55, #64, #52, #59, #58, #51, #32.
