# Implementation Plan: Cycle 4

## Overview

Six work items across three priority tiers. All plugin changes (`plugins/pas/`) go into a feature branch for PR. Version syncs, library mirrors, and changelog updates commit directly to dev.

**Important discovery**: The root `CHANGELOG.md` (written during v1.3.0 planning) already claims `--base-dir` was added to scripts and the hooks step was restored in creating-processes. Neither was actually implemented. The changelog entry is aspirational. This cycle implements the changes the changelog promised.

---

## Task List

### Task 1: Fix check-self-eval.sh Agent-Specificity Bug (P2a)

**Owner**: Framework Architect
**Dependencies**: None
**Parallelizable**: Yes (independent of all other tasks)

**Problem**: The SubagentStop hook at `plugins/pas/hooks/check-self-eval.sh` lines 46-51 checks for ANY .md file in the feedback directory:

```bash
FEEDBACK_COUNT=$(find "$FEEDBACK_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
if [ "$FEEDBACK_COUNT" -gt 0 ]; then
  exit 0  # Self-eval found
fi
```

If agent A writes feedback, agent B passes the check without writing anything.

**Changes**:

1. **`plugins/pas/hooks/check-self-eval.sh`** (lines 46-51): Replace the generic .md count with an agent-specific check. Look for files matching `*${AGENT_ID}*` pattern. The naming convention is `{agent-name}.md` or `{agent-name}-{session_id}.md`. The check should be:
   ```bash
   # Primary check: agent-specific feedback file
   if find "$FEEDBACK_DIR" -maxdepth 1 -name "${AGENT_ID}*.md" -o -name "*-${AGENT_ID}*.md" 2>/dev/null | grep -q .; then
     exit 0  # Agent-specific self-eval found
   fi
   ```

2. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md`** (lines 69-74): Update the embedded script example to match the deployed behavior. The reference currently shows the old `exit 0` + warning log version. Replace the entire embedded `check-self-eval.sh` code block with the corrected agent-specific version that uses `exit 2` (blocking).

**Verification**:
- Script still exits 0 for PAS config guard (no pas-config.yaml)
- Script still exits 0 for feedback disabled guard
- Script exits 0 when a file matching `${AGENT_ID}*.md` exists in feedback dir
- Script exits 2 with SELF-EVALUATION MISSING on stderr when no matching file exists
- Script exits 0 when transcript contains signal patterns (secondary check preserved)

---

### Task 2: Add --base-dir to Generation Scripts (P2b)

**Owner**: Framework Architect
**Dependencies**: None
**Parallelizable**: Yes (independent of all other tasks)

**Problem**: All 3 scripts hardcode `processes/` as the base directory relative to CWD. When run from the project root during testing, `rm -rf` cleanup can destroy real processes. In v1.2.0 development, this destroyed 53 files from `processes/pas-development/`.

**Changes**:

1. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process`**:
   - Add `BASE_DIR=""` variable (line ~12)
   - Add `--base-dir) BASE_DIR="$2"; shift 2 ;;` to argument parser (line ~43 area)
   - Add `--base-dir DIR` to usage text as optional flag: "Base directory for output (default: current directory)"
   - Change line 101 `TARGET="processes/${NAME}"` to `TARGET="${BASE_DIR:+${BASE_DIR}/}processes/${NAME}"`
   - Change line 264 `LAUNCHER_DIR=".claude/skills/${NAME}"` to `LAUNCHER_DIR="${BASE_DIR:+${BASE_DIR}/}.claude/skills/${NAME}"`

2. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent`**:
   - Add `BASE_DIR=""` variable (line ~12)
   - Add `--base-dir) BASE_DIR="$2"; shift 2 ;;` to argument parser
   - Add `--base-dir DIR` to usage text
   - Change line 123 `TARGET="processes/${PROCESS}/agents/${NAME}"` to `TARGET="${BASE_DIR:+${BASE_DIR}/}processes/${PROCESS}/agents/${NAME}"`

3. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill`**:
   - Add `BASE_DIR=""` variable (line ~12)
   - Add `--base-dir) BASE_DIR="$2"; shift 2 ;;` to argument parser
   - Add `--base-dir DIR` to usage text
   - Change line 84 `TARGET="processes/${PROCESS}/agents/${AGENT}/skills/${NAME}"` to `TARGET="${BASE_DIR:+${BASE_DIR}/}processes/${PROCESS}/agents/${AGENT}/skills/${NAME}"`

4. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md`** (step 6): Update the example command in the Generate Process section to show `--base-dir` as an optional flag.

5. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/SKILL.md`** (step 5): Update the example command to show `--base-dir`.

6. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/SKILL.md`** (step 4): Update the example command to show `--base-dir`.

**Verification**:
- `pas-create-process --base-dir /tmp/test-pas --name test ...` creates `/tmp/test-pas/processes/test/`
- `pas-create-process --name test ...` (no --base-dir) still creates `processes/test/` in CWD (backward compatible)
- Same for pas-create-agent and pas-create-skill
- `rm -rf /tmp/test-pas` safely cleans up without touching project root

---

### Task 3: Framework Feedback Routing in route-feedback.sh (P3a)

**Owner**: Framework Architect
**Dependencies**: None
**Parallelizable**: Yes (independent of all other tasks)

**Problem**: `route-feedback.sh` lines 74-77 return empty for `framework:*` targets with a comment saying the hook doesn't handle GitHub issue creation. Framework signals with `Route: github-issue` are silently dropped.

**Changes**:

1. **`plugins/pas/hooks/route-feedback.sh`** (lines 74-77): Replace the empty `framework)` case with logic that uses `gh issue create` to file the signal as a GitHub issue. The implementation:
   ```bash
   framework)
     # Route framework feedback as GitHub issues
     # Only route if gh CLI is available and signal has Route: github-issue
     echo "__FRAMEWORK_SIGNAL__"
     ;;
   ```
   Actually, the routing needs to happen at a higher level because `resolve_target_path` returns a path, not an action. Better approach: add a new function `route_framework_signal()` and call it from the main routing logic when the target type is `framework`. The function should:
   - Extract signal content (the full signal block)
   - Extract signal ID for the issue title
   - Use `gh issue create --repo ZoranSpirkovski/PAS --title "[Feedback] {signal_id}: {one-line summary}" --body "{full signal block}"`
   - Guard: only route if `gh auth status` succeeds (user is authenticated)
   - Guard: only route if the signal block contains `Route: github-issue`
   - Log success/failure to `$CWD/feedback/framework-routing.log`

   Concrete changes to `route-feedback.sh`:
   - Add `route_framework_signal()` function after `route_signal()` (around line 97)
   - In `parse_and_route_signals()`, when `resolve_target_path` returns empty AND `current_target` starts with `framework:`, call `route_framework_signal` instead of logging a warning
   - The `framework)` case in `resolve_target_path` should return the literal string `__framework__` instead of empty, so the caller can distinguish "framework target" from "unknown target"

2. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md`**: Update the embedded `route-feedback.sh` script to reflect the new framework routing capability.

**Verification**:
- Signals with `Target: framework:pas` and `Route: github-issue` get filed as GitHub issues
- Signals with `Target: framework:pas` WITHOUT `Route: github-issue` are logged but not filed
- If `gh` is not available or not authenticated, the signal is preserved (logged, not lost) and a warning is written
- Non-framework signals route identically to before (no regression)

---

### Task 4: Restore Hooks Step in creating-processes SKILL.md (P3b)

**Owner**: DX Specialist (documentation-focused change)
**Dependencies**: None
**Parallelizable**: Yes (independent of all other tasks)

**Problem**: Step 8.5 "Determine Hooks" was dropped during v1.2.0 simplification. The workflow goes directly from step 7 (Create Agents) to step 8 (Verify Against Source Material) with no hook consideration.

**Changes**:

