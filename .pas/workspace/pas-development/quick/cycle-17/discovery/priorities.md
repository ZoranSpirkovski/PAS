# Cycle 17 — Discovery: Orchestrator-Side Session Binding

## The recurrence (evidence)

Consumer transcript: `/home/zoran/projects/github.com/INTERS3CT-LLC/Tangled-Roots-V1/.pas/workspace/tangled-roots/phase-meta/sessions/pas-misrouted-and-migration-ts/status.yaml`

Observed state at the moment the Stop hook fired:

```
session_id: 680584a2          # original maintainer session (correct)
current_session: e6d3092e     # fresh, off-topic session (wrong)
sessions:
  - id: 9094b01b ...          # 5 entries marked "off-topic — user pivoted to ..."
  - id: 991ac66d ...
  - id: 13c458af ...
  - id: 45805bbb ... note: "off-topic content prompt; no PAS phases advanced"
  - id: db890ed1 ... note: "off-topic — user pivoted to /v2-agency-delivery PR #302..."
  - id: a56f86f4 ... note: "off-topic — user pivoted to /v2-agency-delivery PR #304..."
  - id: ff782e88 ... note: "off-topic — user pivoted to /v2-agency-delivery PR #306..."
  - id: e6d3092e ... note: "off-topic — user pivoted to /intake..."
```

The pattern is **self-reinforcing**: once one off-topic entry is logged, future fresh sessions look at the file, see precedent, and follow the same pattern.

## Cycle 16's fix is correct but insufficient

Verified in code at `plugins/pas/.claude-plugin/plugin.json` version `1.4.1`:

| File | Line | Behavior | Status |
|---|---|---|---|
| `pas-session-start.sh` | 42-66 | Refuses to write `current_session:` for fresh sessions; only refreshes on true reconnect (id already in `sessions:` list) | ✓ Correct |
| `verify-completion-gate.sh` | 36-47 | Sanity check: skips gate if resolved workspace's binding does not match live SESSION_ID | ✓ Correct |
| `lib/workspace.sh` | 27-38 | Pass 0 cross-field match on `current_session\|session_id` | ✓ Correct |

**These three fixes only protect against hook-side auto-bind.** The recurrence in Tangled-Roots-V1 happened *after* 1.4.1 was installed. So the binding was written by something else: the orchestrator (Claude) itself, or a consumer-side skill (`process-maintainer`, `/intake`).

## Why the orchestrator binds itself

The plugin's own docs encourage it. Three contributing pieces of text:

### 1. lifecycle.md L28 — "claims" is undefined

> When a skill or process **creates** or **claims** a workspace, it MUST write the session binding into status.yaml itself.

"Claim" is never defined. A skill author or orchestrator can reasonably interpret "claim" as "use the existing workspace because it's the one that's open." Nothing in the contract says **claim ≠ start a fresh session in a project where an in-progress workspace happens to exist**.

### 2. lifecycle.md L122 — false statement (regression from cycle 16)

> **Session tracking:** The `pas-session-start.sh` hook automatically writes `current_session` and appends to the `sessions` list when a session begins.

Post-1.4.1 this is no longer true — the hook only refreshes on reconnect. The doc still tells readers the hook auto-tracks. Skill authors reading this assume tracking is handled and may add their own writes "to be safe."

### 3. lifecycle.md L154-162 — Ad-Hoc Execution

> 1. If a workspace exists for the current cycle, use it — do not create a new one
> 2. Create lifecycle tasks for shutdown steps...

"For the current cycle" is vague. An orchestrator running off-topic work can read this as "the in-progress workspace I see is the current cycle, use it."

### 4. SessionStart hook output L75-99 — universal STARTUP

```
Whether running a formal PAS process or executing an ad-hoc plan, you MUST follow this lifecycle:

STARTUP (before any work):
1. Create workspace: mkdir -p .pas/workspace/{process}/{slug}/...
2. Write status.yaml with all phases as pending
3. Create Claude Code tasks for each phase AND for shutdown steps...
```

This block fires for *every* session, including fresh sessions that are about to do unrelated work. The wording "Whether running a formal PAS process or executing an ad-hoc plan, you MUST" is unconditional. Combined with the unbound-fresh-session message ("This session is NOT bound. To resume, invoke the matching skill") the orchestrator has two contradictory instructions:

