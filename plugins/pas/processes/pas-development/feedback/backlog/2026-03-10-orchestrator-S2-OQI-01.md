[OQI-01]
Target: process:pas-development
Degraded: Shutdown sequence was skipped entirely — went from PR merge to "done" without self-evaluation, status finalization, or signal routing
Root Cause: Executing the plan in a single session without pas-development process scaffolding (no TaskCreate, no lifecycle tasks). The owner provided a pre-built plan and said "implement this", so execution bypassed the orchestration pattern. Without lifecycle tasks, there were no hook enforcement triggers.
Fix: Even when executing an owner-provided plan outside the formal pas-development process, create lifecycle tasks for shutdown steps. The hooks exist to catch this — but only if we go through the workspace lifecycle.
Evidence: Owner asked "did we collect feedback?" — proving the shutdown was skipped.
Priority: MEDIUM

