[OQI-02]
Target: skill:ecosystem-scan
Degraded: delivery timing — assessment was ready before the orchestrator's formal dispatch but required three messages to confirm receipt, suggesting the output format or delivery channel was unclear
Root Cause: wrote the report file and sent a summary before the orchestrator's explicit request arrived, then had to re-confirm twice. The ecosystem-scan skill has no guidance on how to signal readiness to the orchestrator in a multi-agent discussion pattern.
Fix: add a note to the ecosystem-scan skill output format section: "When complete, send a single message to the orchestrator with the file path and a structured summary. Do not pre-send before receiving the orchestrator's request in a discussion pattern."
Evidence: orchestrator sent "Checking in — the other 4 discovery agents have submitted their assessments. Please submit your ecosystem assessment" after the assessment had already been sent twice
Priority: LOW
