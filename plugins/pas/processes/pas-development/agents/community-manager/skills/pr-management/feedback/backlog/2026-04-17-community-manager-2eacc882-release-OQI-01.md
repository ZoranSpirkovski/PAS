[OQI-01]
Target: skill:pr-management
Degraded: Cherry-picking 10 cycle commits onto a feature branch off main produced 5 identical-shape conflicts in `plugins/pas/hooks/tests/test-hooks.sh`. Each conflict was a HEAD-empty-between-markers vs. incoming-side-adds-section block. Resolution was mechanical (delete markers, keep both sides), but a different agent unfamiliar with the pattern could have skipped sections or merged them incorrectly.
Root Cause: The hook test harness is one large file with sequential `# Section:` decoration blocks. Each cherry-picked commit added a new section at end-of-file. When dev's commit history adds them in one order and main's history sees them via cherry-pick in different time-order, the diff anchors become ambiguous.
Fix: pr-management/SKILL.md Step 2 should add: "If `tests/test-hooks.sh` produces conflicts of the form `HEAD vs incoming-adds-section`, resolution is keep-incoming-content + delete-markers. Verify with `bash -n` and a full harness run before continuing the cherry-pick."
Evidence: Five conflicts in this PR (#111), all C04/C05/C06/C07/C08 sections. All resolved identically. Test count delta from 117 → 112 may be a downstream consequence (filed as #112).
Priority: MEDIUM

