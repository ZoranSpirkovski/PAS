[OQI-01]
Target: framework:pas
Degraded: TeamCreate agents cannot write to shared workspace — feedback files created by team agents disappeared after agent shutdown
Root Cause: Agents spawned via TeamCreate appear to run in isolated/sandboxed contexts. File writes they perform don't persist to the main workspace. The orchestrator had to re-write all 6 feedback files from the main conversation context after verifying the feedback directory was empty.
Fix: Either (1) the orchestrator should always write feedback files on behalf of team agents based on their reported content, or (2) the self-evaluation skill should document that team agents must return their feedback content in their final message so the orchestrator can persist it, or (3) investigate whether TeamCreate agents can be configured to share the main filesystem.
Evidence: "Glob showed no files in feedback/. ls confirmed empty directory. User reported seeing files appear and disappear."
Priority: HIGH
Route: github-issue

[OQI-02]
Target: process:pas-development
Degraded: Discovery agents' claims were initially taken at face value without code verification
Root Cause: The orchestrator synthesized agent findings and produced priorities without verifying claims against actual source code. The product owner had to intervene: "we need to validate each ticket, we cannot take things for granted. treat tickets as if they are tips to look into not definitive."
Fix: The orchestrator should always verify agent claims against code before presenting gate summaries. Add a verification step between agent reports and gate presentation in the Discovery phase.
Evidence: "User said 'we need to validate each ticket, we cannot take things for granted'"
Priority: MEDIUM

[STA-01]
Target: process:pas-development
Strength: OBSERVED
Behavior: Workspace lifecycle was followed correctly from session start — workspace created, status.yaml initialized, tasks created, status tracked through all 4 phases. This is the first session where the orchestrator did this without being reminded.
Context: Previous 5 sessions all failed to follow workspace lifecycle. The hub-and-spoke HARD REQUIREMENT language and SessionStart hook appear to be working.
