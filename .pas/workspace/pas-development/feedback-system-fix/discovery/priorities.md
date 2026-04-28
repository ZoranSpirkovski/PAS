# Discovery Priorities

Derived from 3 backlog signals (OQI-01, OQI-02, PPU-01) and GitHub Issue #6.

## Priority 1: Structural Enforcement (Issues #1-5)
The feedback loop is broken because nothing enforces workspace creation, self-evaluation, or signal routing. Orchestration patterns use passive language ("check for") instead of imperative ("create"). Self-eval relies on hooks that silently fail.

## Priority 2: Regressions (Issues #6-7)
- creating-processes skill lost its hooks step during generation scripts refactor
- Generation scripts output to CWD, making test cleanup destructive
