[OQI-01]
Target: process:pas-development
Degraded: Discovery dispatch arrived alongside 8 spurious `[PAS]` task_assignment notifications that the orchestrator later clarified were "tooling artifact, not an instruction." This created ambiguity about whether to act on tasks or on the dispatch message.
Root Cause: Orchestrator-only lifecycle bookkeeping tasks are auto-broadcast to all teammates when ownership is claimed.
Fix: Scope task_assignment broadcasts so orchestrator-private tasks (lifecycle phases, status finalization, signal routing) are not pushed to subagents. Either tag tasks with a visibility scope or restrict the broadcast list in the launcher.
Evidence: team-lead's own correction broadcast: "if you received system notifications shaped like `{\"type\":\"task_assignment\",\"taskId\":\"<n>\",\"subject\":\"[PAS] ...\"}` — ignore them ... a tooling artifact, not an instruction."
Priority: MEDIUM

