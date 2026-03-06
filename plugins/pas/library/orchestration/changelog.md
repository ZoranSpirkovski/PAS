# Orchestration Library Changelog

## 2026-03-07 — Enforce self-evaluation, add agent communication guidance

Triggered by: GitHub issue #1 — Self-eval skipped 3x across 2 sessions, wrong communication mechanism used
Pattern: Shutdown and feedback enforcement fails because nothing enforces it; orchestrator repeatedly skipped self-eval
Changes:
- solo.md: Strengthened shutdown sequence with mandatory self-eval checkpoint, feedback routing verification
- hub-and-spoke.md: Added self-eval instructions to spawn prompt template
- hub-and-spoke.md: Added Agent Communication section (SendMessage for team members, Agent resume for ephemeral subagents)
- hub-and-spoke.md: Made self-eval mandatory before proceeding to agent shutdown, added feedback routing verification step
