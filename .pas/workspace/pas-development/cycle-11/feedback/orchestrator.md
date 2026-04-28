[OQI-01]
Target: process:pas-development
Degraded: Orchestrator jumped into code without creating workspace or lifecycle tasks. User had to interrupt twice to enforce PAS lifecycle.
Root Cause: The plan mode → execution transition bypassed the lifecycle protocol. The orchestrator treated plan approval as permission to start coding immediately.
Fix: When transitioning from plan mode to execution, the FIRST action must be workspace creation and task creation per lifecycle.md. No code changes before workspace exists.
Evidence: "this is super frustrating you need to use /pas to update the /pas-development" and "why don't we have a workspace for the work we are doing????"
Priority: HIGH

[OQI-02]
Target: skill:creating-processes
Degraded: Agent dispatches for file edits were rejected twice by the user. Wasted context on rejected work that had to be redone.
Root Cause: Using bypassPermissions mode for agents making edits to many files — user wanted to review before approving.
Fix: Use default permission mode for agents that make edits. Only use bypassPermissions for read-only exploration.
Evidence: Three agent dispatches rejected by user in sequence.
Priority: MEDIUM

[STA-01]
Target: framework:pas
Strength: CONFIRMED_BY_USER
Behavior: The .pas/ directory convention correctly consolidates all project-level artifacts. Migration function works correctly — 59/59 tests pass including 7 migration tests.
Context: Major restructuring of all path references across ~30 plugin files. High risk of regression but comprehensive test coverage prevented issues.
