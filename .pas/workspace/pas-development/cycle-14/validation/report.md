# Cycle 14 Validation Report — Milestone 3 (Hook Safety & Stability)

**Status:** PASS for merge readiness, with one documented residual deferred to cycle 15.
**Validator:** qa-engineer + team-lead (I2 live test).
**Inputs:** 10 commits on `dev` — `a2b6ee7` (C01), `863e6ee` (C02), `74e62be` (C03), `131d400` (C04), `617c819` (C05), `3766ef5` (C06), `b4b3da2` (C07), `7f754bb` (C08), `b6140cd` (C09), `0e1e269` (C05.1).

---

## Hard gates

| # | Gate | Result | Evidence |
|---|---|---|---|
| G1 | `test-hooks.sh` ≥ 90 PASS | **PASS** | 117/117 (target ≥ 90; +27 buffer) |
| G2 | No unguarded `CLAUDE_PLUGIN_ROOT` | **PASS** | All 13 grep matches are intentional (plugin-substitution `${...}/` in hooks.json, defensive default in `lib/guards.sh:11-12`, guarded reads in `route-feedback.sh:87-88`) |
| G3 | No `$CWD/.pas` in hook source | **PASS** | Zero matches; all path construction through `$PAS_PROJECT_ROOT` |
| G4 | Plugin version `1.3.3` | **DEFERRED** to release phase | Still `1.3.2`; community-manager runs `bump-version.sh` |
| G5 | `plugins/pas/hooks/changelog.md` Cycle 14 entry | **DEFERRED** to release phase | File doesn't exist yet; pre-staged at `execution/changes/feedback-analyst/changelog-draft.md` |

## Runnable invariants

| # | Invariant | Result | Evidence |
|---|---|---|---|
| I1 | Worktree write-survival | **PASS** | Worktree fixture run; `verify-completion-gate.sh` from worktree cwd resolved feedback in main `.pas/workspace/.../feedback/` and exited 0 |
| I2 | Subagent text preservation (live Explore spawn) | **PARTIAL — see addendum** | Hook layer fixes work; SessionStart text leak still reaches subagents |
| I3 | PAS agent enforcement preserved | **PASS** | Crafted SubagentStop input with `agent_type: framework-architect`, no feedback file → exited 2 with dx-rewritten block including absolute path |
| I4 | Hook never crashes on missing fields | **PASS** | status.yaml missing both `instance:` and `status:` → `pas-session-start.sh` exit 0, MISSING_FIELDS warning printed |
| I5 | Phase deliverable enforcement | **PASS** | `[PAS] Phase: discovery` task with declared `output_files: [discovery/nonexistent.md]` → `verify-task-completion.sh` exit 2 |
| I6 | Framework signals stay on PAS repo | **PASS** | Audit log records `INFO: Filing OQI-99 on repo ZoranSpirkovski/PAS`; empty `framework_signal_repo` → hard refusal, no `gh issue create` |
| I7 | applying-feedback skill changes | **PASS** | Step 3 mandates AskUserQuestion with the 4 options; Step 13 separates the 3 routes and forbids `gh issue create` from inside the skill |

---

## I2 addendum — dogfooding finding

