# Cycle-15 Implementation Plan

**Issue:** [#125](https://github.com/ZoranSpirkovski/PAS/issues/125) — Architectural shift to marketplace-authoritative
**Owner gate:** Option B — stop at PR creation. No autonomous merge.
**Target branch:** feature branch off `dev` → PR against `main`.
**Plugin version target:** 1.3.3 → 1.4.0 (minor bump at cycle end — manual in bump script call, see §4).
**Scope snapshot:** 11 work items (P1–P11), ~8 commits, ~1.5k LoC net change (incl. `git mv` of pas-development), 4+ new tests (harness 117 → 121+).

---

## 0. Conventions for this plan

- **File paths are absolute-from-repo-root.** `plugins/pas/...`, `.pas/...`, `.claude/...`.
- **"Execution agent"** names the pas-development agent that owns the change in the Execution phase.
- **"LoC"** is approximate net-diff lines (including new tests and doc prose). Not used as a gate, only as a size signal.
- **Citations** use `file:line` with the line observed in today's tree. If the surrounding context changes during execution, agents re-verify the line before editing.

---

## 1. Work items

### P1 — Harden `${CLAUDE_PLUGIN_ROOT}` resolver

**Execution agent:** framework-architect.
**Files touched:**
- MODIFY `plugins/pas/hooks/lib/guards.sh` — replace the one-liner at `guards.sh:8-12` with a named function `resolve_claude_plugin_root()`. Call it from each hook's entry sequence (see below). The old line-11 export becomes the function's final line on success.
- MODIFY `plugins/pas/hooks/pas-session-start.sh:9-12` — insert `resolve_claude_plugin_root || exit 1` immediately after `source lib/guards.sh`.
- MODIFY `plugins/pas/hooks/pas-development-session-start.sh` — same insertion.
- MODIFY `plugins/pas/hooks/check-self-eval.sh:9-11` — same.
- MODIFY `plugins/pas/hooks/route-feedback.sh:8-10` — same.
- MODIFY `plugins/pas/hooks/verify-completion-gate.sh` — same (locate the `source` line, insert after).
- MODIFY `plugins/pas/hooks/verify-task-completion.sh:12-14` — same.
- MODIFY `plugins/pas/hooks/tests/test-hooks.sh` — append §4 test cases C10-1..C10-4 for the resolver (see §5).

**Resolver behavior (order):**
1. If `CLAUDE_PLUGIN_ROOT` is set AND `[ -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]` AND `[ -d "$CLAUDE_PLUGIN_ROOT/hooks" ]` → accept and return 0.
2. Else walk up from `${BASH_SOURCE[0]}` (the `lib/guards.sh` file's own location) up to 5 levels looking for the same markers. On first match, set `CLAUDE_PLUGIN_ROOT` and return 0.
3. Else scan `$HOME/.claude/plugins/cache/*/pas/*/` for any directory matching the markers. On first match, set and return 0.
4. Else emit `PAS hook: unable to resolve CLAUDE_PLUGIN_ROOT (tried env, walk-up, cache scan)` to stderr and return 2.

Calling convention: `resolve_claude_plugin_root || exit 1` — hooks fail-loud. SessionStart is the exception (non-blocking context injection); it uses `resolve_claude_plugin_root || exit 0` so a misconfigured plugin doesn't panic the host session.

**Diff size:** ~60 LoC resolver + 6 call-site edits ≈ 75 LoC.
**Depends on:** none.
**Must land before:** P3 (routing rewrite depends on a trustworthy `CLAUDE_PLUGIN_ROOT`), P5 smoke (fresh-session pas-development launcher uses the resolver), P6 (write-into-marketplace needs correct paths).

---

### P2 — `/pas:pas` detects marketplace + refuses outside

**Execution agent:** dx-specialist (prose/SKILL.md) with framework-architect for the resolver helper (paired).
**Files touched:**
- MODIFY `plugins/pas/skills/pas/SKILL.md` — add new **Marketplace Gate** section above the existing `## Project Convention` (line 10). Content described below.
- MODIFY `plugins/pas/hooks/lib/guards.sh` — add helper `resolve_marketplace_root()` (walks up from cwd looking for `.claude-plugin/marketplace.json`; echoes path or returns 1). Document that SKILL.md prose invokes `bash -c "source lib/guards.sh && resolve_marketplace_root"` from the skill body.
- MODIFY `plugins/pas/hooks/tests/test-hooks.sh` — add C11-1..C11-3 (walk-up found, walk-up not found, cwd-root match).

**New SKILL.md section (proposed wording, dx-specialist finalizes):**
```
## Marketplace Gate

PAS-the-skill only operates inside a marketplace repository — a git repo containing
`.claude-plugin/marketplace.json` at the root. If the current directory (walking up)
is not inside a marketplace, PAS MUST refuse to proceed.

Resolution:
1. Walk up from cwd looking for `.claude-plugin/marketplace.json`. If found, set
   `PAS_MARKETPLACE_ROOT` to that directory and proceed.
2. If not found, present three options via AskUserQuestion:
   (a) `cd` to an existing marketplace (list choices from `~/.claude/plugins/known_marketplaces.json`)
   (b) Bootstrap a new marketplace here (invoke `bootstrap-marketplace` skill — see P8)
   (c) Exit without doing anything

PAS-the-infrastructure (the hooks that catch feedback) is installed globally via
Claude Code's plugin system and runs everywhere — this gate applies ONLY to the
`/pas` entry-point skill, not to the hooks.
```

**Diff size:** ~25 LoC helper + ~40 LoC SKILL.md + tests ≈ 90 LoC.
**Depends on:** P1 (uses the shared guards.sh hardening cadence).
**Must land before:** P6 (create-process writes into marketplace — requires marketplace root), P8 (bootstrap gate references this).

---

### P3 — Marketplace-aware feedback routing

**Execution agent:** framework-architect.
**Files touched:**
- MODIFY `plugins/pas/hooks/route-feedback.sh` — rewrite `resolve_target_path()` (`route-feedback.sh:17-49`) and `route_signal()` (`route-feedback.sh:51-63`). Add a new helper `route_to_marketplace()` alongside existing `route_framework_signal()`.
- MODIFY `plugins/pas/hooks/lib/guards.sh` — add `resolve_origin_marketplace()` helper.
- MODIFY `plugins/pas/hooks/tests/test-hooks.sh` — add C12-1..C12-5 (see §5).

**`resolve_origin_marketplace()` behavior:**
Inputs: a target path like `skill:<name>` plus the current session's install context.
1. Check for an explicit `Plugin: <plugin>@<marketplace>` line in the signal block. If present, use that and look up `known_marketplaces.json[<marketplace>].installLocation` via `jq`.
2. Else: derive plugin identity from `$CLAUDE_PLUGIN_ROOT`. The path typically has the shape `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` or `~/.claude/plugins/marketplaces/<marketplace>/plugins/<plugin>/`. Extract `<marketplace>`, look up `installLocation`.
3. Output: `<installLocation>\t<plugin-name>` tab-separated. Return 1 on failure.

Concrete marketplace path verification (live data I can cite):
```
~/.claude/plugins/known_marketplaces.json contains:
  "pas-framework": { "installLocation": "/home/zoran/.claude/plugins/marketplaces/pas-framework", ... }
~/.claude/plugins/installed_plugins.json maps plugin IDs like `pas@pas-framework` → installPath.
```
So the expected writable destination for feedback under this model is:
`~/.claude/plugins/marketplaces/pas-framework/plugins/pas/processes/<process>/.../feedback/backlog/`.

**New `route_to_marketplace()` behavior:**
1. Call `resolve_origin_marketplace` to get `<installLocation>` and `<plugin-name>`.
2. Resolve the target artifact's relative path inside that plugin (reuse today's find-based resolution from `route-feedback.sh:26-48` but scoped to `<installLocation>/plugins/<plugin-name>/` as root, not `$CWD/.pas/processes`).
3. Construct filename with host-id (P4 format): `<date>-<host-id>-<source>-<signal-id>.md`.
4. `mkdir -p` + write + `git -C <installLocation> add <file>` + `git commit -m "Feedback: <signal-id>"`. No push — user pushes.

**Fallback chain:**
- If `resolve_origin_marketplace` fails → fall through to existing `route_framework_signal` with `source.repo` from plugin metadata.
- If `git commit` succeeds but `git add` fails or the marketplace isn't a git repo → write file only, skip commit, log.
- If `mkdir -p`/write fails (permissions) → stage at `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data}/pas/feedback-outbox/<date>-<host-id>-<source>-<signal-id>.md` + log to `<cwd>/.pas/workspace/feedback/warnings.log`.

**Backward-compat during transition:** keep `$CWD/.pas/processes/...` lookup as a **third-tier fallback** (after marketplace-route, before outbox). This preserves the cycle-14 behavior for any in-flight cycles that still have the old tree. Remove this tier in cycle-16 after pas-development has migrated.

**Diff size:** rewrite `route-feedback.sh` ~150 LoC (from 211 LoC today, ~50 net). New `resolve_origin_marketplace` ~40 LoC. Tests ~60 LoC ≈ 250 LoC.
**Depends on:** P1 (resolver), P4 (host-id for filenames).
**Must land before:** P9 sweep (upgrading skill checklist references the new routing behavior).

---

### P4 — Host-id in routed filenames

**Execution agent:** framework-architect (tiny change, pair with P3 commit).
**Files touched:**
- MODIFY `plugins/pas/hooks/lib/guards.sh` — add `resolve_host_id()` function.
- MODIFY `plugins/pas/hooks/route-feedback.sh:58-62` — `route_signal()` filename construction updated to include `<host-id>`.
- (Optional — only if trivially small) MODIFY `plugins/pas/hooks/pas-session-start.sh` — if host-id file missing and feedback enabled, create `<cwd>/.pas/workspace/host-id` with `basename "$CWD"`.

**`resolve_host_id()` behavior:**
1. If `<cwd>/.pas/workspace/host-id` exists → read it.
2. Else if `$HOME/.claude/pas-host-id` exists → read it (user-level default).
3. Else → `basename "$CWD"`. Also write this to `<cwd>/.pas/workspace/host-id` atomically so the next run is fast and stable.

**Filename format (new):** `<YYYY-MM-DD>-<host-id>-<source-basename>-<signal-id>.md`.
Example: `2026-04-20-PAS-framework-architect-99f211ea-OQI-01.md`.

**Diff size:** ~25 LoC + tests ≈ 40 LoC.
**Depends on:** none standalone; bundled with P3.
**Must land before:** P3's tests (filename assertions reference this format).

---

### P5 — pas-development migrates into the plugin tree

**Execution agent:** framework-architect (does `git mv`) + community-manager (CLAUDE.md + pr-management touch-ups).
**Ordering constraint:** this is a single atomic commit. `git mv` + launcher edit + CLAUDE.md edit + pr-management edit, all together.

**Files touched (in one commit):**
- MOVE `.pas/processes/pas-development/` → `plugins/pas/processes/pas-development/` via `git mv`. This preserves history on every nested file (agents/, skills/, modes/, process.md, overview.html, changelog.md, feedback/).
- MODIFY `.claude/skills/pas-development/SKILL.md` — the current launcher body says:
  ```
  Read `.pas/processes/pas-development/process.md` for the process definition.
  ```
  Update to:
  ```
  Read `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/process.md` for the process definition.
  Read the orchestration pattern from `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` as specified in the process.
  ```
  The Resume/Quick-cycle sub-sections (launcher lines near 30, 40, 46) already use `${CLAUDE_PLUGIN_ROOT}` — just sweep any `.pas/processes/pas-development/` → `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/`.
- MODIFY `.claude/CLAUDE.md` — the protected-path list at `CLAUDE.md:16` and `CLAUDE.md:44` mentions `.pas/processes/pas-development/`. Replace with `plugins/pas/processes/pas-development/`. Likewise update `CLAUDE.md:61` (pas-development feedback location) to reference `plugins/pas/processes/pas-development/feedback/backlog/`.
- MODIFY `.pas/processes/pas-development/agents/community-manager/skills/pr-management/SKILL.md` Step 6 — it lives around `pr-management/SKILL.md:101` (verified via grep). Update any path references that assumed pas-development lived under `.pas/processes/`.

**Migration semantics:**
- Workspace artifacts (`.pas/workspace/pas-development/cycle-*/`) **DO NOT MOVE**. Workspace is ephemeral, consumer-side. Only the process definition moves.
- Feedback backlogs under `plugins/pas/processes/pas-development/agents/*/skills/*/feedback/backlog/` move as part of the `git mv` — these are process-scoped durable signals (not session ephemera), and they should live with the process.
- The `.pas/processes/pas-development/feedback/backlog/` directory likewise moves.
- After migration, `.pas/processes/` on this repo is empty. Safe to remove the empty dir in the same commit (not required — but leaves the consumer tree clean).

**Smoke test (in-session, done by community-manager after the commit):**
```
# 1. Static check: grep for any remaining reference to the old path
grep -rn '\.pas/processes/pas-development' plugins/ .claude/ docs/ 2>/dev/null
# Expected: no results (workspace files/plans may still reference; they're historical).

# 2. Verify the launcher resolves the new path
cat .claude/skills/pas-development/SKILL.md | grep -E 'CLAUDE_PLUGIN_ROOT|processes/pas-development'

# 3. Verify new tree is complete
ls plugins/pas/processes/pas-development/
# Expected: agents/ changelog.md feedback/ modes/ overview.html process.md

# 4. Verify no in-flight cycle state was clobbered
ls .pas/workspace/pas-development/cycle-15/
# Expected: discovery/ planning/ feedback/ status.yaml (current cycle intact)
```

**A fresh-session invocation test** (actually running `/pas-development`) is **deferred to cycle-16** per the N/N+1 protocol codified in P10 (#113). We cannot validate a SessionStart-routed launcher change from within the same session that modified it.

**Diff size:** `git mv` itself is ~0 LoC net; launcher edit ~5 LoC; CLAUDE.md ~6 LoC; pr-management SKILL.md ~2 LoC ≈ 15 LoC + whatever renames show in `git status`.
**Depends on:** P1 (launcher uses `${CLAUDE_PLUGIN_ROOT}` — must be hardened first so the resolved path is trustworthy).
**Must land before:** nothing in-cycle — this is the dogfood hazard, so it goes **late** in the commit sequence to minimize mid-cycle surface area on a still-running process.

---

### P6 — `pas-create-process` / `pas-create-skill` write into the marketplace

**Execution agent:** framework-architect.
**Files touched:**
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process:295-307` — thin-launcher template. Change:
  ```bash
  Read `.pas/processes/${NAME}/process.md`
  ```
  to:
  ```bash
  Read `\${CLAUDE_PLUGIN_ROOT}/processes/${NAME}/process.md`
  ```
  And change the target resolution earlier in the script (the `TARGET=` computation — find it via grep) so `--base-dir` defaults to `<PAS_MARKETPLACE_ROOT>/plugins/<plugin>/` instead of `<cwd>/.pas/`. Pass `--plugin <name>` as a new optional flag; if the marketplace has only one plugin, infer it.
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md:94-104` — update the documented command line to reflect the new default target and the optional `--plugin` flag.
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill` — the sibling skill-creation script. Same treatment: default target is `<marketplace>/plugins/<plugin>/processes/<process>/agents/<agent>/skills/<skill>/` (or `<marketplace>/plugins/<plugin>/library/<skill>/` for library skills).
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/SKILL.md` — mirror SKILL.md doc update.
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent` — same (check the script exists; if not, skip this bullet — the skill delegates to pas-create-skill for agent-scaffolding).
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/SKILL.md` — mirror.

**Script changes detail:** add argument `--plugin <name>`; compute `DEFAULT_BASE_DIR` by invoking `resolve_marketplace_root` (sourced from `${CLAUDE_PLUGIN_ROOT}/hooks/lib/guards.sh`); error clearly if neither `--base-dir` nor an auto-detected marketplace is available.

**Diff size:** ~80 LoC per script × 2 + SKILL.md prose ≈ 200 LoC.
**Depends on:** P1, P2 (needs `resolve_marketplace_root`).
**Must land before:** P8 (bootstrap-marketplace's post-scaffold hook invokes `pas-create-process` to seed a first process).

---

### P7 — Consumer-side shrink

**Execution agent:** dx-specialist (mostly SKILL.md prose) + framework-architect (the bootstrap code path in pas-session-start).
**Files touched:**
- MODIFY `plugins/pas/skills/pas/SKILL.md:39-47` — the "First-Run Detection" block. Remove the `.pas/config.yaml` creation step. Keep `.pas/workspace/` creation. Update the prose to: "On first run, PAS creates `.pas/workspace/` lazily (on first skill invocation that writes to it)."
- MODIFY `plugins/pas/skills/pas/SKILL.md:49` (auto-migrate block) — legacy migration of `pas-config.yaml → .pas/config.yaml` remains for backward-compat but add a note that after this cycle, consumer-side `.pas/config.yaml` is DEPRECATED and will be removed in a future cycle after downstream consumers upgrade.
- MODIFY `plugins/pas/hooks/lib/guards.sh` — `guard_pas_project()` (`guards.sh:93-124`) today requires `.pas/config.yaml`. Relax to: project is valid if **either** `.pas/config.yaml` exists **or** `.pas/workspace/` exists. Exported `PAS_PROJECT_ROOT` behavior unchanged.
- MODIFY `plugins/pas/hooks/pas-session-start.sh:26` — the `feedback:` grep assumes `.pas/config.yaml` is present. Fall back to a plugin-level default (read from `${CLAUDE_PLUGIN_ROOT}/pas-config.yaml` which already has `feedback: enabled`, see `plugins/pas/pas-config.yaml:1`).
- MODIFY `plugins/pas/hooks/tests/test-hooks.sh` — update any test that constructs a `.pas/config.yaml` fixture to also cover the workspace-only variant.

**Settings migration:** the only real setting is `feedback: enabled/disabled`. Options:
- (a) Plugin-level default in `plugins/pas/pas-config.yaml` applies unless consumer overrides in `.pas/workspace/config.yaml`.
- (b) Keep consumer override path, just shift default resolution to plugin-first.

This plan picks **(a)** — simpler, fits "consumer only has workspace" principle. If a consumer needs to disable feedback, they write `.pas/workspace/config.yaml` with `feedback: disabled`.

**Diff size:** ~60 LoC across SKILL.md + guards.sh + session-start ≈ 80 LoC.
**Depends on:** none standalone. Should land alongside or after P2 (marketplace gate) for coherent UX.
**Must land before:** P9 (upgrading skill references the new config semantics).

---

### P8 — Bootstrap-marketplace skill

**Execution agent:** dx-specialist (skill prose) + framework-architect (scaffold logic).
**Files touched:**
- CREATE `plugins/pas/skills/bootstrap-marketplace/SKILL.md` — the invoked skill.
- CREATE `plugins/pas/skills/bootstrap-marketplace/scripts/scaffold-marketplace.sh` — the scaffold shell script.
- (no changes to pas-create-process — use it as-is once P6 lands).

**Bootstrap-marketplace SKILL.md structure:**
```yaml
---
name: bootstrap-marketplace
description: Scaffold a new user-controlled marketplace repository for PAS plugins.
---

## When to Use

Invoked by `/pas:pas`'s Marketplace Gate (P2) when cwd is not inside a marketplace
AND the user chooses "bootstrap here."

## Process

1. Confirm cwd is writable + not already a marketplace.
2. Run `bash ${CLAUDE_SKILL_DIR}/scripts/scaffold-marketplace.sh --name <marketplace-name> [--plugin <first-plugin>]`.
3. Report what was created.
4. Suggest next steps (register with `/plugin marketplace add .`, optional `gh repo create`).
```

**scaffold-marketplace.sh behavior:**
1. `[ -d .git ] || git init`.
2. Create `.claude-plugin/marketplace.json` with a starter entry:
   ```json
   {
     "name": "<marketplace-name>",
     "version": "0.1.0",
     "plugins": [
       { "name": "<first-plugin>", "version": "0.1.0", "source": "./plugins/<first-plugin>" }
     ]
   }
   ```
3. Create `plugins/<first-plugin>/.claude-plugin/plugin.json` with version 0.1.0.
4. Create `plugins/<first-plugin>/hooks/` with an empty `hooks.json` stub.
5. Create `plugins/<first-plugin>/skills/` empty.
6. Commit `Initial marketplace scaffold`.

**Diff size:** SKILL.md ~60 LoC + scaffold script ~120 LoC ≈ 180 LoC.
**Depends on:** P2 (the gate invokes this skill).
**Must land before:** nothing — leaf.

---

### P9 — Upgrading skill + cycle-12 residual sweep

**Execution agent:** dx-specialist.
**Files touched:**
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md:17-56` — expand the checklist. Add items:
  - **No `.pas/processes/` in consumer** (processes ship via plugins now).
  - **No `.pas/config.yaml` in consumer** (plugin-level default + workspace override per P7).
  - Update item 4 (library) to reference the already-shipped cycle-12 expectation.
- MODIFY `plugins/pas/library/orchestration/lifecycle.md:34, 103` — two instances of `.pas/library/self-evaluation/SKILL.md`. Replace with `${CLAUDE_PLUGIN_ROOT}/library/self-evaluation/SKILL.md`.
- MODIFY `plugins/pas/library/orchestration/hub-and-spoke.md:17, 29, 88, 131` — four instances of `.pas/library/...` → `${CLAUDE_PLUGIN_ROOT}/library/...`.
- MODIFY `plugins/pas/hooks/check-self-eval.sh:86` — `Format reference: .pas/library/self-evaluation/SKILL.md` → `Format reference: ${CLAUDE_PLUGIN_ROOT}/library/self-evaluation/SKILL.md`.
- MODIFY `plugins/pas/hooks/verify-completion-gate.sh:107` — same pattern.
- MODIFY `plugins/pas/hooks/verify-task-completion.sh:46` — same pattern.
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md:9, 99` — two instances.
- MODIFY `plugins/pas/processes/pas/agents/orchestrator/skills/applying-feedback/SKILL.md:19, 125` — adjust references.

**Note on the one exception:** `plugins/pas/hooks/tests/test-hooks.sh:728-729` asserts `.pas/library/` still exists post-migration in an explicit **legacy migration test**. Keep that test as-is — it's testing cycle-10's backward-compat migration behavior and the assertion is intentional.

**Diff size:** 13 files × small edits ≈ 60 LoC.
**Depends on:** P3 (routing semantics), P7 (config semantics).
**Must land before:** nothing — leaf sweep.

---

### P10 — Cycle-14 residuals to bundle

**Execution agent:** feedback-analyst (for the meta-rule), framework-architect (for the harness bump assertion).
**Files touched:**
- CREATE `plugins/pas/library/orchestration/doctrines.md` — new reference doc codifying cross-cycle operating rules. Initial content: the **N/N+1 protocol** (issue #113). Structure:
  ```
  # PAS Orchestration Doctrines
  ## N/N+1 Protocol (cycle-14 lesson)
    Any change to hook substrate (SessionStart, Stop, SubagentStop, TaskCompleted)
    or resolver logic (CLAUDE_PLUGIN_ROOT, .pas/ detection) MUST be validated from a
    fresh session in the following cycle. Validation inside the same cycle that
    modified the substrate is unreliable because the running session loaded the old
    version. Plan such cycles as N (ship the change) + N+1 (validate).
  ```
- MODIFY `plugins/pas/library/orchestration/lifecycle.md` — add a `## Doctrines` section at the end referencing the new doc.
- MODIFY `plugins/pas/hooks/tests/test-hooks.sh` — verify the harness count increases to the target. Not a test — just an assertion in CI that `PASS + FAIL == expected` at the end. Optional; skip if owner prefers the runtime count.
- CLOSE **#112** (test-count delta) on PR description after harness count check. No file change in the cycle itself — comment note in PR.
- **#114 (status-before-idle)** — if execution budget allows. Estimate: new task type `[PAS] Status check` added to the SessionStart heredoc (`pas-session-start.sh:86-93`). Defer if time-constrained; not a blocker.
- **#109 (SessionStart text leak)** — DEFER. No code change in P10. Re-evaluate post-cycle per priorities doc.

**Diff size:** ~30 LoC doctrines.md + ~5 LoC lifecycle.md reference + optional #114 ~10 LoC ≈ 45 LoC.
**Depends on:** none.
**Must land before:** none — can land in any commit slot.

---

### P11 — Umbrella issue management

**Execution agent:** community-manager.
**Action:** no code change. After PR is opened (but before asking owner to review), post a summary comment on issue #125 listing:
- Shipped: P1, P2, P3, P4, P5, P6, P7, P8, P9, P10 (partial).
- Deferred: #109, #114 (if cut), cross-marketplace dependency graph, `plugin.json` userConfig integration.
- PR link.

Explicitly **do not close #125** — it remains the umbrella.

P0 (issue backlog hygiene) — gated on owner approval. Defer to post-PR if owner greenlights. Not in the commit sequence.

**Diff size:** 0 LoC (comment only).
**Depends on:** PR creation (last step).

---

## 2. Dependencies between items

DAG (top = must-happen-first):

```
P1 (resolver hardening)
  ├── P2 (marketplace gate — uses guards.sh helper cadence)
  ├── P3 (routing — needs trustworthy CLAUDE_PLUGIN_ROOT)
  ├── P5 (pas-dev migration — launcher resolves via CLAUDE_PLUGIN_ROOT)
  └── P7 (consumer shrink — touches guard_pas_project)

P2 ──┬── P6 (create-process writes into marketplace — needs marketplace root)
     └── P8 (bootstrap gate references marketplace detection)

P4 ── P3 (host-id referenced in filename construction)

P3 ── P9 (upgrading skill documents routing)
P7 ── P9 (upgrading skill documents config semantics)

P10 — independent (doctrines + harness count + cycle-14 residuals)

P11 — last (after PR open)
```

No cycles. P1 is the root dependency for four items — it must land first.

---

## 3. Execution parallelism plan

Execution phase has four agents available: framework-architect, dx-specialist, feedback-analyst, community-manager.

### Wave 1 (serial, must be first)
- **P1** → framework-architect. Blocks every other P. Ship alone in commit C01.

### Wave 2 (parallel after P1)
- **P2** + **P7** → paired assignment: framework-architect owns guards.sh helpers; dx-specialist owns SKILL.md prose. Can commit as C02 (P2) and C03 (P7) independently; no shared file conflicts.
- **P4** → framework-architect (tiny — bundled into the P3 commit, not standalone).
- **P10** → feedback-analyst (doctrines.md is independent). Commit slot C04.

### Wave 3 (parallel after P2 + P4)
- **P3** → framework-architect. Large rewrite, commit C05. Needs P1 + P2 + P4.
- **P6** → framework-architect. Script edits, commit C06. Needs P1 + P2. Can land in parallel with P3 if executed by different agent-instances; otherwise serialize.
- **P8** → dx-specialist. New skill, commit C07. Needs P2 only — so could technically run in Wave 2, but waiting for P3 keeps the "bootstrap creates a marketplace that routes feedback correctly" story coherent.

### Wave 4 (serial, late)
- **P9** → dx-specialist. Sweep across 13 files. Touches files other P-items also edit, so must be after everything else. Commit C08.

### Wave 5 (the dogfood hazard)
- **P5** → framework-architect + community-manager paired. Commit C09. Placed LAST in the sequence (before version bump) to minimize cycle runtime on post-migration state. The migration invalidates any hook that was resolving from the old `.pas/processes/pas-development/` path — if it goes early, subsequent commits in this same session might route feedback wrongly.

### Wave 6 (packaging)
- **Version bump** — framework-architect runs `bash plugins/pas/hooks/lib/bump-version.sh` but replaces the auto-patch with a manual edit for the minor bump (1.3.3 → 1.4.0). Commit C10.
- **Changelog + PR** — community-manager writes `plugins/pas/CHANGELOG.md` entry for 1.4.0 (or updates the top-level changelog if that's the convention — verify against cycle-14's convention by reading `0955342`'s message). Commit C11. Then opens PR.

### Concrete agent dispatch (single execution session)

If Execution runs in one session with a hub-and-spoke pattern:

| Parallel group | Agent | Work | Commits |
|---|---|---|---|
| G1 | framework-architect | P1 | C01 |
| G2a | framework-architect | P4 prep (helper only) | (folded into C05) |
| G2b | dx-specialist | P2 SKILL.md + P7 SKILL.md | C02, C03 |
| G2c | feedback-analyst | P10 doctrines.md | C04 |
| G3a | framework-architect | P3 routing + P4 filename | C05 |
| G3b | framework-architect | P6 creation scripts | C06 |
| G3c | dx-specialist | P8 bootstrap-marketplace | C07 |
| G4 | dx-specialist | P9 sweep | C08 |
| G5 | framework-architect + community-manager | P5 migration | C09 |
| G6 | framework-architect | Version bump | C10 |
| G7 | community-manager | Changelog + PR | C11 + PR open |

If budget splits across sessions (priorities doc allows 2–3 sessions): boundary goes between G4 and G5 — i.e., all non-P5 work in session N, then the migration + packaging in session N+1. That way the migration gets its own "clean" session the way cycle-14 learned to do.

---

## 4. Commit sequence

Target: 11 commits. Each independently meaningful; each passes hook tests on its own.

| # | Title (commit message first line) | P-items | Files | LoC |
|---|---|---|---|---|
| C01 | `fix(hooks): harden CLAUDE_PLUGIN_ROOT resolver with validation + fail-loud` | P1 | guards.sh + 6 hooks + tests | ~75 |
| C02 | `feat(pas): marketplace gate for /pas skill` | P2 | guards.sh helper + skills/pas/SKILL.md + tests | ~90 |
| C03 | `feat(pas): relax consumer to workspace-only (deprecate .pas/config.yaml)` | P7 | SKILL.md + guards.sh + session-start + tests | ~80 |
| C04 | `docs(library): add orchestration doctrines (N/N+1 protocol)` | P10 | doctrines.md + lifecycle.md ref + (optional #114) | ~45 |
| C05 | `feat(hooks): marketplace-aware feedback routing with host-id filenames` | P3 + P4 | route-feedback.sh + guards.sh + tests | ~250 |
| C06 | `feat(pas): pas-create-process + pas-create-skill write into marketplace` | P6 | 2 scripts + 3 SKILL.md docs | ~200 |
| C07 | `feat(pas): bootstrap-marketplace skill` | P8 | skills/bootstrap-marketplace/ (new) | ~180 |
| C08 | `docs(pas): sweep .pas/library refs to ${CLAUDE_PLUGIN_ROOT}/library` | P9 | 13 files | ~60 |
| C09 | `refactor(pas): migrate pas-development into plugin tree (atomic)` | P5 | git mv + launcher + CLAUDE.md + pr-management | ~15 diff + rename block |
| C10 | `chore: bump version to 1.4.0` | — | plugin.json + marketplace.json | ~6 |
| C11 | `docs: add cycle-15 changelog entry (milestone 4: marketplace-authoritative)` | — | CHANGELOG.md or plugins/pas/CHANGELOG.md | ~30 |

**Version bump mechanism** (C10):
```bash
# bump-version.sh today auto-increments patch. We want a minor bump.
# Option A: call bump-version.sh three times (1.3.3 → 1.3.6 — wrong).
# Option B: manually edit both JSONs with jq, commit.

jq '.version = "1.4.0"' plugins/pas/.claude-plugin/plugin.json > /tmp/p.json && mv /tmp/p.json plugins/pas/.claude-plugin/plugin.json
jq '.metadata.version = "1.4.0" | .plugins[0].version = "1.4.0"' .claude-plugin/marketplace.json > /tmp/m.json && mv /tmp/m.json .claude-plugin/marketplace.json
```

Alternatively: extend `bump-version.sh` with a `--minor` flag as a separate micro-commit. Not worth the yak-shave this cycle; prefer the direct jq call in C10.

**Branch naming:** `feature/cycle-15-marketplace-authoritative`. Off `dev`. PR opened against `main` per project convention (cycle-14 pattern: PR #111 merged to main, then main merged back into dev per pr-management Step 6 — that Step 6 runs AFTER owner merges this PR, not in cycle-15).

---

## 5. Test plan

Current harness count: 117 (verified: `plugins/pas/hooks/tests/test-hooks.sh` per cycle-14 memory).
Target after cycle-15: **121+** (absolute minimum 121 from P1; 124 with P2; 129 with P3; 130+ with migration smoke).

### C10-1..C10-4 — P1 resolver tests (in C01 commit)

Append a new section to `test-hooks.sh` (before the trailing "Summary" block at the tail):

```
# ===== C10: resolve_claude_plugin_root =====

# C10-1: env set + valid (current repo layout)
CLAUDE_PLUGIN_ROOT=$(pwd)/plugins/pas \
  bash -c "source $HOOKS_DIR/lib/guards.sh && resolve_claude_plugin_root && echo \"OK: \$CLAUDE_PLUGIN_ROOT\"" \
  | grep -q "OK: .*plugins/pas" && PASS=...

# C10-2: env empty + walk-up succeeds (unset env, source from real lib)
env -u CLAUDE_PLUGIN_ROOT \
  bash -c "source $HOOKS_DIR/lib/guards.sh && resolve_claude_plugin_root && echo \"OK: \$CLAUDE_PLUGIN_ROOT\"" \
  | grep -q "OK:" && PASS=...

# C10-3: env wrong + walk-up succeeds
CLAUDE_PLUGIN_ROOT=/nonexistent \
  bash -c "source $HOOKS_DIR/lib/guards.sh && resolve_claude_plugin_root && echo \"OK: \$CLAUDE_PLUGIN_ROOT\"" \
  | grep -q "OK:" && PASS=...

# C10-4: all strategies fail → non-zero exit + stderr
env -u CLAUDE_PLUGIN_ROOT HOME=/tmp/no-claude-here \
  bash -c "source /tmp/fake-guards.sh && resolve_claude_plugin_root" 2>&1 \
  | grep -q "unable to resolve" && FAIL path...
```

Note: C10-4 requires an isolated fake guards.sh copy in `/tmp` (so walk-up from that copy doesn't find the real plugin). Pattern already used by the migration tests at the tail of test-hooks.sh.

### C11-1..C11-3 — P2 marketplace-root tests (in C02 commit)

- C11-1: cwd inside marketplace → helper echoes absolute path to `.claude-plugin/marketplace.json` dir.
- C11-2: cwd outside any marketplace → helper returns non-zero.
- C11-3: cwd IS the marketplace root → helper echoes cwd.

### C12-1..C12-5 — P3 marketplace-aware routing tests (in C05 commit)

- C12-1: signal with `Plugin: pas@pas-framework` → file written under `~/.claude/plugins/marketplaces/pas-framework/plugins/pas/.../feedback/backlog/`. (Test uses a TEST_HOME fixture, not actual $HOME.)
- C12-2: signal without Plugin line + `CLAUDE_PLUGIN_ROOT` set to plugin path → derived plugin+marketplace → correct file destination.
- C12-3: marketplace not registered in known_marketplaces.json → fallback to `gh issue create` path (mock `gh`).
- C12-4: write permission denied → file appears in `${CLAUDE_PLUGIN_DATA}/pas/feedback-outbox/` + warnings.log entry.
- C12-5: filename includes host-id per P4 format (`<date>-<host-id>-<source>-<signal-id>.md`).

### P5 migration smoke (in C09 commit — **static only**, no fresh-session)

No new entries in test-hooks.sh needed (hook behavior doesn't depend on pas-development location). Smoke is the bash snippet in §1/P5. Run manually by community-manager after committing C09.

Harness total: **117 + 4 (C10) + 3 (C11) + 5 (C12) = 129 tests.** Comfortably above 121 target.

If budget allows, add:
- 1 test for P7: `guard_pas_project` accepts workspace-only project (no config.yaml). → 130.
- 1 test for P4: `resolve_host_id` fallback order. → 131.

---

## 6. Rollback plan

Git-native rollback for commits that didn't reach `main`:

### Per-commit rollback (mid-execution)

- **C01 (P1)**: `git revert <sha>`. Restores the old one-liner resolver. All downstream commits still work because they only added call-sites — the function body just becomes the defensive one-liner again. Simple.
- **C02-C04**: `git revert <sha>`. Isolated additions. No cross-file fallout.
- **C05 (P3 routing)**: highest-risk revert. The rewrite touches live hook paths. `git revert <sha>` restores cycle-14 behavior. Verify test suite passes after revert before deciding to re-attempt.
- **C06-C08**: `git revert <sha>`. Isolated.
- **C09 (P5 migration)**: **hardest to rollback.** `git revert` creates a reverse rename, which git handles but needs human-eyes verification. Alternative: `git reset --hard HEAD~1` (destructive — only safe if nothing pushed). Safest sequence if we need to back out:
  1. `git revert <C09-sha>` on the feature branch.
  2. Verify `.pas/processes/pas-development/` is restored.
  3. Verify `plugins/pas/processes/pas-development/` is empty/absent.
  4. Verify CLAUDE.md protected-path language matches the restored location.
  5. Run `bash plugins/pas/hooks/tests/test-hooks.sh` to confirm harness passes.

### Whole-cycle rollback (if PR is rejected)

- PR open against `main` means the feature branch is visible. If owner rejects, we close the PR without merge. The feature branch remains on `dev`'s history.
- If owner wants to keep parts but not others: cherry-pick forward into a cycle-16 branch. This is why the commit sequence is designed to be independently meaningful per commit.

### pas-development mid-cycle failure

If C09 breaks the pas-development launcher and the cycle is still running:
- The currently-open session's loaded process definition doesn't care about filesystem — it's already loaded. Continue the current cycle to completion using the in-memory definition.
- Next session (cycle-16) uses the new location or reverts if still broken.
- DO NOT attempt to re-invoke `/pas-development` from within the C09-breaking session as a "test" — that's exactly the dogfooding hazard we're trying to avoid.

### Outbox-orphaned signals (from P3 failure)

If P3 lands and an outbox write triggers during cycle-15 (because some path in `known_marketplaces.json` doesn't resolve as expected), signals end up at `~/.claude/plugins/data/pas/feedback-outbox/`. These are NOT LOST — they're just not routed. A separate "drain outbox" operation (future skill, not this cycle) can replay them once paths resolve.

---

## 7. Risks flagged during planning

These are risks NOT in the priorities doc that I found while sizing the work:

### PR1 — `$CLAUDE_PLUGIN_ROOT` walk-up ambiguity

During P1 planning, I realized the walk-up-from-`BASH_SOURCE` strategy assumes the hooks are invoked from a path containing `hooks/lib/guards.sh`. This is true for the current plugin layout. But if Claude Code ever changes the hook-invocation cwd (some harness quirk), the walk-up could fail on an otherwise-valid plugin.

**Mitigation:** C10-2 test explicitly exercises the walk-up path. Also the cache-scan fallback covers this.

### PR2 — `git mv` in a worktree

`.pas/workspace/pas-development/cycle-15/` is the active workspace for THIS cycle. `git mv .pas/processes/pas-development/` in the same commit should not touch workspace. Verified: they're sibling subtrees. But if any tool or hook writes into `.pas/processes/pas-development/` during the rename window (there shouldn't be one, but worth flagging), the write races with the mv.

**Mitigation:** C09 is near-last in the commit sequence. Verify workspace dir is quiescent before running `git mv`. Optionally: `git mv` runs in a distinct orchestrator turn, not in a subagent, so the write-window is narrow.

### PR3 — `installed_plugins.json` shape evolves

Today's schema: `{ version: 2, plugins: { "<plugin>@<marketplace>": [ { scope, projectPath?, installPath, ... } ] } }`. If Claude Code bumps this to `version: 3` with a different shape, `resolve_origin_marketplace` breaks.

**Mitigation:** `resolve_origin_marketplace` checks `.version` and no-ops (returns 1) on unknown schema. Falls back to the GitHub-issue route. Log the mismatch.

### PR4 — Multi-plugin marketplaces in P6

A marketplace may host multiple plugins (`plugins/pas/`, `plugins/foo/`). `pas-create-process` needs to know which plugin to write into. If auto-detection picks wrong, the process lands in the wrong plugin.

**Mitigation:** when marketplace has >1 plugin, `pas-create-process` REQUIRES `--plugin <name>`. Error clearly otherwise. No auto-magic.

### PR5 — CHANGELOG location convention

Memory notes "docs: add hooks changelog with cycle 14 / M3 entry" (commit `0955342`). So there's a hooks-specific changelog at `plugins/pas/hooks/changelog.md`. But there's also `plugins/pas/library/` changelog, various per-process changelogs, and the top-level one.

**Mitigation:** community-manager reads `0955342` to match style and decides the target file. Probably both hooks/changelog.md (for hook-touching changes C01/C05) AND plugins/pas/CHANGELOG.md (for the overall 1.4.0 cycle summary).

### PR6 — Test isolation for C12 (routing to real marketplace)

C12-1 would, if not sandboxed, write into the user's actual `~/.claude/plugins/marketplaces/pas-framework/` on test run. That's pollution.

**Mitigation:** all C12 tests use `TEST_HOME=$(mktemp -d)` and set `HOME=$TEST_HOME`; construct a fake `known_marketplaces.json` inside it. Same approach cycle-14 tests use for workspace fixtures.

### PR7 — Scope check against cycle-14 session length

Cycle-14 was 6.4 hours, 11 commits. Cycle-15 is also 11 commits but includes a larger `git mv` and more new files (bootstrap-marketplace skill is meaningful LoC). Realistic estimate: 6-8 hours. Priorities doc already says "2-3 implementation sessions" — this is not news, but the planner confirms it.

**Mitigation:** the G4/G5 session boundary (described in §3) is the natural split point if Execution pauses.

---

## 8. Verification plan

Cycle-15 is an **Option B** cycle: stop at PR. Cycle-16 validates live behavior.

### In-cycle (cycle-15) — mandatory

- [ ] `bash plugins/pas/hooks/tests/test-hooks.sh` returns 0 with pass count ≥ 121 (target 129). Run before every commit past C01; run at the end before opening PR.
- [ ] Static: `grep -rn '\.pas/library/' plugins/pas/` shows no instances except the migration-test assertion at `test-hooks.sh:728-729`.
- [ ] Static: `grep -rn '\.pas/processes/pas-development' plugins/ .claude/` shows no results after C09.
- [ ] Static: `grep -rn '\${CLAUDE_PLUGIN_ROOT}/processes/pas-development' .claude/skills/pas-development/` shows at least one match.
- [ ] `plugins/pas/.claude-plugin/plugin.json` version == `1.4.0`. Same for `.claude-plugin/marketplace.json` (`.metadata.version` and `.plugins[0].version`).
- [ ] `status.yaml` for cycle-15 reflects completed phases at the right moments; `current_session` recorded.
- [ ] PR opens cleanly against `main` with a clear description of shipped/deferred items.

### In-cycle — best-effort (can't fully validate in-session)

- [ ] Manually run `bash plugins/pas/hooks/route-feedback.sh < fixture.json` with a mocked `$HOME` fixture directory. Inspect the output path. Not a fresh-session test (still same-process loaded), but catches gross errors in the rewrite.
- [ ] Manually invoke `bash plugins/pas/hooks/lib/guards.sh` functions directly in a subshell. Sanity check exported vars.

### Post-cycle (cycle-16) — deferred per N/N+1 doctrine

- [ ] **Fresh session** invokes `/pas-development` from a clean shell. Confirm launcher resolves `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/process.md` successfully.
- [ ] **Fresh session** inside a **consumer-only** project (no `.pas/config.yaml`) invokes a feedback-emitting skill. Confirm `route-feedback.sh` routes to the marketplace clone.
- [ ] **Fresh session** runs `/pas:pas` from a non-marketplace cwd. Confirm it presents the three-option gate (P2).
- [ ] **Fresh session** runs `/pas:pas` → "bootstrap here" → confirms scaffold (P8) produces a valid marketplace.
- [ ] Route-feedback integration: open a new signal targeting a skill, verify the backlog file lands under `~/.claude/plugins/marketplaces/pas-framework/plugins/pas/...`.
- [ ] SessionStart hook loads context without crashing after the migration (tests the resolver from a production-like session).

---

## 9. Out of scope (explicit)

- Migration of downstream consumer repos (dacforge, etc.) — per priorities doc non-goals.
- Renaming `/pas:pas` → `/pas:manage` — explicitly deferred per owner constraint.
- `plugin.json` `userConfig` integration for host-config — deferred (ecosystem-analyst Opp-3).
- Any cross-marketplace dependency resolution (single-marketplace assumption holds).
- Automated push of feedback commits to marketplace remote — local commits only.
- Bootstrap-marketplace push to remote — user-driven.
- Full removal of consumer `.pas/config.yaml` — still tolerated this cycle for backward-compat; removal in a future cycle once downstream have migrated.
- Extending `bump-version.sh` to support minor/major bumps — punt; direct `jq` call is fine.

---

## 10. Gate checklist for Planning → Execution

Before moving from Planning to Execution:

- [ ] Owner has approved priorities v2 (done per team-lead message).
- [ ] This plan is acknowledged by owner (pending this deliverable).
- [ ] Workspace state: `.pas/workspace/pas-development/cycle-15/planning/implementation-plan.md` exists and passes owner's sniff test.
- [ ] Execution team assignments match agent capabilities (verified in §3).
- [ ] Rollback plan covers the high-risk commits (C05, C09) — yes (§6).
- [ ] Test plan articulates harness-count delta (117 → 129 target) — yes (§5).
- [ ] N/N+1 protocol documented for cycle-16 follow-up — yes (P10, §8).

**Ready for Execution.**

---

*End of cycle-15 implementation plan.*
