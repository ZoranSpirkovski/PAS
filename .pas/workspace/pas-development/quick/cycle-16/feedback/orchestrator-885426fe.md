# Orchestrator Self-Evaluation — Cycle 16 (Session 885426fe)

## What went well

The cluster collapsed cleanly. Six issues (#173, #174, #162, #160, #156, #155) were all rooted in one substrate-level race: hooks misroute to the wrong workspace under concurrent worktree/session runs, surfacing as resolver field-name brittleness, SessionStart auto-binding fresh sessions, and Stop hook mtime fallback misroutes — plus two unrelated route-feedback path bugs in #156. Five surgical fixes addressed all six issues without introducing per-symptom patches.

Test harness grew from 130 → 142 (+8 new C16 tests, +4 reframed session-start tests asserting the new no-auto-bind semantics). N/N+1 doctrine respected: cycle-16 ships static + harness validation, with a deliberate live-behavior checklist prepared for cycle 17.

## Signals

[OQI-01]
Target: framework:pas
Degraded: PAS hook substrate misroutes phase-completion verification under concurrent workspace presence
Root Cause: Cycle-16's workspace artifacts live on `dev`, the plugin code on the `feature/cycle-16-concurrency-fix` branch. When the orchestrator was on the feature branch (after pushing it), the cycle-16 workspace directory was absent (it's a dev-only artifact per CLAUDE.md). The `verify-task-completion.sh` hook then resolved to `cycle-15/` (most-recent mtime fallback) and demanded release-phase output_files — including a literal PR URL `https://github.com/ZoranSpirkovski/PAS/pull/150` listed as a path. The hook treats URLs as filesystem paths.
Evidence: Verbatim hook stderr at task #5 completion attempt — "Workspace: /home/zoran/projects/github.com/ZoranSpirkovski/PAS/.pas/workspace/pas-development/cycle-15 / Missing output_files: https://github.com/ZoranSpirkovski/PAS/pull/150". Resolved by switching back to `dev` where cycle-16 status.yaml is present.
Fix: Two improvements (file separately):
1. The `output_files:` schema documented in lifecycle.md should explicitly accept either a filesystem path OR a URL, with the hook treating URL-shaped values as already-satisfied (PR URL is a deliverable that does not exist on disk by design).
2. `verify-task-completion.sh` should refuse to validate a phase against a workspace whose `current_session:` does not match the orchestrator's session id — same defense the cycle-16 fix added to `verify-completion-gate.sh`. The C5 sanity check should be promoted to a shared helper used by both Stop and TaskCompleted hooks.
Priority: MEDIUM
Route: github-issue

[OQI-02]
Target: framework:pas
Degraded: Workspace artifacts split across branches creates dogfooding hazard for hook resolution
Root Cause: CLAUDE.md mandates that `.pas/workspace/` artifacts go on `dev` directly while plugin changes go on a feature branch. This means the orchestrator's workspace can vanish from the working tree mid-session when switching branches for normal git workflow (push feature, write PR). Hooks that scan for workspaces from the current working tree see stale state.
Evidence: Same incident as OQI-01 — cycle-16 status.yaml was on dev, orchestrator was on feature branch, hook resolved to cycle-15.
Fix: Either (a) document this hazard explicitly in CLAUDE.md / pr-management Step 7 ("after pushing the feature branch, switch back to dev for shutdown — feature branch lacks workspace artifacts"), or (b) commit workspace artifacts to BOTH branches (smaller change, easier to forget), or (c) make the hooks resolve workspaces relative to git's main worktree always (hardest, most correct). Option (a) is cheapest and matches existing pr-management patterns.
Priority: LOW
Route: github-issue

[OQI-03]
Target: framework:pas
Degraded: Quick-cycle process status.yaml schema does not include `output_files:` per phase, but `verify-task-completion.sh` enforces them
Root Cause: My cycle-16 status.yaml lists `output_files:` for each phase (following the lifecycle.md schema), but the quick cycle process.md doesn't require this — it lists phase outputs in the description text. The TaskCompleted hook only enforces what's in `output_files:`. So if I had omitted `output_files:`, the enforcement would silently no-op.
Evidence: `lifecycle.md:80-81` documents `output_files:` as part of the canonical status.yaml schema; the quick cycle process.md does not explicitly require it.
Fix: Either make `output_files:` mandatory in the lifecycle.md schema (already documented as such — but enforcement is opt-in), or add a self-check at workspace creation time that warns if a phase has no `output_files:`.
Priority: LOW
Route: github-issue

## What I'd do differently

Nothing structural. The directive ("FIX THE FUCKING CONCURRENCY ISSUE") was clear once disambiguated to the issue cluster, the planning was tight, and the execution avoided scope creep. The dogfood incident at shutdown was instructive — it proved that the cycle-16 fixes are needed by surfacing the same bug in the orchestrator's own workflow.

One minor regret: I bundled C3 + C4 into one commit (SessionStart no-auto-bind plus PAS_WORKSPACE_MISMATCH parseable line) instead of two as planned. They share file context and would have been awkward to split, but a reviewer skimming `git log` will see a slightly larger commit than the plan suggested.
