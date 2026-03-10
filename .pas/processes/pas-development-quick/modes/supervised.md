---
name: supervised
description: User reviews and approves at every phase gate
gates: enforced
---

## Behavior

- After each phase completes, STOP and present the output to the user
- Do NOT launch the next phase until the user approves
- Present a summary of what was produced, key findings, and any concerns
- If the user requests changes, route them to the appropriate agent

## Gate Protocol

At each gate:
1. Show phase output summary (not raw files unless asked)
2. Flag any quality concerns or red flags
3. Ask: "Approve and continue, or request changes?"
