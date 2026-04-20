---
name: doctrines
description: Cross-cycle operating rules that inform how PAS work is planned and executed. Consulted during planning and validation phases.
---

# PAS Orchestration Doctrines

Cross-cycle operating rules that protect PAS from known failure modes. Each doctrine is backed by a concrete incident or pattern observed in prior cycles.

## N/N+1 Protocol

**Rule:** Any change to hook substrate (`SessionStart`, `Stop`, `SubagentStop`, `TaskCompleted`) or resolver logic (`CLAUDE_PLUGIN_ROOT` resolution, `.pas/` detection, feedback routing) MUST be validated from a **fresh session** in the following cycle (N+1), not in the cycle that shipped the change (N).

**Why:** The running session loaded the *old* version of the hook at startup. The harness can assert static correctness, but live hook behavior — path resolution, SessionStart text injection, agent-type scoping, feedback file routing — is only fully exercised when a fresh session fires the hook from scratch. In-cycle "integration tests" using the currently-loaded hook state are misleading.

**Origin:** Cycle-14 (Milestone 3, hook safety & stability) — memory record I2. Multiple fixes appeared to pass in-cycle validation but behaved differently when the user started a new session. Filed as issue #113 and codified here.

**How to apply:**

- **Planning:** When a priority touches the hook substrate, mark it in the implementation plan as "N/N+1 — ship in cycle N, validate in cycle N+1." The PR for cycle N is still complete and mergeable; validation just doesn't block the merge.
- **Execution:** After shipping hook-substrate changes, do NOT re-invoke the modified flow within the same session to claim it works. Run the unit harness, commit, move on.
- **Validation:** Cycle-N validation scope = static checks (grep, tests, test-harness count). Live behavior = cycle-N+1 scope with a deliberate checklist.
- **Completion:** A cycle that shipped hook-substrate changes is "complete" at PR open. The N+1 cycle opens with a validation checklist that links back to the shipped PR.

**Scope boundary:** not every change to a file under `plugins/pas/hooks/` triggers this rule — only changes that alter how a hook resolves paths, scopes agents, or processes input. Pure test additions, comment edits, or bumping a constant don't require N+1 validation.

## Dogfooding Hazard Awareness

**Rule:** When PAS modifies PAS, the cycle is running *on* the substrate it is modifying. Migration operations that would remove or relocate process/hook artifacts used *by the running cycle* must be placed late in the commit sequence and should not be re-invoked during the same session.

**Why:** Cycle-14 hit this directly — modifying hook logic mid-cycle caused non-deterministic failures because downstream hook invocations ran on the new code while agents were operating on assumptions from the old code.

**How to apply:**

- Order commits so substrate-mutating operations come last.
- If an operation would invalidate a path that the running session has loaded (e.g., moving `pas-development/` during cycle-15), run it atomically in one commit and do NOT exercise the new path until N+1.
- Keep backwards-compatible fallbacks during transition cycles where feasible.

## Data Verification Norm

**Rule:** Every quantitative or external claim in agent output MUST be backed by a command, URL, or file reference. No speculation passed as fact.

**Why:** Cycle-8 incident — agents fabricated external metrics (e.g., "104 cloners") that contradicted the owner's direct knowledge. Propagated through multiple artifacts before the owner caught it.

**How to apply:** See `discussion.md` → Data Verification Norm for the operational checklist. This doctrine is the top-level rule; `discussion.md` is the enforcement recipe.

## Adding New Doctrines

New doctrines get added here when a cross-cycle pattern becomes a rule. Each doctrine must:

1. Cite a concrete incident or pattern (not a hypothetical).
2. State the rule, the reason, and how to apply.
3. Define its scope boundary — what it does *not* cover.

Doctrines are small, reusable, and cited by plans and validation reports. They are not a wishlist.
