[OQI-03]
Target: agent:community-manager
Degraded: Agent fabricated a growth narrative from development activity data
Root Cause: The GitHub traffic/clones API returns clone counts that include the repo owner's own git operations. The community-manager interpreted these as external interest ("marketplace discovery is working") without critical analysis. A 2-day-old repo with zero stars and zero forks does not have 104 genuine cloners.
Fix: Community-manager's gh-engagement and issue-triage skills need a verification requirement for traffic/adoption metrics: cross-reference clone data against stars, forks, and repo age before drawing conclusions.
Evidence: Repo API shows stargazers_count: 0, forks_count: 0, subscribers_count: 0, created 2026-03-06.
Priority: HIGH
