# Discovery Priorities: Feedback System Rehaul

## Core Problem

The PAS feedback system relies entirely on markdown instructions that the orchestrator can (and does) ignore. 3/3 sessions failed to produce feedback autonomously. The v1.3.0 fix made instructions louder but didn't change the enforcement mechanism — it's still text an LLM reads and may skip.

## What We Have (Unused)

Claude Code provides 4 hard enforcement mechanisms PAS doesn't use:

| Mechanism | What It Does | PAS Usage |
|-----------|-------------|-----------|
| `Stop` hook exit 2 | **Blocks session end**, forces Claude to continue | Currently exit 0 (warning log only) |
| `TaskCompleted` hook | **Blocks task completion** until conditions met | Not used at all |
| `TeammateIdle` hook | **Forces teammates to keep working** | Not used at all |
| Agent-based hooks | **Spawns verification subagent** with filesystem access | Not used at all |

Additionally:
- `SessionStart` hook can inject context (workspace reminders)
- `PreToolUse` hook can block specific tool calls
- `PostToolUse` hook can inject reminders after key operations

## Priority 1: Stop Hook Enforcement (Critical)

Replace the current warning-only Stop behavior with hard blocking:
- Check if workspace exists and has feedback files
- Check if status.yaml shows `status: completed`
- If conditions fail → exit 2 → Claude cannot stop → must complete shutdown

This single change would have caught all 3 session failures.

## Priority 2: SessionStart Hook (Workspace Init)

Add a SessionStart hook that:
- Detects if a PAS process is about to run (checks for pas-config.yaml + process context)
- Injects workspace creation reminder into Claude's context
- This addresses the "orchestrator forgets to create workspace" pattern

## Priority 3: TaskCompleted Hook (Task-Level Enforcement)

When tasks are used for tracking:
- Block task completion until the task's deliverables exist on disk
- Block final task completion until feedback files exist

## Priority 4: Redesign Hook Architecture

Current hooks.json registers:
- `SubagentStop` → check-self-eval.sh (warning only, exit 0)
- `Stop` → route-feedback.sh (routes signals, no enforcement)

Proposed hooks.json:
- `SessionStart` → inject workspace/feedback reminders
- `Stop` → verify-completion-gate.sh (exit 2 if conditions fail)
- `Stop` → route-feedback.sh (routes signals, runs after gate passes)
- `SubagentStop` → check-self-eval.sh (enhanced, exit 2 if no self-eval)
- `TaskCompleted` → verify-task-deliverables.sh (exit 2 if incomplete)

## Priority 5: Agent-Based Verification

For complex checks, use agent-type hooks instead of bash scripts:
- Agent can read files, check content, verify structure
- More robust than pattern matching in bash

## What v1.3.0 Already Fixed (Keep)

- Imperative workspace creation language in orchestration patterns
- COMPLETION GATE text in all 4 patterns
- Orchestrator self-eval as explicit shutdown step
- Framework signal routing documentation
- route-feedback.sh plugin path fallbacks
- --base-dir flag on generation scripts
- creating-processes hooks step restoration

The text-level enforcement stays. The hooks ADD hard technical enforcement on top.
