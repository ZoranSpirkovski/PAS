---
agent: community-manager
deliverable: PR scaffolding for Milestone 3 — Hook Safety & Stability
cycle: 14
status: ready-for-execution
depends-on:
  - framework-architect: hook fixes landed on dev
  - dx-specialist: docs/skills updates landed on dev
  - feedback-analyst: signal markings landed on dev
---

# PR Scaffolding — Cycle 14, Milestone 3

This artifact contains everything needed to cut the PR once the other three
agents have committed their work to `dev`. It is independent of their outputs:
title, body, branch name, issue-close templates, and a step-by-step runbook
that follows `pr-management/SKILL.md`.

## Branch name

```
fix/m3-hook-safety-stability
```

Rationale: per `pr-management` Step 2, branch name reflects the primary change
— here the milestone-3 grouping (P0 hook bugs that break sessions and derail
subagents).

## PR title

```
Fix Milestone 3: hook safety & stability (P0 session/subagent crashes)
```

68 characters — under the 70-char cap from `pr-management` Quality Checks.

## PR body

```markdown
## Summary

Milestone 3 of the 44-issue triage roadmap. Fixes the P0 hook bugs that
break sessions and derail subagents.

- `check-self-eval.sh`: fix `[: 0\n0: integer expression expected` crash
  from multi-line `grep -c` output (closes #55, #56)
- `pas-session-start.sh`: fix `CLAUDE_PLUGIN_ROOT: unbound variable`
  crash; fix crash on missing `instance` field in `status.yaml`
  (closes #54, #57, #64)
- Hook scoping: stop SubagentStop/SessionStart/system-reminder hooks
  from firing on non-PAS subagents (closes #38, #67, #68)
- `verify-task-completion.sh`: target the correct workspace when
  multiple process instances exist (closes #52)
- Hook scripts warn on malformed `status.yaml` instead of silently
  degrading (closes #58)
- PAS framework signals route to the framework repo, not to product
  repos where PAS is a consumer (closes #59)
- SubagentStop no longer elides the subagent's text response when
  writing self-eval (closes #71)
- Worktree contract: cwd-relative path resolution, silent disable when
  not in a PAS workspace, completion-gate deadlock fix (closes #70)

Hook test harness extended from 60 to ≥75 tests covering each fix.

## Test plan

- [ ] `bash plugins/pas/hooks/tests/test-hooks.sh` — all tests pass
      (≥75 tests)
- [ ] Spawn a generic Explore subagent inside an active PAS workspace
      and confirm it returns findings (not a self-eval file) — covers
      #38, #67, #68
- [ ] Run a session in a git worktree; write
      `.pas/workspace/.../feedback/orchestrator-{sid}.md`; exit cleanly
      — covers #70 findings 1–4
- [ ] Run a session with `status.yaml` missing the `instance` field;
      hook logs a warning rather than crashing — covers #54, #58
- [ ] Run a session with `CLAUDE_PLUGIN_ROOT` unset; session-start hook
      degrades gracefully — covers #64
- [ ] Confirm `framework:pas` signals from a session in a downstream
      consumer repo are routed to ZoranSpirkovski/PAS, not the
      consumer's repo — covers #59
```

## pr-management runbook (this cycle)

Execute in order after framework-architect, dx-specialist, and feedback-analyst
have committed their changes to `dev`.

### Step 0: Bump version

```bash
bash plugins/pas/hooks/lib/bump-version.sh
```

Expected: `plugins/pas/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` move from 1.3.2 → 1.3.3.

### Step 1: Two commits on dev

```bash
# Plugin commit (the only thing that goes into the PR)
git add plugins/pas/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        plugins/pas/hooks/check-self-eval.sh \
        plugins/pas/hooks/pas-session-start.sh \
        plugins/pas/hooks/verify-task-completion.sh \
        plugins/pas/hooks/verify-completion-gate.sh \
        plugins/pas/hooks/lib/guards.sh \
        plugins/pas/hooks/lib/workspace.sh \
        plugins/pas/hooks/hooks.json \
        plugins/pas/hooks/tests/ \
        plugins/pas/library/self-evaluation/SKILL.md
git commit -m "Fix M3: hook safety & stability — session/subagent crashes (v1.3.3)"

# Dev artifacts commit
git add .pas/workspace/pas-development/cycle-14/ \
        .pas/processes/pas-development/ \
        .pas/feedback/
git commit -m "Cycle-14 dev artifacts: M3 hook safety triage and execution"

git push origin dev
```

Adjust the file list above if framework-architect / dx-specialist touch
additional plugin files; the rule is **plugin files + marketplace.json in
commit 1, everything else in commit 2**.

### Step 2: Feature branch off main

```bash
git checkout main && git pull origin main
git checkout -b fix/m3-hook-safety-stability main
git cherry-pick <plugin-commit-sha-from-step-1>
```

If conflict (modify/delete on files new to main): `git add <files> &&
git cherry-pick --continue --no-edit`.

### Step 3: Verify plugin-only diff

```bash
git diff main --stat
```

Expected: every file under `plugins/pas/` or `.claude-plugin/`. If anything
else appears, abort and fix.

### Step 4: Create PR

```bash
git push -u origin fix/m3-hook-safety-stability
gh pr create --base main \
  --title "Fix Milestone 3: hook safety & stability (P0 session/subagent crashes)" \
  --body "$(cat <<'EOF'
[paste the PR body block from above]
EOF
)"
```

### Step 5: Clean up after merge

After product owner merges:

```bash
git branch -d fix/m3-hook-safety-stability
```

### Step 6: Merge main back into dev

```bash
git checkout dev
git fetch origin main
git merge origin/main --no-ff -m "Merge main into dev after PR #<N>"

# MANDATORY verification — do not skip
test -f .pas/processes/pas-development/process.md && echo "OK: process.md" || echo "MISSING: process.md"
test -d .pas/library/ && echo "OK: library/" || echo "MISSING: library/"
test -d .pas/workspace/ && echo "OK: workspace/" || echo "MISSING: workspace/"
```

If any path is MISSING, restore from `HEAD~1` and commit immediately
(see `pr-management` Step 6). This guard exists because dev-only
directories have been deleted twice in past cycles.

## Issue-close comments

After PR merges, comment on each closed issue with the PR link and a one-line
fix summary. Format per `gh-engagement` resolution rules: explain what was
done, link the PR, do NOT close the issue (product owner closes).

### #38 — system-reminder hooks derail subagents

```
Fixed in #<PR>. SessionStart, SubagentStop, and system-reminder hooks
now scope to PAS subagents only — generic Explore/Plan/etc agents
return findings without writing self-eval files. Hook scoping in
`plugins/pas/hooks/hooks.json` plus guard logic in `lib/guards.sh`.
```

### #52 — verify-task-completion checks wrong workspace

```
Fixed in #<PR>. `verify-task-completion.sh` now resolves the workspace
from the active session ID (via `status.yaml.current_session`) instead
of picking the most recent workspace by mtime — so multiple concurrent
process instances no longer collide.
```

### #54 — SessionStart crashes on missing `instance` field

```
Fixed in #<PR>. `pas-session-start.sh` now warns and degrades gracefully
when `status.yaml` is missing the `instance` field, rather than aborting
the session start. See also #58 for the broader malformed-yaml handling.
```

### #55 — `check-self-eval.sh` integer comparison failure

```
Fixed in #<PR>. The `grep -c` invocation that produced multi-line output
("0\n0") has been replaced with a single-integer count (`wc -l < file`
with explicit numeric coercion). The `[ ... -gt ... ]` comparison no
longer crashes with "integer expression expected".
```

### #56 — SubagentStop hook reliability (umbrella)

```
Resolved in #<PR> via the constituent fix #55. The umbrella signal is
covered when `check-self-eval.sh` no longer crashes before delivering
its message.
```

### #57 — SessionStart hook reliability (umbrella)

```
Resolved in #<PR> via the constituent fixes #54, #58, #64. The umbrella
signal is covered when SessionStart no longer crashes on missing fields,
unset env vars, or malformed yaml.
```

### #58 — hooks should warn on malformed `status.yaml`

```
Fixed in #<PR>. Hook scripts now log a warning to
`.pas/feedback/warnings.log` and degrade gracefully when `status.yaml`
is missing required fields or fails to parse, instead of silently
dropping the hook's effect.
```

### #59 — framework signals must not file on product repos

```
Fixed in #<PR>. `framework:pas` signals now route to
ZoranSpirkovski/PAS regardless of which repo the session is running in.
Routing logic centralized in the message-routing library skill.
```

### #64 — `pas-session-start.sh` `CLAUDE_PLUGIN_ROOT` unbound

```
Fixed in #<PR>. `pas-session-start.sh` no longer assumes
`CLAUDE_PLUGIN_ROOT` is set; falls back to relative path resolution from
the script's own location when the env var is unset.
```

### #67 — SubagentStop fires for non-PAS subagents

```
Fixed in #<PR> alongside #38, #68. Hook matchers in
`plugins/pas/hooks/hooks.json` now check whether the subagent is part
of an active PAS process before firing, so generic subagents are not
affected.
```

### #68 — SessionStart hijacks subagents

```
Fixed in #<PR> alongside #38, #67. The SessionStart hook no longer
emits the PAS routing prompt to subagents that aren't part of an
active PAS workflow.
```

### #70 — worktree contract

```
Fixed in #<PR>. Worktree contract now codified:
- `PAS_PROJECT_ROOT` resolves cwd-relative for worktrees
  (lib/guards.sh)
- Hooks silently disable when run outside a PAS workspace
  (guard_pas_project)
- `verify-completion-gate.sh` no longer deadlocks when phases are
  marked `completed` (deadlock fix)
- Self-evaluation skill documents the cwd-relative path contract
- Test harness extended with worktree scenarios
```

### #71 — SubagentStop elides subagent text response

```
Fixed in #<PR>. SubagentStop hook now writes the self-eval file as a
side effect without consuming or replacing the subagent's text
response. Caller receives the agent's actual output unchanged.
```

## Quality-check pre-flight

Before running Step 4 (`gh pr create`), confirm:

- [ ] `git diff main --stat` lists ONLY files under `plugins/pas/` or
      `.claude-plugin/`
- [ ] `plugins/pas/.claude-plugin/plugin.json` and
      `.claude-plugin/marketplace.json` both show new version
- [ ] PR title under 70 chars
- [ ] PR body contains "closes #N" for each of the 13 issues
- [ ] No "Co-Authored-By", no Claude/Anthropic attribution anywhere in
      commits, branch name, PR title, PR body, or issue comments
      (project memory: "no reason to advertise my tools")
- [ ] After PR merge: Step 6 runs and the three `test -d` checks all
      print "OK"

## Notes for the orchestrator

- This scaffolding does NOT execute any git or `gh` commands. The actual
  PR is cut in the Release phase (task #5), not in Execution.
- The 13 issue numbers come from `hey-claude-lets-implement-silly-crown.md`
  and have been verified against `gh issue list` (all 13 are open as of
  2026-04-16).
- If any of the 13 issues turn out to be out-of-scope after the technical
  agents finish their work, drop the corresponding "closes #N" line and
  the matching issue-close comment, but keep the rest of the PR intact.
- If additional issues end up being fixed as side effects, add them to
  the PR body and append matching close comments below.