1. **`plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md`**: Insert a new step between current steps 7 and 8. Renumber step 8 to step 9. The new step 8:

   ```markdown
   ### 8. Determine Hooks

   Evaluate whether the process needs lifecycle hooks:

   - **Feedback hooks**: If `pas-config.yaml` has `feedback: enabled`, the PAS plugin's hooks handle self-eval and routing automatically. No per-process hooks needed for feedback.
   - **Domain-specific guards**: Does any phase need pre-conditions checked before tool use? (e.g., block destructive commands, validate inputs)
   - **Lifecycle automation**: Should anything happen automatically at session start, agent stop, or task completion?

   If hooks are needed, use `creating-hooks/SKILL.md` from the same skills directory as this skill.

   Most processes do not need custom hooks — the PAS plugin's global hooks cover feedback lifecycle. Only add hooks when the process has domain-specific automation needs.
   ```

**Verification**:
- SKILL.md has 9 steps (was 8)
- Step 8 is "Determine Hooks"
- Step 9 is "Verify Against Source Material" (renumbered from 8)
- The hooks step references creating-hooks skill correctly
- The step correctly notes that PAS global hooks handle feedback already

---

### Task 5: Sync Version Manifests to 1.3.0 (P4)

**Owner**: Community Manager (release/metadata focused)
**Dependencies**: Tasks 1-4 should be complete first (so the version bump reflects actual changes)
**Parallelizable**: No (should run after other tasks complete)

**Problem**: Three version sources disagree:
- `CHANGELOG.md`: 1.3.0
- `plugins/pas/.claude-plugin/plugin.json`: 1.2.0
- `.claude-plugin/marketplace.json`: 1.1.0 (both metadata.version and plugins[0].version)

**Changes**:

1. **`plugins/pas/.claude-plugin/plugin.json`** (line 4): Change `"version": "1.2.0"` to `"version": "1.3.0"`

2. **`.claude-plugin/marketplace.json`** (line 8): Change `"version": "1.1.0"` to `"version": "1.3.0"`

3. **`.claude-plugin/marketplace.json`** (line 14): Change `"version": "1.1.0"` to `"version": "1.3.0"`

**Scope note**: `plugin.json` is under `plugins/pas/` so it goes in the PR. `marketplace.json` is at root, so it commits directly to dev.

**Verification**:
- `grep -r '"version"' plugins/pas/.claude-plugin/ .claude-plugin/` shows 1.3.0 everywhere
- `CHANGELOG.md` already says 1.3.0 (no change needed)

---

### Task 6: Hook Validation (P1 — Passive)

**Owner**: QA Engineer (in Validation phase)
**Dependencies**: All other tasks
**Parallelizable**: No (this is tracked by running the cycle itself)

This is not a code change. By running this cycle through all 4 phases with proper workspace lifecycle, we validate hook enforcement. The QA engineer should document in the validation report:

- Did SessionStart hook inject PAS context? (Check conversation start)
- Did SubagentStop hook fire for each agent? (Check agent feedback files)
- Did TaskCompleted hook enforce [PAS] task deliverables?
- Did Stop hook block exit without feedback?
- Can issues #11 and #12 be closed?

---

## File Inventory

### Plugin Files (PR-worthy, under `plugins/pas/`)

| File | Action | Task |
|------|--------|------|
| `plugins/pas/hooks/check-self-eval.sh` | Modify | T1 |
| `plugins/pas/hooks/route-feedback.sh` | Modify | T3 |
| `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md` | Modify | T2, T4 |
| `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process` | Modify | T2 |
| `plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/SKILL.md` | Modify | T2 |
| `plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent` | Modify | T2 |
| `plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/SKILL.md` | Modify | T2 |
| `plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill` | Modify | T2 |
| `plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md` | Modify | T1, T3 |
| `plugins/pas/.claude-plugin/plugin.json` | Modify | T5 |

### Dev-Only Files (commit directly to dev)

| File | Action | Task |
|------|--------|------|
| `.claude-plugin/marketplace.json` | Modify | T5 |
| `CHANGELOG.md` | No change needed | — (already has 1.3.0 entry) |
| `library/` mirrors | Sync after PR merge | Post-PR |

### Files NOT Changed

