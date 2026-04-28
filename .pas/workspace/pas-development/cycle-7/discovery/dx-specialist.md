# DX Assessment — Cycle 7

## Priority Ranking (by DX impact)

### 1. CLAUDE.md says "4 phases" (Signal 5) — HIGH

This is the single highest-impact DX issue. Here is why:

CLAUDE.md is the **first file every agent reads**, every session, before doing anything. It is the ground truth document. When it says "7 agents, 4 phases" but the process actually has 5 phases, every agent starts the session with a wrong mental model.

The damage is not just "stale text." An agent that reads "4 phases" and then encounters a Release phase will either (a) skip it because it was not mentioned, (b) be confused about whether it is legitimate, or (c) waste tokens reconciling conflicting information. This is exactly the kind of bug that is trivial to fix but compounds silently across every session.

**Fix:** Change "4 phases" to "5 phases" in `.claude/CLAUDE.md` line 15. One word change, immediate payoff.

### 2. Library mirror drift (Signal 3) — HIGH

The `library/` directory is the **read path** for every agent running under the pas-development process. The skill launcher at `.claude/skills/pas-development/SKILL.md` says: "Read the orchestration pattern from `library/orchestration/`." Agents follow this instruction. When `library/` is stale, agents execute with outdated behavior.

The drift is significant:
- `library/orchestration/` is missing `SKILL.md` entirely (the entry point for the orchestration skill)
- `library/orchestration/discussion.md` and `hub-and-spoke.md` both differ from plugin source
- `library/` is missing the `message-routing/` skill entirely
- `library/self-evaluation/` is missing `changelog.md` and `feedback/`

This means any agent reading orchestration patterns from `library/` is getting stale versions. The orchestrator itself may be working from outdated instructions.

**DX question the orchestrator raised: Should `library/` be the canonical read path, or should agents read from `plugins/pas/library/` directly?**

My assessment: `library/` should remain the read path, but the sync must be automated. Reasons:
- `library/` is the user-facing convention. In any PAS project, the user's `library/` is their canonical copy. The pas-development process should eat its own dogfood and use the same path.
- Reading from `plugins/pas/library/` would create a special case where the development process reads from a different location than every other process. That is a DX anti-pattern — it means the team operates differently from users.
- The real fix is making the sync step impossible to forget. Add it to the pr-management skill's release checklist or (better) to a post-release housekeeping step.

**Fix:** Sync `library/` from `plugins/pas/library/` now. Add a sync step to the release process so this cannot recur.

### 3. Release phase branch switching contradiction (Signal 1) — MEDIUM

Two authoritative documents disagree on how the Release phase works:

- `process.md` line 61: "cherry-picks only `plugins/pas/` files from dev (`git checkout dev -- plugins/pas/...`)"
- `pr-management/SKILL.md` step 2: "git cherry-pick {plugin-commit-hash}"

These are fundamentally different strategies:
- `git checkout dev -- plugins/pas/` copies files from the dev branch into the current branch's working tree.
- `git cherry-pick {hash}` replays a specific commit onto the current branch.

The parenthetical in process.md is misleading — it labels `git checkout dev --` as "cherry-picking," which it is not. An agent following process.md literally would use `git checkout dev --`, while an agent following pr-management would use `git cherry-pick`. The OQI-01 feedback signal confirms this already caused a real problem in cycle 6.

From a DX perspective, the pr-management skill has the correct, detailed procedure. The process.md description is a high-level summary that should not include implementation details (especially wrong ones).

**Fix:** Remove the parenthetical from process.md's Release phase description, or correct it to match pr-management. The detailed procedure lives in the skill — the process definition should reference the skill, not restate it inaccurately.

### 4. Plan mode bypasses /pas-development (Signal 2) — MEDIUM

This is a real routing gap, but the DX tradeoffs are subtle.

**The problem:** When someone uses Claude Code's native plan mode to think about PAS changes, the plan gets produced outside the pas-development process. The multi-agent discovery/planning phases are bypassed. The user gets a quick plan but loses the structured synthesis.

**The DX balance question:** Too aggressive routing feels heavy-handed. Imagine you ask "What if I added a hook for X?" in plan mode and get redirected to a full multi-agent discovery cycle. That is friction, not help. But too subtle means users never discover that `/pas-development` exists for this purpose.

My recommendation: **Inform, do not redirect.**

- Add a brief note to CLAUDE.md under a "Development Workflow" section: "To evolve PAS itself, use `/pas-development` for structured multi-agent planning. Native plan mode works but bypasses the discovery and feedback synthesis that the development process provides."
- Do NOT try to intercept or redirect plan mode. That would fight the user's chosen interaction pattern.
- The skill launcher description could also mention this: "For PAS framework evolution, this process provides structured discovery and planning that native plan mode does not."

This is the lightest touch that makes the capability discoverable without being intrusive. Users who want the fast path keep it. Users who want rigor know where to find it.

### 5. Deleted orchestrator.md (Signal 4) — LOW

A deleted feedback file from cycle-6. Git status shows `workspace/pas-development/cycle-6/feedback/orchestrator.md` as deleted. This is low DX impact — it is a historical artifact, not something agents actively reference. But leaving tracked files in a deleted state creates noise in `git status` that can confuse agents reading repository state.

**Fix:** Either restore it from git or commit the deletion. Do not leave it in limbo.

## Quick Wins

1. **Change "4 phases" to "5 phases" in CLAUDE.md** — 10-second fix, immediate accuracy improvement for every future session.
2. **Sync `library/` from `plugins/pas/library/`** — Ensures agents read current orchestration patterns. Critical for process correctness.
3. **Remove or correct the parenthetical in process.md Release phase** — Eliminates the contradiction that already caused a real bug.
4. **Commit or restore the deleted orchestrator.md** — Cleans up git status noise.

## Not Quick Wins (but worth noting)

- Automating library sync so drift cannot recur. This needs a design decision (hook? release checklist step? script?) and should be planned properly.
- Plan mode routing. This is a long-term discoverability problem, not a one-line fix. The "inform, don't redirect" approach is low effort and good enough for now.
