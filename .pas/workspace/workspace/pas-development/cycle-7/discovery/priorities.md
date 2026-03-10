# Cycle 7 Discovery Priorities

## Cycle Type
Signal-driven housekeeping + owner directive (merge reconciliation)

## Signal Sources
- `processes/pas-development/feedback/backlog/2026-03-08-orchestrator-OQI-01.md` (release workflow bug)
- `processes/pas-development/feedback/backlog/2026-03-08-owner-OQI-01.md` (plan mode bypass)
- Codebase exploration (library mirror drift, CLAUDE.md staleness, deleted file)
- Cycle-6 validation report (convention violations)

## Completed (mid-discovery)

### P0: Merge main into dev — reconcile branch history
- **Owner directive:** "cherry pick merge main once and for all"
- **Done:** `git merge origin/main --no-ff` — clean merge, zero file changes, dev-only dirs safe
- **Commit:** Merge main into dev: reconcile branch history after PR #18

### P4 → DONE: Restore deleted orchestrator.md
- **Done:** `git checkout HEAD~1 -- workspace/pas-development/cycle-6/feedback/orchestrator.md`

## Remaining Priorities

### P1 (HIGH): Fix release phase description in process.md
- **Signal:** process.md line 61 says `git checkout dev -- plugins/pas/...` — contradicts the already-corrected pr-management skill (cherry-pick workflow)
- **Impact:** Data-loss vector. Caused actual loss in cycle-6. Orchestrator reads process.md as authoritative.
- **Fix:** Replace implementation details with high-level description. Let pr-management skill own the procedure.
- **File:** `processes/pas-development/process.md` (line 61)

### P2 (MEDIUM-HIGH): Sync library mirrors + create sync script
- **Signal:** 3 of 4 library skills on dev are out of sync with `plugins/pas/library/`
  - `library/message-routing/` — entirely missing
  - `library/orchestration/` — missing SKILL.md, feedback/backlog/.gitkeep
  - `library/self-evaluation/` — missing changelog.md, feedback/backlog/.gitkeep
  - `library/visualize-process/` — fully synced
- **Impact:** Silent correctness problem. Agents reading from `library/` get stale or missing content.
- **Fix:** Copy missing files from plugin source + create `sync-library.sh` script to prevent future drift
- **Files:** `library/` directory, new `scripts/sync-library.sh`

### P3 (MEDIUM): Fix CLAUDE.md stale information + add routing note
- **Signal:** Line 15 says "7 agents, 4 phases" (should be 5). No mention that PAS plugin changes should route through /pas-development.
- **Impact:** Wrong mental model from first read. Dogfooding gap.
- **Fix:** Update phase count. Add note about /pas-development routing for PAS evolution work. "Inform, don't redirect" approach.
- **File:** `.claude/CLAUDE.md`, `.claude/skills/pas-development/SKILL.md`
- **Deferred:** Hook-based enforcement (PreToolUse guard) goes to backlog for a future cycle

### P4 (MEDIUM): Add post-merge safety to release process
- **Owner directive:** Prevent future merge-deletions of dev-only dirs
- **Impact:** This class of bug has happened TWICE — processes/pas-development/ deleted during merges
- **Fix:** Update pr-management skill to include safe merge-back step after PR merge. Add verification that dev-only dirs survive.
- **File:** `processes/pas-development/agents/community-manager/skills/pr-management/SKILL.md`

## Resolved Signals (from previous cycles)
- OQI-02 (claim verification): RESOLVED — STA-02 confirms fix is practiced
- OQI-01 (workspace lifecycle): RESOLVED — cycle-5 implemented enforcement
- OQI-03 (workspace lifecycle): RESOLVED — same fix

## Discussion Notes
- All 5 agents contributed. No conflicts between assessments.
- Key debate: Signal 2 (plan mode bypass) — ecosystem-analyst proposed PreToolUse hook enforcement. Consensus: good idea but out of scope for housekeeping cycle. Text nudge now, hook enforcement later.
- Framework Architect identified root pattern: documentation drift across duplicated information. Sync script addresses the structural case (library mirrors). Others are one-time text fixes.
- Community Manager confirmed: no open GitHub issues, no new issues needed. All signals are dev-only housekeeping.
- No PR to main needed this cycle — all changes are dev-only artifacts.

## Backlog Items (for future cycles)
- PreToolUse hook to guard `plugins/pas/` from direct edits outside /pas-development
- PostToolUse hook to auto-sync library mirrors when plugin source changes
- Worktree-based release phase to eliminate branch-switching class of bugs entirely