| File | Why |
|------|-----|
| `plugins/pas/hooks/hooks.json` | No structural changes to hook registrations |
| `plugins/pas/hooks/pas-session-start.sh` | No changes needed |
| `plugins/pas/hooks/verify-task-completion.sh` | No changes needed |
| `plugins/pas/hooks/verify-completion-gate.sh` | No changes needed |
| `plugins/pas/library/orchestration/*.md` | No pattern changes this cycle |
| `plugins/pas/library/self-evaluation/SKILL.md` | No changes needed |

---

## Scope Boundary

### PR Scope (feature branch -> main)

All files under `plugins/pas/`. This includes:
- Hook script fixes (T1, T3)
- Generation script --base-dir (T2)
- creating-processes hooks step restoration (T4)
- plugin.json version bump (T5)
- Reference doc sync (T1, T3)

**PR title**: "Fix agent feedback specificity, add script safety, framework routing, restore hooks step"

### Dev-Only Scope (commit to dev directly)

- `marketplace.json` version sync (T5)
- Workspace artifacts (this plan, discovery docs, etc.)
- Library mirror syncs (post-merge)

---

## Execution Parallelism

```
Tasks 1, 2, 3, 4 — all independent, can run in parallel
         |
         v
      Task 5 — version sync (after 1-4 complete)
         |
         v
      Task 6 — validation (passive, during whole cycle)
```

**Optimal dispatch**: Send T1, T2, T3, T4 to agents simultaneously. T5 after all return. T6 is tracked throughout.

### Agent Assignments

| Task | Agent | Rationale |
|------|-------|-----------|
| T1 (check-self-eval fix) | Framework Architect | Hook architecture, shell scripting |
| T2 (--base-dir scripts) | Framework Architect | Script architecture, backward compat |
| T3 (framework routing) | Framework Architect | Hook architecture, gh CLI integration |
| T4 (hooks step restore) | DX Specialist | Skill documentation, user-facing guidance |
| T5 (version sync) | Community Manager | Release metadata, manifest management |
| T6 (hook validation) | QA Engineer | Validation phase |

Note: T1, T2, T3 all go to Framework Architect. These can still be parallelized if the Framework Architect uses subagents for independent file changes. Alternatively, T2 could go to a second agent since it's purely additive and touches different files than T1/T3 (scripts vs hooks).

---

## Risk Assessment

### Risk 1: `gh issue create` in route-feedback.sh fails silently

**Impact**: Framework signals are lost.
**Mitigation**: The script must check `gh auth status` before attempting. If gh is unavailable, preserve the signal (don't delete the .md file, don't mark as .routed) and log a clear warning. The signal survives for the next session.

### Risk 2: --base-dir breaks existing usage in skills

**Impact**: Creating-processes/agents/skills skills reference the scripts. If --base-dir changes default behavior, existing skill workflows break.
**Mitigation**: --base-dir is purely optional. When omitted, scripts behave identically to before (generate relative to CWD). No default changes.

### Risk 3: Agent-specific check in check-self-eval.sh is too strict

**Impact**: `agent_id` might not match the filename pattern agents actually use.
**Mitigation**: The check uses glob patterns (`${AGENT_ID}*.md` and `*-${AGENT_ID}*.md`) to match both `{name}.md` and `{name}-{session_id}.md` conventions. Also preserves the transcript fallback check. If the agent_id is "unknown" (field not available), fall back to the current behavior (any .md).

### Risk 4: CHANGELOG.md already claims changes that haven't been made

**Impact**: Confusing — users may think features exist that don't. The changelog says --base-dir and hooks step already shipped in 1.3.0.
**Mitigation**: After implementing the actual changes, the changelog becomes accurate. No changelog edit needed — it was written as a plan, and this cycle implements the plan. Add a note in the validation report that the CHANGELOG.md was aspirational and is now accurate.

### Risk 5: pas-feedback-hooks.md reference sync creates merge conflicts

**Impact**: Two tasks (T1 and T3) both modify `pas-feedback-hooks.md`.
**Mitigation**: T1 modifies the check-self-eval.sh section. T3 modifies the route-feedback.sh section. These are different sections of the file. If both agents write the full file, assign T1 to update only its section and T3 to update only its section, or have one agent do both reference updates at the end.

**Resolution**: Framework Architect handles T1 and T3, so the same agent updates both sections of `pas-feedback-hooks.md` — no conflict.
