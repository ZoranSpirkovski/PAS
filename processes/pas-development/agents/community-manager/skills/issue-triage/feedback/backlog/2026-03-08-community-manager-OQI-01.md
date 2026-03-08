[OQI-01]
Target: skill:issue-triage
Degraded: Discovery proactivity — triage report was accurate but too conservative
Root Cause: The triage skill focuses on classifying what exists (open issues, activity) but does not prompt the agent to proactively recommend actions when the tracker is clean. With 0 open issues, I defaulted to "nothing to do" instead of looking for gaps to surface (e.g., suggesting the library drift pattern warrants a preventive checklist item, or recommending documentation of the merge-safety gap before it was assigned as P4).
Fix: Add a "Clean Tracker Proactivity" section to the issue-triage skill: when there are 0 open issues, shift focus from classification to proactive signal analysis — recommend preventive measures, suggest issues that should be filed, or flag recurring patterns that warrant tracking even if no user has reported them.
Evidence: Owner feedback that the team was "too conservative in discovery, expected more proactivity"
Priority: MEDIUM
