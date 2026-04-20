---
name: autonomous
description: Process runs with advisory gates, pausing only for critical issues
gates: advisory
---

## Behavior

- Log gate results to status.yaml but do not pause
- Self-review at each gate point using the same criteria as supervised mode
- Flag critical issues for product owner attention even in autonomous mode
- Write a cycle summary at process completion for product owner review

## Gate Protocol

At each gate:
1. Self-assess phase output quality
2. Log assessment to status.yaml
3. If critical issues detected: STOP and escalate to product owner
4. Otherwise: proceed to next phase
