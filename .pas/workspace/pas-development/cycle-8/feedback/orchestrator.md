# Orchestrator Self-Evaluation — Cycle 8

## Session: cycle-8-s1 (paused after discovery)

[OQI-01]
Target: process:pas-development
Degraded: Fabricated metrics propagated unchallenged through the entire discovery phase
Root Cause: The community-manager reported "104 unique cloners in 2 days" as evidence of marketplace traction. The orchestrator did not verify this claim before incorporating it into the discovery synthesis and priorities.md. When the owner flagged it as hallucinated, the orchestrator ran a traffic API call that returned non-zero data and tried to rationalize it ("could be bots, CI, your own clones") instead of running the basic repo API (`gh api repos/.../`) which would have shown all zeros immediately. The owner had to correct the orchestrator twice.
Fix: Three changes needed:
1. Any quantitative claim about external metrics (stars, forks, clones, traffic) must be verified by the orchestrator before propagation — not taken from agent reports at face value
2. When the owner says data is wrong, accept the correction immediately. Do not rationalize API data that contradicts the owner's direct knowledge.
3. The discussion pattern needs a verification norm: agents must include the exact command/API call they used for any external data claim, and the orchestrator must re-run it before synthesizing.
Evidence: Owner said "this data is hallucinated" and then "no your understanding is completely flawed as well" after the orchestrator tried to explain away the discrepancy.
Priority: HIGH

[OQI-02]
Target: process:pas-development
Degraded: Agent spawn timing race condition persisted from cycle-7 — same bug, same workaround
Root Cause: Messages sent immediately after Agent spawn are lost because agents read their agent.md files before processing their mailbox. This required re-sending discovery prompts to all 5 agents. The cycle-7 self-evaluation flagged this exact issue (OQI-02) with the fix "wait for ready confirmations before sending phase instructions." The fix was not implemented.
Fix: After spawning agents, wait for all "ready" confirmations before sending phase work. This was identified in cycle-7 and ignored.
Evidence: All 5 discovery agents required re-sent prompts, identical to cycle-7.
Priority: MEDIUM

[OQI-03]
Target: agent:community-manager
Degraded: Agent fabricated a growth narrative from development activity data
Root Cause: The GitHub traffic/clones API returns clone counts that include the repo owner's own git operations. The community-manager interpreted these as external interest ("marketplace discovery is working") without critical analysis. A 2-day-old repo with zero stars and zero forks does not have 104 genuine cloners.
Fix: Community-manager's gh-engagement and issue-triage skills need a verification requirement for traffic/adoption metrics: cross-reference clone data against stars, forks, and repo age before drawing conclusions.
Evidence: Repo API shows stargazers_count: 0, forks_count: 0, subscribers_count: 0, created 2026-03-06.
Priority: HIGH
