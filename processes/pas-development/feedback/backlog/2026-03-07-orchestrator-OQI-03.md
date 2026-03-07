[OQI-03]
Target: process:pas-development
Degraded: Discovery phase skipped — orchestrator jumped to proposing solutions
Root Cause: When the product owner said to "rehaul completely," the orchestrator started proposing approaches before running a proper discovery phase. The product owner had to say "lets use the skill to do discovery properly."
Fix: The SessionStart hook (pas-session-start.sh) will inject process lifecycle reminders.
Evidence: "User said 'lets use the skill to do discovery properly'"
Priority: MEDIUM

