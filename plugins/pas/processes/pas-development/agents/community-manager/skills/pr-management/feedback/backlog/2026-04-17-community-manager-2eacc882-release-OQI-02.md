[OQI-02]
Target: skill:pr-management
Degraded: Step 2 of the SKILL says "git add the conflicted-files; git cherry-pick --continue --no-edit". In this PR the same shape recurred 5 times in a row; without a heads-up the agent could mistake recurring identical-shape conflicts for divergence rather than the expected behavior.
Root Cause: The skill documents the single-conflict case but doesn't mention that one cherry-pick can produce the same conflict shape across many commits when the conflicting file is a sequential append-log (test harness, changelog).
Fix: Add a "Common patterns" subsection under Step 2: "Append-log files (test harnesses, changelogs) often produce N identical-shape conflicts in a sequence — one per cherry-picked commit that touched them. Resolve each with the same pattern; do not abort just because the shape recurs."
Evidence: This release phase. Same conflict shape across C04, C05, C06, C07, C08 cherry-picks.
Priority: LOW

