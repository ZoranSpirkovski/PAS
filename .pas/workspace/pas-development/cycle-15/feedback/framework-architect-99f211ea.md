[STA-01]
Target: skill:framework-assessment
Strength: OBSERVED
Behavior: Read-then-cite discipline — every claim in the perspective file was backed by a `file:line` citation verified against the live tree (guards.sh:11, route-feedback.sh:26-48, pas-create-process:295-307, SKILL.md:57, etc.). This caught the #125 prose/reality mismatch (the "Local copy is authoritative" string does not exist in plugins/pas/ — it lived in downstream consumer repos), which reframed the whole cycle.
Context: Cycle-15 was a large architectural shift driven by an issue that quoted text no longer in the source tree. Without verification discipline, the cycle would have chased a literal line and mis-scoped.

[STA-02]
Target: skill:implementation-planning
Strength: OBSERVED
Behavior: Sequencing the dogfood-hazardous commit (P5 pas-development migration) LAST in the commit chain (C09), not first or middle. This contains blast radius — earlier commits run on stable substrate, and the single commit that invalidates the running process definition lands after the test-critical routing work.
Context: Cycle-14 memory records the N/N+1 dogfooding hazard ("modifying hooks while the cycle runs on those hooks makes live integration tests unreliable"). This cycle applied that lesson in ordering, not just in P10 documentation.

[OQI-01]
Target: skill:implementation-planning
Degraded: Version-bump strategy leaked plan noise. The plan discusses three options for bumping 1.3.3 → 1.4.0 (call bump-version.sh three times, direct jq, extend the script) inline. That's deliberation that belonged in the final plan as a single sentence: "Version bump is a manual jq edit because bump-version.sh is patch-only; adding --minor is deferred."
Root Cause: Planning-as-thinking bled into planning-as-artifact. When a decision is small, the plan should state the decision, not retrace the reasoning.
Fix: When writing implementation-plan output, collapse any "Option A vs B vs C" block into a one-line decision + one-line rationale. If the tradeoff is substantive, promote it to Risks (§7) instead of leaving it mid-prose in the commit sequence table.
Evidence: §4 commit sequence contains ~8 lines on bump-version.sh options that could be 2 lines.
Priority: LOW

[OQI-02]
Target: skill:framework-assessment
Degraded: Round-1 perspective surfaced a "new env var needed?" question (§2.1, Q1) that the owner's priorities v2 implicitly resolved by adopting Claude Code's existing registry files (known_marketplaces.json, installed_plugins.json). If I'd checked `~/.claude/plugins/` existence at the start of Discovery rather than in Planning, I'd have known the registry was already there and framed the perspective around it directly.
Root Cause: Ecosystem-adjacent data (Claude Code's own filesystem conventions) wasn't in my default "read these files" checklist for framework-assessment. I treat the PAS tree as the universe and only grep outside when prompted.
Fix: Add to framework-assessment/SKILL.md Process step 4 ("Version analysis"): also inspect `$HOME/.claude/plugins/{known_marketplaces.json, installed_plugins.json}` when the cycle topic touches plugin distribution, installation, or cross-project concerns. Don't treat them as "ecosystem-analyst territory" — they're substrate.
Evidence: My perspective file (§7.1) proposed a new `${MARKETPLACE_ROOT}` consideration and only dismissed it after cycle-10 memory lookup. The actually-authoritative answer (Claude Code's registry files) wasn't surfaced until the owner's v2 framing. Could have been mine in round 1.
Priority: MEDIUM

[OQI-03]
Target: skill:implementation-planning
Degraded: The perspective file proposed an "outbox" pattern (§3.2, §7/R1) that priorities v2 then made a tertiary fallback rather than the primary write path. My framing over-weighted the read-only-install concern because I reasoned from worst-case deployment rather than checking actual deployment mix.
Root Cause: Risk-from-first-principles without verification. I did ask the right question in round 2 (Q2 to community-manager) but only after writing a solution around the unverified risk.
Fix: In framework-assessment, when a risk hinges on a deployment property (read-only vs writable, frozen vs source-checkout), verify before proposing. A two-line check (`ls ~/.claude/plugins/marketplaces/`) would have shown the clones are writable git repos with autoUpdate=true, not frozen installs. That single observation would have flipped the primary write path from "outbox" to "direct local commit" in round 1.
Evidence: Perspective §3.2 made outbox the default write mode; priorities v2 demoted it to a fallback after disk/permission failures. The instinct was right but the framing emphasis was wrong.
Priority: MEDIUM
