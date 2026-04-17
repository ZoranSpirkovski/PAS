# Cycle 14 Discovery — Priorities

**Cycle directive (product owner):**
> "Implement all open GitHub issues into the framework, sequenced by milestone. Cycle 14 = Milestone 3 (Hook Safety & Stability)."

**Discovery pattern:** discussion (5 specialists). All 5 perspective docs land in `discovery/{agent}-perspective.md`.

---

## 1. Consensus

All 5 perspectives agree:

1. **M3 scope = 11 hook fixes + 2 umbrella closures, plus the additions below.**
2. **Close-on-merge:** #31, #33, #56, #57, #61, #66 — pure dups/umbrellas, ~14 % queue reduction with zero implementation.
3. **Downgrade #62** to M6 (it's a small `self-evaluation/SKILL.md` doc tweak, not a P0).
4. **Split #70** into 6 sub-issues before any code lands. A 10-finding RFC is unreviewable as one PR.
5. **Defer #70 findings 5, 8, 9, 10** to later milestones (5 → M5 generator work; 8 needs config schema; 9/10 → M7 architectural).
6. **`agent_type` (or `agent_id`) in the hook payload is the right scoping mechanism** for #38/#67/#68/#71. Stay with bash for M3 hooks; defer agent-based hooks to M7.
7. **Use `git rev-parse --show-toplevel`** (not `--git-common-dir`) as the worktree-aware `PAS_PROJECT_ROOT` resolver, with `.pas/config.yaml` walk-up taking precedence.
8. **M4 lifecycle skills can be *designed* in parallel** with M3 execution but their *implementation* must land after M3 merges. **M5 generator work is sequential after M3.**
9. **Defer the full DX audit to M6.** Audit needs post-fix state (M3 + M4 + M5 shipped) to be useful. Lock the checklist in now (see §5).

---

## 2. Hoists & additions to M3

Net-new to M3 vs. the pre-triage plan, with rationale:

