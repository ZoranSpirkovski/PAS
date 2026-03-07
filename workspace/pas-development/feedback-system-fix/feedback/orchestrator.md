[OQI-01]
Target: process:pas-development
Degraded: Orchestrator planned implementation without workspace lifecycle — 3/3 sessions now where process lifecycle was not followed autonomously
Root Cause: The orchestrator produced a complete implementation plan but omitted the pas-development process's own workspace initialization, status tracking, and shutdown steps. The product owner had to point this out.
Fix: The orchestration patterns (Group A changes) add HARD REQUIREMENT and COMPLETION GATE enforcement. The pas-development process.md itself should reference workspace lifecycle explicitly in its phase definitions.
Evidence: "Product owner rejected plan approval twice: first for missing workspace lifecycle, then for not noting that they had to tell the orchestrator to follow the process."
Priority: HIGH

[OQI-02]
Target: process:pas-development
Degraded: Orchestrator skipped self-evaluation at shutdown despite having just implemented the fix for this exact problem
Root Cause: The orchestrator completed all implementation work, ran verification, and presented the summary — but did not write self-evaluation or finalize status.yaml. The product owner had to remind the orchestrator.
Fix: The COMPLETION GATE is now in the orchestration patterns. The verify-completion-gate.sh Stop hook will enforce this technically with exit 2.
Evidence: "User said 'from what I can see you didn't do the self-evaluation' after the orchestrator declared batch complete without shutdown."
Priority: HIGH
