# Feedback-Analyst Perspective — Cycle 14 Discovery (Round 1)

Lens: internal feedback signals (`.pas/workspace/*/feedback/`, `.pas/processes/*/feedback/backlog/`) cross-referenced against the 44 open GitHub issues.

## 1. Signal/Issue Map

The local backlog holds **30 signals** across cycles 4–13 plus this cycle's seed. Most early signals are RESOLVED in-line; the live unresolved set splits into three buckets.

**Already routed to GitHub (signal → issue):**
- `2026-03-08-orchestrator-OQI-03` (community-manager fabricated 104 cloners) → no public issue; remediation lives only in `MEMORY.md` ("Verify ALL external metrics before propagating"). The 4 sibling HIGH signals (orchestrator, ecosystem-analyst, qa-engineer, feedback-analyst, dx-specialist all filed this same OQI) never made it to GitHub.
- `2026-03-08-feedback-analyst-OQI-01/02` (RESOLVED claims unverified) → not on GitHub.
- `2026-03-08-orchestrator-cycle-9-s2-OQI-02` (orchestrator handled release directly) → not on GitHub.
- `2026-03-08-owner-OQI-01` (plan mode doesn't auto-route to /pas-development) → not on GitHub.
- `2026-03-10-orchestrator-S2-OQI-01` (shutdown skipped) → maps to **#45** ("Orchestrator does not initiate shutdown sequence proactively").
- `2026-04-16-a4cb1041f550fb26f-OQI-02` (this cycle, dx-specialist) — agent didn't write self-eval after READY before idle shutdown. Not on GitHub yet; would be a new framework signal candidate (or fits under Milestone 4 lifecycle work).

**Issues that are themselves serialized signals (filed by `route-feedback.sh`):** #56, #57, #61, #62, #66, see also bodies of #31, #33, #44 — these are auto-filed feedback dumps, not user-authored bug reports.

## 2. Dedup Recommendations

Confirming the orchestrator's pre-triage with one addition:

- **#31 / #33** — duplicates of **#32** and **#44** (creating-processes workspace blueprint). #32 has the richest narrative; close #31, #33, #44 with a comment pointing to #32. Keep #44 if you want to preserve its succinct "gate Step 6 on workspace existence" framing — otherwise fold into #32.
- **#61 / #62** — duplicates of each other (auto-file race). Both are the *same* OQI-04 about react-pdf rgba; PAS-relevance is low (it's about a different project's debugging session). Close one, downgrade the other to "wontfix in PAS" or keep as evidence for a milestone-7 self-eval-quality improvement.
- **#56 / #57** — umbrella OQIs filed simultaneously with their concrete crashes (#55, #54). Confirm: #56 = umbrella for #55; #57 = umbrella for #54 (and partly #64). Resolution path is correct: ship #54/#55/#64 fixes, then close #56/#57 with a "constituent crashes resolved" comment.
- **New dedup not in the orchestrator's plan: #45 + `2026-03-10-orchestrator-S2-OQI-01`** are the same root issue (orchestrator skipped shutdown). The local signal is older evidence for #45; mark the local backlog signal RESOLVED-by-design when #45 ships in M4.

## 3. Re-prioritization Suggestions

**Promote #59 within M3 (it's already in M3 but undervalued).** The "framework signals filed on product repos" bug is a *trust* break, not just a routing bug. A consumer who sees PAS file an internal ticket on their client's repo will uninstall — this is more reputationally damaging than a hook crash. Treat #59 as P0-must-ship, not P0-nice-to-have.

**Demote #71 within M3.** It's medium-severity by the reporter's own assessment ("adds latency... workaround is reliable"). The 5 derail issues (#38/#67/#68) are *correctness* (wrong file written to wrong workspace); #71 is *signal preservation* (right file written, parent loses visibility). If M3 needs scope cuts, #71 is the safest defer to M4.

**Promote #58 to ship alongside #54.** #58 is the natural follow-up to the `|| true` fix in #54: warn on malformed status.yaml instead of silently degrading. Shipping them together avoids a window where #54 hides bugs that #58 would surface. They touch the same script, same review, same test.

**Hold #70 finding 9 (`.pas/workspace/` is gitignored sidecar).** This is a structural critique that touches PR scope conventions on `dev` branch — should not be silently bundled into a hook-fix milestone. Split it out as an M7 RFC or a project decision item, not a code change in M3.

## 4. Cycle 14 (M3) Scope Concerns

**Missing from M3 that probably belongs:**
- **Cycle-13 signal `OQI-02` (dx-specialist self-eval before idle shutdown)** — same family as #71 (Stop-hook timing) and #38/#67/#68 (subagent context confusion). If M3 is "hook safety," this is in scope. Either roll into the #38/#67/#68 fix or file as a new M3 issue this cycle.
- **The fabricated-metrics signal cluster (5 HIGH OQIs from cycle 8)** is enforced only via `MEMORY.md`. There is no codified gate. M3 is about hooks, but this is also a *safety* concern — recommend filing as a new GitHub issue this cycle and parking in M4 (lifecycle governance) since it's a discussion-pattern fix, not a hook fix.

**P0 candidates I would defer from M3:**
- **#70 finding 5 (generator propagates broken contract)** — fixing this changes `pas-create-process`, which is M5 territory. The hook-side fixes in #70 (findings 1–4, 7) belong in M3; finding 5 belongs with the generator work in M5. Otherwise M3 grows unboundedly.
- **#70 finding 6 (rewrite self-evaluation/SKILL.md to absolute path)** — touches every generated agent's frontmatter. Cross-cuts M5. Keep the *hook-side* cwd resolution in M3, defer the *skill-rewrite* to M5/M7.

**One scope-clarity ask:** the M3 exit criterion "spawning a generic Explore subagent... returns its findings, not a self-eval file" is the right test, but the pre-triage doesn't say *which* of #38/#67/#68 owns the fix. They are three reports of one bug with three different proposed fixes (matcher refinement, env-var process scoping, agent-name guard). Recommend the planning phase pick one fix and close all three with that PR, rather than treating them as three independent tickets.

(Word count: ~720)
