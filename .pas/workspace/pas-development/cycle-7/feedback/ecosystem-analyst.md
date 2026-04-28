# Self-Evaluation — Ecosystem Analyst (cycle-7)

[OQI-01]
Target: agent:ecosystem-analyst
Degraded: proactivity in discovery — identified platform capabilities but stopped at "here are the options" rather than proposing concrete hook implementations with pseudocode or draft configs
Root Cause: followed the skill's "frame observations as opportunities, not imperatives" guideline too literally, which led to a descriptive rather than prescriptive assessment
Fix: in future discovery rounds, include at least one concrete implementation sketch (e.g., draft hooks.json snippet) for the highest-impact opportunity, while still framing it as a proposal
Evidence: "Owner feedback: team was too conservative in discovery, expected more proactivity"
Priority: MEDIUM

[OQI-02]
Target: skill:ecosystem-scan
Degraded: delivery timing — assessment was ready before the orchestrator's formal dispatch but required three messages to confirm receipt, suggesting the output format or delivery channel was unclear
Root Cause: wrote the report file and sent a summary before the orchestrator's explicit request arrived, then had to re-confirm twice. The ecosystem-scan skill has no guidance on how to signal readiness to the orchestrator in a multi-agent discussion pattern.
Fix: add a note to the ecosystem-scan skill output format section: "When complete, send a single message to the orchestrator with the file path and a structured summary. Do not pre-send before receiving the orchestrator's request in a discussion pattern."
Evidence: orchestrator sent "Checking in — the other 4 discovery agents have submitted their assessments. Please submit your ecosystem assessment" after the assessment had already been sent twice
Priority: LOW
