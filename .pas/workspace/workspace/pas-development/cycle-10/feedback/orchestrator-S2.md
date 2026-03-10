[OQI-01]
Target: process:pas-development
Degraded: Shutdown sequence was skipped entirely — went from PR merge to "done" without self-evaluation, status finalization, or signal routing
Root Cause: Executing the plan in a single session without pas-development process scaffolding (no TaskCreate, no lifecycle tasks). The owner provided a pre-built plan and said "implement this", so execution bypassed the orchestration pattern. Without lifecycle tasks, there were no hook enforcement triggers.
Fix: Even when executing an owner-provided plan outside the formal pas-development process, create lifecycle tasks for shutdown steps. The hooks exist to catch this — but only if we go through the workspace lifecycle.
Evidence: Owner asked "did we collect feedback?" — proving the shutdown was skipped.
Priority: MEDIUM

[OQI-02]
Target: skill:creating-processes
Degraded: verify-task-completion.sh had a latent pipefail bug — grep for missing `completed_at` line caused exit 1 instead of exit 2
Root Cause: `grep '^completed_at:' | head -1 | awk '{print $2}'` fails when grep finds no match, and `set -o pipefail` propagates the exit code through the pipeline. Existed since the hook was created in cycle 9 but never triggered because test coverage was manual.
Fix: Added `|| true` to both grep pipelines in the Finalize status case. The test harness (A1) now covers this edge case.
Evidence: Test failure on first run: "expected exit 2, got 1"
Priority: LOW

[STA-01]
Target: skill:creating-processes
Strength: OBSERVED
Behavior: The test harness caught a real bug on the first run (pipefail in verify-task-completion.sh) and verified the fix immediately. 45 tests covering all hooks, all bug fixes, and edge cases.
Context: This is the first automated test coverage for PAS hooks. Previously all testing was manual. The harness validates the entire hook I/O contract.