### ADD: #49 — "no checkpoint enforces phase output_files before advancing" (P0, S effort)
- Direct, live evidence: **this very cycle** dispatched execution-phase work (community-manager's PR scaffolding) before discovery and planning produced anything. The bug isn't theoretical — it's actively biting the cycle that's supposed to fix the framework.
- Same hook-stability family as the rest of M3. One-file change in `verify-task-completion.sh` (or sibling). Cheap.
- Source: community-manager + feedback-analyst both flagged.

### HOIST: #30, #40, #41 — `applying-feedback` skill UX edits (P1→P0 in M3, S effort each)
- Two-line skill edits. Bundle into the same `library/` PR as the M3 hook fixes.
- **#41 specifically** is a trust-breaking accident — the agent has filed bogus issues on user *product* repos. That belongs with #59 (framework signals → wrong repo), not deferred to M6.
- DX-specialist's call. Feedback-analyst notes the same routing-overlap with #59.

### NEW (file this cycle): codified gate for fabricated metrics
- Cycle-8 had **5 HIGH OQIs** (one per agent) about `community-manager` fabricating "104 cloners". Currently enforced *only* by a `MEMORY.md` rule. There is no codified guard.
- Feedback-analyst recommends filing as a new GitHub issue this cycle, then slotting into **M4** (lifecycle governance, discussion-pattern fix). Out of scope for cycle 14 *implementation*, but should be filed in the release phase to capture the signal.

### MAYBE (product-owner call needed): cycle-13 OQI-02 (self-eval before idle shutdown)
- Same hook-timing family as #71 / #38 / #67 / #68. Either:
  - (a) roll into the #38/#67/#68 fix this cycle, or
  - (b) file as new GH issue and slot to M4.
- Feedback-analyst flagged. No other perspective weighed in. **Open question for the gate.**

---

## 3. Disagreements & resolutions

| Issue | Disagreement | Resolution |
|---|---|---|
| **#71** scope | feedback-analyst: defer if M3 needs scope cut. framework-architect: bundle with #38/#67/#68 (same root cause). dx-specialist: 9.0 DX score, must keep. | **Keep in M3.** Same fix as #38/#67/#68 — `agent_type` payload scoping makes #71 disappear for non-PAS agents at zero extra cost. |
| **#70 split**: how many findings ship in cycle 14? | community-manager: 6 sub-issues. framework-architect: ship 1, 2, 4, 6, 7 (defer 3, 5, 8, 9, 10). feedback-analyst: defer 5, 6, 9. | **Ship findings 1, 2, 4, 7** (PAS_PROJECT_ROOT, silent-disable, deadlock+diagnostic, SubagentStop scoping). **Defer finding 6** (self-eval skill rewrite) to M5 alongside the generator — aligns with feedback-analyst's call that skill-rewrites belong with generator work, not hook work. **Defer finding 3** to a follow-up (overlaps with #52 — solve session-id-first resolution in cycle 14, hold atomic-write hardening). |
| Whether #50 / #59 share a fix | community-manager: possibly one message-routing pass. dx-specialist: not flagged. | **Defer the consolidation question to planning.** If framework-architect can land #59 cheaply, leave #50 in M6 as planned. |

---

## 4. Final M3 scope (cycle 14 PR)

**Bug-fix issues (12 actionable):**
- #38, #52, #54, #55, #58, #59, #64, #67, #68, #70 (subset), #71, **#49 (added)**

**Skill-edit issues (3 actionable, hoisted from M6):**
- #30, #40, #41

**Close-on-merge with zero implementation (6):**
- #31, #33 (dups of #32), #61 (dup of #62), #66 (dup of #65), #56, #57 (umbrellas resolved by #54/#55/#64)

**#70 sub-issues to file (6, then M3 ships 4):**
- **Ship in cycle 14:** #70.1 `PAS_PROJECT_ROOT`, #70.2 completion-gate deadlock + diagnostics, #70.4 `check-self-eval` scoping (overlaps #67/#68), #70.7 — wait, framework-architect numbers them differently from community-manager. **Resolution: community-manager files the sub-issues; framework-architect plans against the new numbers in planning phase.**
- **Defer:** #70.3 (atomic status.yaml — pairs with #52 follow-up), #70.5 (generator → M5), #70.6 (skill rewrite → M5), #70.8 (skip-pas escape hatch — needs schema), #70.9 (sidecar visibility → M7), #70.10 (subagent cwd guidance → M7).

**Total cycle 14 actions:** 15 implementation issues + 6 admin closures + 6 sub-issues filed = **27 GitHub-issue actions**.

---

## 5. Recommended commit ordering (input to planning phase)

From framework-architect, slightly reordered to match the dependency graph:

1. **#64 + `lib/guards.sh` defensive defaults** — `CLAUDE_PLUGIN_ROOT` guard, `set -u` safety. Foundation; nothing else lands without this.
2. **#54 + #58 bundle** — same lines, opposing failure modes (crash vs. silent degradation). Includes dx-specialist's error-message rewrite.
3. **#55** — `check-self-eval.sh` `grep -c` integer-comparison fix. Independent.
4. **#70.1 `PAS_PROJECT_ROOT` resolution** in `lib/guards.sh` (per ecosystem-analyst's algorithm). Foundation for everything that touches paths.
5. **#52 + #70 finding 3 (partial)** — session-id-first workspace resolution.
6. **#38 / #67 / #68 / #71 + #70 finding 7 bundle** — `agent_type` scoping + `SessionStart` injection guard for subagent contexts. Highest blast radius; most tests required.
7. **#70 finding 4** — completion-gate deadlock + absolute-path diagnostic.
8. **#59** — `framework_signal_repo` constant + audit log.
9. **#49** — `output_files` checkpoint in `verify-task-completion.sh` (or new `verify-phase-deliverables.sh`).
10. **#30 / #40 / #41 skill edits** — `applying-feedback/SKILL.md`. Independent commit, shipped in same PR.
11. **Close-on-merge admin** — release phase only.

**Test harness target:** ≥75 tests (up from 60). Critical new fixtures: worktree-cwd setup, agent-type scoping (PAS-blocked vs. non-PAS-passthrough), output-file deliverable presence.

---

## 6. M6 DX audit checklist (lock-in for future cycle)

Per dx-specialist, capture now so M6 inherits a concrete plan:

- Frontmatter clarity: every `SKILL.md` description readable cold by a first-time user.
- Hook error messages: every `set -euo pipefail` failure path emits a user-facing message with recovery actions (use the §2 templates from `dx-specialist-perspective.md` as baseline).
- `lifecycle.md` prose accuracy: matches what hooks actually enforce post-M3.
- Generator scaffolds: `creating-processes` / `pas-create-skill` / `pas-create-process` produce artifacts that pass their own validation hooks on first run.
- Onboarding path: README → first `/pas-development` run → first feedback signal applied — measure friction at each step.
- Naming audit: `framework:pas` vs `process:` vs `agent:` vs `skill:` target syntax — intuitive without docs?

---

## 7. Source-session attribution (planning context)

Many M3 issues come from the same downstream consumer session. Implementing them together preserves the consumer's session-feedback intent:

- **agency-delivery / Tangled-Roots-V1 sessions:** #67, #70, #71, #72 — most of the worktree + subagent-derail signals.
- **feature-dev / stripe-payments (1ce8c296):** #49, #50, #51, #53 — the M4 lifecycle bundle.
- **Visualife (b680fff6, afb73e3a):** #30, #40, #41, #42, #43 — UX skill edits (3 of which we're hoisting into M3).

This is the basis for community-manager's per-issue `closes #N` PR body in the release phase.

---

## 8. Open questions for the product owner gate

1. **#70 sub-issue split:** approve community-manager filing 6 sub-issues against the original #70 in this cycle's release phase? (If no, we attempt the whole thing as one PR — not recommended.)
2. **Cycle-13 dx-specialist OQI-02** (self-eval before idle shutdown): roll into the #38/#67/#68 fix this cycle, or file as new issue and slot to M4?
3. **M3 PR scope confirmation:** 15 implementation issues + 3 skill edits is a meaty PR. Comfortable with that, or split skill-edits into a follow-on cycle 14b PR?
4. **Hoist of #30/#40/#41 from M6 to M3:** approve, or keep in M6?
5. **Was the cycle-14 OQI from community-manager (executing release work in discovery phase) significant enough to file as a new framework signal** in addition to fixing via #49?

---

## 9. Cycle 14 framework-signal candidates (route at shutdown)

From cycle-14's own dogfooding so far:

- **TaskUpdate ownership-change auto-broadcasts task assignments to teammates**, even for [PAS]-prefixed orchestrator-only tasks. Caused community-manager to attempt task #3 (Phase: execution) immediately after spawn. Recommend: orchestrator-only tasks should suppress assignment broadcasts, OR teammate spawn prompts should explicitly say "ignore [PAS] prefix tasks unless DM'd."
- **Agents auto-claim broadcast `task_assignment` over plain-text SendMessage dispatch.** community-manager started PR scaffolding instead of discovery despite a SendMessage having arrived first. Lifecycle.md should specify channel precedence, or the team-task-list mechanism needs guard rails for orchestrator-only tasks.
- **No phase-order enforcement.** Agent shipped execution-phase work before discovery completed. Direct evidence for #49.
- **Subagent self-eval filename mismatch.** lifecycle.md says agent feedback files are `{agent}.md`, but spawned agents wrote `{agent}-{session_id}.md`. The `{session_id}` suffix is for the *orchestrator's* file. Worth checking if `check-self-eval.sh` accepts both forms or if the contract is genuinely ambiguous.
