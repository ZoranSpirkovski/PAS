[OQI-02]
Target: process:pas-development
Degraded: Agent spawn timing race condition persisted from cycle-7 — same bug, same workaround
Root Cause: Messages sent immediately after Agent spawn are lost because agents read their agent.md files before processing their mailbox. This required re-sending discovery prompts to all 5 agents. The cycle-7 self-evaluation flagged this exact issue (OQI-02) with the fix "wait for ready confirmations before sending phase instructions." The fix was not implemented.
Fix: After spawning agents, wait for all "ready" confirmations before sending phase work. This was identified in cycle-7 and ignored.
Evidence: All 5 discovery agents required re-sent prompts, identical to cycle-7.
Priority: MEDIUM

