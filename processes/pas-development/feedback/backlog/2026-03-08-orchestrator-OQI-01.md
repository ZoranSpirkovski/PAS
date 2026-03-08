[OQI-01]
Target: process:pas-development
Degraded: SKILL.md routing edit was lost during branch switching in Release phase
Root Cause: The orchestrator edited SKILL.md on dev, then checked out a feature branch from main. The edit was staged and committed on the feature branch but the dev branch's working tree copy reverted to the pre-edit state. The dev commit (dev-only artifacts) did not include the SKILL.md change.
Fix: During the Release phase, after committing dev-only artifacts, also commit plugin source changes to dev BEFORE creating the feature branch. Or stage/commit all changes to dev first, then create the feature branch by cherry-picking from dev.
Evidence: "Grep for 'Visualizing a process' returned no matches after switching back to dev"
Priority: MEDIUM

