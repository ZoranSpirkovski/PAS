---
name: autonomous
description: Execute all phases without pausing at gates
gates: advisory
---

## Behavior

- Execute phases sequentially without pausing for user approval
- Log gate results but do not stop
- Self-review at each gate point
- Flag critical issues even in autonomous mode

## Gate Protocol

At each gate:
1. Self-evaluate phase output against gate criteria
2. Log result to status.yaml
3. Continue to next phase unless critical issue detected
4. If critical issue: pause and alert the user
