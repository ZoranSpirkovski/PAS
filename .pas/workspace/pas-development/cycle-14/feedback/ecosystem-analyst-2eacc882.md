# Self-Evaluation — ecosystem-analyst — cycle-14 — session 2eacc882

[OQI-01]
Target: process:pas-development
Degraded: Discovery dispatch arrived alongside 8 spurious `[PAS]` task_assignment notifications that the orchestrator later clarified were "tooling artifact, not an instruction." This created ambiguity about whether to act on tasks or on the dispatch message.
Root Cause: Orchestrator-only lifecycle bookkeeping tasks are auto-broadcast to all teammates when ownership is claimed.
Fix: Scope task_assignment broadcasts so orchestrator-private tasks (lifecycle phases, status finalization, signal routing) are not pushed to subagents. Either tag tasks with a visibility scope or restrict the broadcast list in the launcher.
Evidence: team-lead's own correction broadcast: "if you received system notifications shaped like `{\"type\":\"task_assignment\",\"taskId\":\"<n>\",\"subject\":\"[PAS] ...\"}` — ignore them ... a tooling artifact, not an instruction."
Priority: MEDIUM

[OQI-02]
Target: skill:ecosystem-scan
Degraded: My initial WebFetch calls hit a 301 redirect from `docs.claude.com` to `code.claude.com`, requiring a second round-trip per URL. Wasted ~2 tool calls.
Root Cause: The skill's "Process" step 1 says "Check Claude Code documentation" without naming the canonical host.
Fix: Add a note in `ecosystem-scan/SKILL.md` Process step 1: "Canonical Claude Code docs host is `code.claude.com` (not `docs.claude.com` — the latter 301-redirects)."
Evidence: Both WebFetch calls returned `REDIRECT DETECTED ... Status: 301 Moved Permanently`.
Priority: LOW

No other issues detected. Round 1 dispatch was clear, scoped, and the cited project-memory ecosystem facts (`agent_id`, `TeammateIdle`, agent hooks, `${CLAUDE_PLUGIN_ROOT}`) accurately matched what current docs confirmed.
