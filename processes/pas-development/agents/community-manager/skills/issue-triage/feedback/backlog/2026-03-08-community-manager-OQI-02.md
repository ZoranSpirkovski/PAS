[OQI-02]
Target: skill:issue-triage
Degraded: Assessment completeness — the discovery report treated GitHub API data as ground truth without caveats
Root Cause: The issue-triage skill has quality checks for issue classification ("classifications are based on issue content, not just title") but no equivalent guidance for traffic/adoption metrics. I applied the skill's rigor to issue analysis but not to traffic data, which was outside the skill's explicit scope. The community assessment task required me to go beyond issue triage into metrics interpretation, and I had no skill-level guardrails for that.
Fix: If the community-manager agent is expected to report adoption metrics, the gh-engagement or a new metrics-reporting skill should include: (1) always compare metrics across multiple dimensions before drawing conclusions, (2) flag when a single metric contradicts the broader picture, (3) distinguish between "the API says X" and "X people are actively interested."
Evidence: The discovery report's "Key Insight" section treated clone count as the "most important signal" and built the entire roadmap urgency framing around it.
Priority: MEDIUM
