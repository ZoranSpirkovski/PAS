---
agent: community-manager
phase: discovery
round: 1
cycle: 14
lens: GitHub issues SME
---

# Community-manager perspective — issue triage

## External-metrics integrity

All 44 open issues authored by `ZoranSpirkovski` (verified via `gh issue list ... --json author`). Zero stars, zero forks, zero external contributors. Every issue is owner-reported, mostly from downstream consumer sessions (agency-delivery, feature-dev, attorney, webmaster, upravitel, aigis-insight-forge, Visualife, Tangled-Roots-V1). No external community signals to weigh.

## Triage table (44 rows)

Effort key: S = ≤1 hr, M = half-day, L = full day, XL = multi-day / RFC.

| #  | Milestone | Priority | Effort | Notes |
|----|-----------|----------|--------|-------|
| 29 | M7 | P2 | XL | RFC: codebase knowledge persistence — 2-level (process / workspace) |
| 30 | M6 | P2 | S | applying-feedback should use AskUserQuestion (paired with #40) |
| 31 | **CLOSE** | — | — | dup-of #32 (also dup-of #33) — same OQI-03 text |
| 32 | M5 | P1 | M | creating-processes missing workspace blueprint step |
| 33 | **CLOSE** | — | — | dup-of #32 (literal text duplicate of #31) |
| 34 | M6 | P2 | S | GH issue template for framework:pas signal routing |
| 35 | M4 | P1 | M | PAS doesn't follow lifecycle for creation skills (paired with #60) |
| 36 | M4 | P1 | S | "improvements reflection" default shutdown step (PPU from session b975970f) |
| 37 | M5 | P1 | S | newly-created process tries to read non-existent files |
| 38 | **M3** | **P0** | M | system-reminder hooks derail subagents |
| 39 | M4 | P1 | S | verify-completion-gate ignores in_progress (one-line grep fix) |
| 40 | M6 | P2 | S | applying-feedback uses AskUserQuestion (paired with #30) |
| 41 | M6 | P2 | S | applying-feedback: clarify direct apply vs GH issue routing |
| 42 | M7 | P2 | S | subagent-driven-development: skip review for trivial tasks |
| 43 | M7 | P2 | S | subagent-driven-development: collapse redundant plan docs |
| 44 | M5 | P1 | M | dup-of #32 phrased as creating-processes enforcement (keep — adds enforcement angle) |
| 45 | M4 | P1 | S | OQI: orchestrator skipped shutdown sequence proactively |
| 46 | M7 | P2 | M | GATE: preserve per-process duplication; pairs with #47 |
| 47 | M7 | P2 | XL | PPU: shared agents with per-process overlay (RFC, paired with #46) |
| 48 | M7 | P2 | M | agent lifecycle guidance (spawn late, precise context, collect self-eval) |
| 49 | **M3** | **P0** | M | no checkpoint enforces phase output_files before advancing — direct enabler of cycle 14 OQI-01 |
| 50 | M6 | P2 | S | feedback must stay in workspace, not auto-memory |
| 51 | M4 | P1 | L | universal /startup and /shutdown skills (umbrella for #36/#39/#45/#49/#53) |
| 52 | **M3** | **P0** | M | verify-task-completion picks wrong workspace (mtime race; paired with #70 finding 3) |
| 53 | M4 | P1 | S | offer feedback application during shutdown |
| 54 | **M3** | **P0** | S | SessionStart crash on missing instance — append `\|\| true` to grep pipelines |
| 55 | **M3** | **P0** | S | check-self-eval grep -c multi-line; trivial fix per body |
| 56 | **CLOSE-AS-RESOLVED** | — | — | umbrella signal — covered by #55 fix |
| 57 | **CLOSE-AS-RESOLVED** | — | — | umbrella signal — covered by #54, #58, #64 fixes |
| 58 | **M3** | **P0** | S | hooks should warn on malformed status.yaml (overlap with #54) |
| 59 | **M3** | **P0** | M | framework signals must NOT route to product repos |
| 60 | M4 | P1 | M | dup-of #35 from a different session — keep both for cross-session evidence |
| 61 | **CLOSE** | — | — | dup-of #62 (literal text dup); not a PAS bug — Vite/PDF anecdote |
| 62 | **DOWNGRADE** | P2 | S | OQI-04 about marking unverified causes as hypothesis — small self-evaluation/SKILL.md doc tweak. M6 polish. |
| 63 | M5 | P1 | S | creating-processes workspace HARD REQUIREMENT — overlap with #32/#44 |
| 64 | **M3** | **P0** | S | pas-session-start.sh CLAUDE_PLUGIN_ROOT unbound |
| 65 | M5 | P1 | M | pas-create-skill needs process-level skill creation |
| 66 | **CLOSE** | — | — | PPU-05 already references #65 as the canonical issue |
| 67 | **M3** | **P0** | M | SubagentStop fires for non-PAS subagents (one of the worst bugs — landed feedback in attorney workspace) |
| 68 | **M3** | **P0** | M | SessionStart hijacks subagents (15 tool uses → empty self-eval) |
| 69 | M7 | P2 | XL | RFC: PAS-authored skills should be portable |
| 70 | **M3** | **P0** | XL | worktree contract — see RFC split below |
| 71 | **M3** | **P0** | M | SubagentStop elides subagent text response (5× per session in agency-delivery) |
| 72 | M7 | P2 | XL | RFC: workspace organization at scale (status prefixes, archive, phase-level grouping) |

## Dedup / close recommendations

**Close as duplicates (no action):**
- #31, #33 — literal text duplicates of #32 (OQI-03 routing dup); close pointing at #32
- #61 — literal text dup of #62; close pointing at #62
- #66 — body explicitly references #65 as the routed issue; close pointing at #65

**Close as resolved when M3 ships:**
- #56 (umbrella) — resolved by #55 fix
- #57 (umbrella) — resolved by #54 + #58 + #64 fixes

**Downgrade:**
- #62 — the actual signal is "self-evaluations should distinguish verified vs hypothetical root causes" — that's a small doc tweak in `self-evaluation/SKILL.md`, not a P0. Move to M6 (P2).

**Net effect:** 44 open → 39 actionable after dedup → 33 after M3 closes 6 (the 5 dup/umbrella + #62 if accepted as a downgrade). M3 itself contains 11 actionable issues (after pulling #49 in — see below) plus 2 umbrella closes.

## M3 scope confirmation + correction

The pre-triage roadmap lists 13 issues for M3. After review:

**Confirmed in M3 (11 actionable + 2 umbrella):**
- #38, #52, #54, #55, #58, #59, #64, #67, #68, #70, #71 — all P0 hook crashes / subagent derailments
- #56, #57 — close as resolved post-merge

**Add to M3 (proposed):** **#49** — "no checkpoint enforces phase output_files before advancing." Direct evidence: cycle 14 itself has dispatched execution before discovery/planning produced anything (filed as my own OQI-01 in `feedback/community-manager-2eacc882.md`). #49 is a one-file fix in `verify-task-completion.sh` and is in the same hook-stability family — keeping it in M4 means the orchestrator continues skipping deliverables for the entire next cycle. Recommend pulling into M3.

**Re-scope candidate:** #50 ("feedback must stay in workspace, not auto-memory"). Currently slotted M6, but the auto-memory leak is partly about routing — same theme as #59 (framework signals → wrong repo). Worth checking if a single message-routing pass can knock out both.

**Hidden P0s in M4-M7?** None found. The M4 lifecycle items (#36, #39, #45, #51, #53) cluster around "orchestrator skips steps" — annoying but not session-breaking. M5 generator items (#32, #37, #44, #63) are bad for new processes but not for existing ones. M6/M7 are polish + RFC.

## #70 RFC-issue split proposal

#70 contains 10 distinct findings + a suggested-direction list. Implementing it as one PR would be unreviewable. Propose splitting into 6 sub-issues, all under M3 except finding-9:

- **#70.1 — Resolve `PAS_PROJECT_ROOT` once and export it** (findings 1, 2, 4 first half) — foundation; nothing else lands without this. Effort: M.
- **#70.2 — Fix completion-gate deadlock + print absolute paths in errors** (finding 4) — depends on #70.1. Effort: S.
- **#70.3 — Atomic status.yaml mutation + remove mtime auto-detect race** (finding 3) — overlaps with #52. Effort: M.
- **#70.4 — Scope `check-self-eval.sh` to PAS-spawned subagents** (finding 7) — overlaps with #67/#68. Effort: M.
- **#70.5 — Add `skip_pas_auto_pin` escape hatch + cwd-relative SessionStart context** (finding 8) — Effort: S.
- **#70.6 — Generator + skill body migration to absolute-anchor paths** (findings 5, 6, 10) — depends on #70.1; rewrites `pas-create-*` and `self-evaluation/SKILL.md`. Effort: L.
- **#70.9 (defer to M7)** — `.pas/workspace` sidecar visibility on PRs (finding 9) — architectural; relates to #72 workspace organization RFC.

Filing the split itself is a small task (6 `gh issue create` calls referencing #70). I can do it during release phase if the team agrees. Original #70 stays open as the umbrella, closes when sub-issues all merge.

## Source-session attribution

Useful for cross-referencing related issues:

- **agency-delivery / Tangled-Roots-V1 sessions:** #67, #70, #71, #72 — most architectural critiques came from worktree-heavy multi-phase work
- **feature-dev / stripe-payments (1ce8c296):** #49, #50, #51, #53 — entire M4 lifecycle bundle
- **aigis-insight-forge (6beb749a / 2026-03-27):** #45, #46, #47, #48
- **Visualife (b680fff6, afb73e3a):** #30, #40, #41, #42, #43
- **upravitel (01a0c95a):** #63
- **create-develop-process (b975970f):** #34, #36
- **invoice generation (first PAS use):** #60

Several issues come from the same session and should be reviewed together when implementing the corresponding milestone — implementing #51 without #36/#39/#45/#49/#53 in the same PR would leave half the stripe-payments session feedback unaddressed.

## Recommendation summary

1. **M3 scope:** confirm 11 + 2 from roadmap; add #49 (cheap, prevents continued cycle-level OQI).
2. **Close-on-merge candidates:** 6 issues (#31, #33, #56, #57, #61, #66) — saves the queue 14% with zero implementation cost.
3. **Split #70** into 6 sub-issues before assigning to framework-architect — otherwise it's an unreviewable PR.
4. **Downgrade #62** to M6 unless feedback-analyst flags it as higher.
5. **Verify #50/#59 routing overlap** — possible single-PR consolidation.
