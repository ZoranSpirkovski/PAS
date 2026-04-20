[OQI-02]
Target: skill:feedback-analysis
Degraded: Skill prescribes the "Output Format" of a Feedback Analysis Report but does not define the cross-reference output (signal-to-issue mapping) the orchestrator asked me to produce in this cycle. I had to invent a format on the fly.
Root Cause: The skill assumes signals are the only input — it has no contract for using GitHub issues as a second corpus to cross-reference against.
Fix: Extend the skill with an optional "Cross-Reference Mode" that takes a second corpus (issue tracker, RFC list) and produces a mapping table alongside the cluster report.
Evidence: My perspective doc invents a "Signal/Issue Map" section format because the skill's Output Format only covers Summary / Priority Clusters / Conflicts / Unclustered.
Priority: LOW
