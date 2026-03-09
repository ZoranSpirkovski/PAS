[OQI-01]
Target: agent:ecosystem-analyst
Degraded: message delivery reliability — assessment was written and summary sent, but orchestrator did not register it, requiring two re-confirmations before acknowledgment
Root Cause: same issue as cycle-7 OQI-02. The ecosystem-scan skill still has no delivery protocol for the discussion pattern. I completed work and sent a message, but the orchestrator's mailbox processing may have missed it or it arrived before the orchestrator was ready to receive discovery contributions. Three messages were needed for acknowledgment.
Fix: the cycle-7 OQI-02 fix was filed but apparently not applied. The ecosystem-scan skill output format section should include: "When complete, send a single message to the orchestrator with the file path and a one-line confirmation. If no acknowledgment within one exchange, re-send once with the exact file path."
Evidence: orchestrator sent "All 4 other discovery agents have submitted. We're waiting on your ecosystem assessment. Please submit now." after the assessment file had already been written and two messages sent confirming it.
Priority: MEDIUM