The team-lead ran the live Explore-subagent test twice (qa-engineer couldn't spawn in team-mode):

- **Run 1 (post-C05, pre-C05.1):** Explore wrote `feedback/ae66c297957f09eac.md` with a `[OQI-01]` self-eval signal instead of returning the requested hook list as text. While doing the analysis it actually discovered the `LAST_MSG_LEN` whitespace bug in `check-self-eval.sh:65` (the `tr -d ' '` only stripping spaces, not the trailing newline from `wc -c`).
- **C05.1 fixup landed** (`0e1e269`) — added a SUBAGENT NOTE carve-out to the SessionStart heredoc and replaced `tr -d ' '` with `tr -d '[:space:]'`. Brought test count to 117.
- **Run 2 (post-C05.1):** Explore *still* wrote `feedback/a7ad01e8aa5a076c7.md` with content "No issues detected." — the SUBAGENT NOTE carve-out did not change behavior.

**Root-cause hypothesis (deferred to cycle 15):** C05's `agent_id` skip in `pas-session-start.sh:21-23` may not trigger because Claude Code's SessionStart payload likely doesn't populate `agent_id` for Agent-tool subagents (the field is documented for SubagentStop / TeammateIdle events, but SessionStart payload structure for subagents was not verified). If `agent_id` is empty in subagent SessionStart events, the full lifecycle heredoc — including the SUBAGENT NOTE — gets injected, and the receiving subagent obeys the "MUST follow this lifecycle" directive over the SUBAGENT NOTE carve-out.

**Why this is a *partial* pass, not a fail:**
1. **Hook-layer fixes are validated:** `check-self-eval.sh` correctly skips non-PAS subagents (`guard_agent_in_active_process` returns false for `Explore` not in active workspace allowlist) → no blocking, no junk feedback file mandated by hook.
2. **The residual is text-injection, not gate-blocking:** the rogue feedback file is benign — `check-self-eval.sh` doesn't block on it, `verify-completion-gate.sh` doesn't enforce it. The subagent writes it because the directive text leaks into its context, but the hook system tolerates the file's existence.
3. **Dogfooding constraint:** every Agent-tool spawn in this very cycle reproduced #38/#67/#68 in our own workspace — but iterating fixes within the cycle that uses them changes the substrate mid-test. A clean fresh-session test in cycle 15 is needed to validate any deeper SessionStart fix.

**Two evidence files preserved as the I2 repro:**
- `cycle-14/feedback/ae66c297957f09eac.md` (pre-C05.1 Explore self-eval)
- `cycle-14/feedback/a7ad01e8aa5a076c7.md` (post-C05.1 Explore self-eval — proves the leak persists)

---

## Per-issue closure attribution

All 18 implementation issues + cycle-13 OQI-02 attributed:

- **#30, #40** → `b6140cd` (C09, applying-feedback Step 3 AskUserQuestion mandate)
- **#41** → `b6140cd` (C09, Step 13 routing-rule + `gh issue create` ban)
- **#38, #67, #68** → `617c819` (C05, agent_type whitelist + SessionStart agent_id skip — *hook layer only; text leak deferred to cycle 15*)
- **#49** → `7f754bb` (C08, `Phase:`-task `output_files` case branch)
- **#52** → `131d400` (C04, `find_active_workspace_status` Pass 0 session-id match)
- **#54, #58** → `863e6ee` (C02, `safe_grep_field` + MISSING_FIELDS accumulator)
- **#55** → `74e62be` (C03, replaced two-line `|| echo 0` integer-comparison bug)
- **#59** → `b4b3da2` (C07, `framework_signal_repo` constant + audit log + hard refusal on empty)
- **#64** → `a2b6ee7` (C01, `CLAUDE_PLUGIN_ROOT` defensive default)
- **#70-F1** → `a2b6ee7` (C01, `resolve_pas_project_root` walk-up + `git show-toplevel` fallback)
- **#70-F2** → `a2b6ee7` (C01, `WORKSPACE_DIR` anchored to `PAS_PROJECT_ROOT`) + `3766ef5` (C06, worktree-safe diagnostics)
- **#70-F4** → `3766ef5` (C06, absolute-path diagnostics + `Resolved PAS_PROJECT_ROOT` line)
- **#70-F7** → `617c819` (C05, bundled with #38/#67/#68 hook scoping)
- **#71** → `617c819` (C05, substantive-response heuristic) + `0e1e269` (C05.1, `LAST_MSG_LEN` whitespace fix)
- **cycle-13 OQI-02** → `617c819` (C05, rolled into agent_type whitelist)

---

## Cross-artifact consistency

- **lifecycle.md vs. verify-task-completion.sh:** prose matches implementation exactly. PASS.
- **applying-feedback Step 13 vs. route-feedback.sh:** Step 13's "filed ONLY on `ZoranSpirkovski/PAS` (enforced by `route-feedback.sh framework_signal_repo`)" matches hook's hard-refusal-on-empty. Contract honored. PASS.
- **Orphan references:** none found that contradict the new contract. PASS.

## Regression check

3 of 60 pre-cycle baseline tests spot-checked:
1. `session-start: no .pas/config.yaml` — graceful skip, PASS
2. `workspace resolution prefers in_progress over completed` — C04 Pass 0 preserves Pass 1 fallback, PASS
3. `session-start: outputs session ID` — SessionStart normal path intact, PASS

All 117 harness tests pass; no regressions.

## Convention compliance

- All modified hooks retain `#!/usr/bin/env bash` + `set -euo pipefail`
- New helpers (`resolve_pas_project_root`, `safe_grep_field`, `guard_agent_in_active_process`) follow `guards.sh` convention
- `applying-feedback/SKILL.md` frontmatter unchanged; description starts with "Use when"
- `applying-feedback/changelog.md` updated for C09
- `pas-config.yaml` field `framework_signal_repo: ZoranSpirkovski/PAS` at canonical key

---

## Release-phase actions (community-manager)

1. Run `bash plugins/pas/hooks/lib/bump-version.sh` (1.3.2 → 1.3.3) — closes G4.
2. Create `plugins/pas/hooks/changelog.md` from pre-staged `execution/changes/feedback-analyst/changelog-draft.md` — closes G5.
3. File 6 sub-issues against #70 (per discovery/priorities.md §5).
4. File 4 dogfood signals from `execution/changes/feedback-analyst/dogfood-signals.md`.
5. **NEW:** file the SessionStart-text-leak residual as a fresh issue for cycle 15 (root-cause hypothesis above).
6. Cherry-pick plugin-only commits onto a feature branch off `main`; verify diff is plugin-only; open PR to `main`.
7. Post-merge: merge `main` back into `dev` (pr-management Step 6).
8. Close all closed-by-merge issues with PR-link comments.

## Conclusion

Cycle 14 is **validation-PASS for merge readiness**. M3 closes 18 issues at the hook layer. The I2 SessionStart-text-leak residual is documented, evidenced (two preserved feedback files), and routed to cycle 15 as a known follow-on. Recommend release.
