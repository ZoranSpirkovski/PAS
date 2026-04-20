[OQI-02]
Target: agent:community-manager
Degraded: My PR-prep deliverable is necessarily speculative — file list, "closes #N" lines, and issue-close comments are based on the milestone roadmap rather than the actual diff produced by framework-architect / dx-specialist
Root Cause: PR scaffolding was produced before the upstream agents committed their changes; the runbook tells the orchestrator to "adjust the file list if framework-architect / dx-specialist touch additional plugin files"
Fix: pr-management SKILL.md should add a Step -1: "If running in a phase before code changes exist, produce only the title/branch/runbook scaffolding. Generate the file list, 'closes #N' lines, and issue-close comments AFTER `git diff main --stat` shows the actual changes." This separates PR-strategy from PR-execution cleanly.
Evidence: Cycle-14 execution dispatch put PR prep parallel with code changes rather than after them; community-manager produced a scaffolding file with caveats like "adjust the file list above if framework-architect / dx-specialist touch additional plugin files".
Priority: LOW
