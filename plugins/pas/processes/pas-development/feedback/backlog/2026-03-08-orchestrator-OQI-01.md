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

