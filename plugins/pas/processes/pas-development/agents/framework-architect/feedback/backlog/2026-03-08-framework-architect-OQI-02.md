[OQI-02]
Target: agent:framework-architect
Degraded: Discovery proactivity — assessment was reactive (responded to listed signals) rather than proactive (independently identifying additional issues)
Root Cause: Treated the signal list as exhaustive rather than as a starting point. Did not independently audit for additional drift or structural issues beyond what was presented.
Fix: In discovery, treat provided signals as seeds. Run independent audits (convention compliance, cross-reference checks) to surface issues the other agents may have missed.
Evidence: Owner feedback that team was "too conservative in discovery, expected more proactivity"
Priority: MEDIUM
