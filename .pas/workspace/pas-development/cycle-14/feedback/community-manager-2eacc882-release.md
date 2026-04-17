[OQI-01]
Target: skill:pr-management
Degraded: Cherry-picking 10 cycle commits onto a feature branch off main produced 5 identical-shape conflicts in `plugins/pas/hooks/tests/test-hooks.sh`. Each conflict was a HEAD-empty-between-markers vs. incoming-side-adds-section block. Resolution was mechanical (delete markers, keep both sides), but a different agent unfamiliar with the pattern could have skipped sections or merged them incorrectly.
Root Cause: The hook test harness is one large file with sequential `# Section:` decoration blocks. Each cherry-picked commit added a new section at end-of-file. When dev's commit history adds them in one order and main's history sees them via cherry-pick in different time-order, the diff anchors become ambiguous.
Fix: pr-management/SKILL.md Step 2 should add: "If `tests/test-hooks.sh` produces conflicts of the form `HEAD vs incoming-adds-section`, resolution is keep-incoming-content + delete-markers. Verify with `bash -n` and a full harness run before continuing the cherry-pick."
Evidence: Five conflicts in this PR (#111), all C04/C05/C06/C07/C08 sections. All resolved identically. Test count delta from 117 → 112 may be a downstream consequence (filed as #112).
Priority: MEDIUM

[OQI-02]
Target: skill:pr-management
Degraded: Step 2 of the SKILL says "git add the conflicted-files; git cherry-pick --continue --no-edit". In this PR the same shape recurred 5 times in a row; without a heads-up the agent could mistake recurring identical-shape conflicts for divergence rather than the expected behavior.
Root Cause: The skill documents the single-conflict case but doesn't mention that one cherry-pick can produce the same conflict shape across many commits when the conflicting file is a sequential append-log (test harness, changelog).
Fix: Add a "Common patterns" subsection under Step 2: "Append-log files (test harnesses, changelogs) often produce N identical-shape conflicts in a sequence — one per cherry-picked commit that touched them. Resolve each with the same pattern; do not abort just because the shape recurs."
Evidence: This release phase. Same conflict shape across C04, C05, C06, C07, C08 cherry-picks.
Priority: LOW

[STA-01]
Target: skill:pr-management
Strength: CONFIRMED_BY_USER
Behavior: Refusing to merge the PR myself before product-owner authorization arrived via team-lead. I held the PR at "open, awaiting merge" and explicitly listed the post-merge steps that required authorization, instead of executing them speculatively.
Context: Team-lead's release dispatch said "Run the full pr-management workflow" which could have been read as "merge it yourself." I read it as "do everything up to the merge gate; merge requires PO approval per project CLAUDE.md." Team-lead's next message confirmed this was the right call ("PRODUCT OWNER EXPLICITLY AUTHORIZED RELEASE"). Future cycles must preserve this gate: PR creation is community-manager work, but the merge button is product-owner-only unless explicitly delegated.
