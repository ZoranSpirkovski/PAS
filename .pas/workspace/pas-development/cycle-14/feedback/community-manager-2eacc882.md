[OQI-01]
Target: process:pas-development
Degraded: Execution phase dispatched community-manager before discovery and planning had produced any artifacts (both directories empty, status.yaml shows both phases as `pending`)
Root Cause: The hub-and-spoke execution dispatch in cycle 14 was issued without a prerequisite gate that confirms `discovery/issue-triage.md` and `planning/implementation-plan.md` exist
Fix: Add a precondition check to the execution-phase dispatcher (orchestrator) — refuse to dispatch execution agents until each prior phase's `output_files` listed in `status.yaml` exists on disk. This is also the substance of issue #49 in the M3 backlog.
Evidence: Workspace state at dispatch time — `discovery/`, `planning/` empty; `execution/changes/` empty; status.yaml `phases.discovery.status: pending`, `phases.planning.status: pending`. community-manager had to ask team-lead whether to scaffold-or-wait.
Priority: MEDIUM

[OQI-02]
Target: agent:community-manager
Degraded: My PR-prep deliverable is necessarily speculative — file list, "closes #N" lines, and issue-close comments are based on the milestone roadmap rather than the actual diff produced by framework-architect / dx-specialist
Root Cause: PR scaffolding was produced before the upstream agents committed their changes; the runbook tells the orchestrator to "adjust the file list if framework-architect / dx-specialist touch additional plugin files"
Fix: pr-management SKILL.md should add a Step -1: "If running in a phase before code changes exist, produce only the title/branch/runbook scaffolding. Generate the file list, 'closes #N' lines, and issue-close comments AFTER `git diff main --stat` shows the actual changes." This separates PR-strategy from PR-execution cleanly.
Evidence: Cycle-14 execution dispatch put PR prep parallel with code changes rather than after them; community-manager produced a scaffolding file with caveats like "adjust the file list above if framework-architect / dx-specialist touch additional plugin files".
Priority: LOW