- Universal: create a workspace and register your session
- Mismatch branch: you're not bound, invoke a skill to bind yourself

The path of least resistance is to register the session in the existing in-progress workspace and add an "off-topic" note when stopping.

## Root cause (one sentence)

Cycle 16 closed the hook-side binding loophole but left the **doctrine and human-readable instructions** still telling orchestrators and skills to register fresh sessions in any in-progress workspace they find — so the same misroute now happens via human/AI compliance with the docs instead of via auto-binding.

## What the fix must change

### Must (1.4.2)

1. **Doctrine — add the Phase Advancement Test.** Bind only if this session is about to advance a phase in *this* workspace. "Logging that a session existed in a project" is not a reason to bind. Existing `Workspace Binding Is Skill-Owned` doctrine extended.

2. **lifecycle.md — Session Binding Contract section.** Replace the word "claims" with a concrete definition. State explicitly: a fresh session that is *not* advancing any phase in an existing workspace MUST NOT modify that workspace's `status.yaml` (no `sessions:` append, no `current_session:` write, no "off-topic" notes added at stop time — leave it alone entirely).

3. **lifecycle.md — Session tracking line 122.** Rewrite to reflect 1.4.1+ behavior (hook only refreshes on reconnect; skill is responsible for the initial write).

4. **lifecycle.md — Ad-Hoc Execution.** Qualify "use existing workspace" with: only if the ad-hoc work directly continues that workspace's process. Otherwise create a new workspace or do nothing.

5. **SessionStart hook output.** STARTUP block becomes conditional on "you are about to start or advance a PAS process." Unbound-fresh-session branch wording escalated: "Do NOT register this session in `<path>/status.yaml`. Do NOT add an off-topic note at stop time. If your work is unrelated, this workspace stays unchanged."

6. **Hook test harness.** Add cases for the orchestrator-side binding scenario:
   - Given an in-progress workspace and a fresh SESSION_ID, simulate orchestrator writing `current_session: <fresh>` and appending to `sessions:` → verify the gate fires (current behavior, regression baseline).
   - After the doctrine/wording fix, no test code change needed; this is a behavioral fix not a code fix. But add an assertion that the hook output contains the new "DO NOT register" wording.

### Should (1.4.2 if quick, otherwise queue)

7. **Phase-mtime sanity check in `verify-completion-gate.sh`.** If no phase under `phases:` has had its `status:` updated during this session (rough check: status.yaml mtime older than session start, or no phase status moved from `pending` → anything else), skip the gate even if `current_session:` matches. Belt-and-suspenders against future cases where a skill *correctly* binds a session that then ends without doing phase work.

   **Risk:** mtime is fragile. A safer signal would be a session-scoped phase-write log, but that's a bigger change. Defer to brainstorm or later cycle if it's not trivially safe.

### Out of scope (file as separate framework signal)

8. **Proper PAS testing framework.** Per user direction — the recurrence shows hook-isolation tests cannot catch lifecycle/orchestrator behavior bugs. Needs end-to-end fixture tests, multi-worktree concurrency tests, skill-side contract tests. Filed as framework:pas issue at shutdown.

## Files in scope for cycle 17

- `plugins/pas/library/orchestration/doctrines.md` — extend `Workspace Binding Is Skill-Owned`
- `plugins/pas/library/orchestration/lifecycle.md` — Session Binding Contract, line 122, Ad-Hoc Execution
- `plugins/pas/hooks/pas-session-start.sh` — STARTUP block + unbound-branch wording
- `plugins/pas/hooks/tests/test-hooks.sh` — assertion on new wording
- (Optional) `plugins/pas/hooks/verify-completion-gate.sh` — phase-mtime check
- `plugins/pas/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version bump 1.4.1 → 1.4.2 (auto-bumped by `lib/bump-version.sh` on commit)
- `plugins/pas/hooks/changelog.md` + `plugins/pas/library/orchestration/changelog.md` — entries

## Open questions for product owner

1. **Phase-mtime gate hardening (#7) — yes or defer?** Trivial 5-line check, low risk. Defer if you'd rather see it land cleanly with the testing framework cycle.
2. **Should the SessionStart hook also emit a parseable `PAS_DO_NOT_REGISTER=1` line** alongside the English warning, so a future skill-creator process can lint against skills that touch foreign status.yaml? Cheap to add, gives the future testing-framework cycle a hook to lint against.
