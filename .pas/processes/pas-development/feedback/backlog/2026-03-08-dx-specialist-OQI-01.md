[OQI-01]
Target: process:pas-development
Degraded: Data verification — community-manager fabricated clone metrics (104 cloners) that were propagated without challenge
Root Cause: The discussion pattern relies on agents accepting each other's factual claims at face value. No agent (including the DX specialist) challenged the community-manager's adoption metrics during discovery, even though the repo is a single-person project with no evidence of external users. The orchestrator's claim verification duty (documented in hub-and-spoke.md) was not applied to inter-agent claims during the discussion phase.
Fix: Add explicit verification guidance to the discussion orchestration pattern: "When an agent cites specific numbers (downloads, users, clones, stars), the moderator or a peer agent must verify the claim against the actual data source before recording it in the synthesis. Unverifiable metrics must be flagged as unverified or excluded."
Evidence: "community-manager fabricated clone metrics (reported 104 cloners when repo has zero external activity)"
Priority: HIGH

