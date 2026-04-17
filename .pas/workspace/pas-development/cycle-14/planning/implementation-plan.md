# Cycle 14 Implementation Plan — Milestone 3 (Hook Safety & Stability)

**Inputs:** `discovery/priorities.md`, `discovery/ecosystem-analyst-perspective.md`, `discovery/dx-specialist-perspective.md`, `discovery/framework-architect-perspective.md`.
**PR scope:** `plugins/pas/` + `.claude-plugin/marketplace.json` (auto-bumped). All `.pas/` artifacts (workspace, feedback, planning) committed directly to `dev`.
**Test target:** ≥ 75 tests in `plugins/pas/hooks/tests/test-hooks.sh` (up from 60).

---

## 0. Sub-issue numbering for #70

community-manager files 6 sub-issues against the original #70 in the release phase. This plan adopts the **finding numbers** from the original issue (1–10) so we can revise to actual sub-issue numbers once filed. The four findings shipped this cycle:

- **#70-F1** — `PAS_PROJECT_ROOT` resolution
- **#70-F2** — silent-disable from worktrees
- **#70-F4** — completion-gate deadlock + absolute-path diagnostic
- **#70-F7** — SubagentStop scoping (overlaps #67/#68; absorbed into commit 5)

Deferred: F3 (atomic status.yaml — pairs with #52 follow-up); F5 (generator → M5); F6 (self-eval skill rewrite → M5); F8/F9/F10 (M7).

---

## 1. Commit list

Eleven commits in dependency order. Numbered `C01`–`C11`. Each is a self-contained reversible unit (see §5 rollback plan).

| # | Title | Files | Issues closed | Depends on | Parallel-with |
|---|---|---|---|---|---|
| **C01** | `lib/guards.sh`: defensive defaults + `resolve_pas_project_root` | `lib/guards.sh` | #64, #70-F1 | — | — |
| **C02** | `pas-session-start.sh`: tolerate missing fields, warn loudly | `pas-session-start.sh` | #54, #58 | C01 | C03, C09, C10 |
| **C03** | `check-self-eval.sh`: fix `grep -c` integer comparison | `check-self-eval.sh` | #55 | C01 | C02, C09, C10 |
| **C04** | `lib/workspace.sh`: session-id-first workspace resolution | `lib/workspace.sh`, all 4 hooks (read-side) | #52, #70-F3 (partial) | C01 | C09, C10 |
| **C05** | Hook scoping for non-PAS subagents | `lib/guards.sh`, `check-self-eval.sh`, `pas-session-start.sh` | #38, #67, #68, #71, #70-F7, **cycle-13 OQI-02** | C01, C04 | C09, C10 |
| **C06** | `verify-completion-gate.sh`: absolute paths in diagnostics, worktree-safe | `verify-completion-gate.sh` | #70-F4, #70-F2 | C01, C04 | C09, C10 |
| **C07** | `route-feedback.sh`: enforce `framework_signal_repo` constant + audit log | `route-feedback.sh`, `pas-config.yaml` | #59 | C01 | C09, C10 |
| **C08** | `verify-task-completion.sh`: enforce phase `output_files` checkpoint | `verify-task-completion.sh`, `library/orchestration/lifecycle.md` | #49 | C04 | C09, C10 |
| **C09** | `applying-feedback/SKILL.md`: AskUserQuestion + routing-clarity edits | `processes/pas/agents/orchestrator/skills/applying-feedback/SKILL.md`, `.../changelog.md` | #30, #40, #41 | — | C02–C08 |
| **C10** | Test harness expansion (≥ 75 tests, worktree fixture, agent_type fixtures) | `tests/test-hooks.sh`, `tests/fixtures/worktree-setup.sh` | — | follows each commit's own tests | — |
| **C11** | Version auto-bump | `plugin.json`, `marketplace.json` | — | C01–C10 land first | — |

Release-phase admin (community-manager, not commits): close #31, #33, #56, #57, #61, #66 with `closes-via #N` comments after PR merges. `bump-version.sh` runs on commit (per cycle-12 cycle-13 memory) so C11 is mechanical.

---

## 2. Per-commit detail

### C01 — `lib/guards.sh` defensive defaults + `resolve_pas_project_root`

**Why first:** every other hook sources `guards.sh`. Foundation.

**`plugins/pas/hooks/lib/guards.sh`:**
- Add at top (before any function), so every script that sources us inherits the default:
  ```bash
  : "${CLAUDE_PLUGIN_ROOT:=$(cd "${BASH_SOURCE[0]%/*}/../.." 2>/dev/null && pwd || echo "")}"
  ```
- Add new `resolve_pas_project_root()` per ecosystem-analyst's algorithm (§3 of `ecosystem-analyst-perspective.md`):
  - Trust `${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}` as candidate
  - Walk up from candidate searching for `.pas/config.yaml`
  - Fallback to `git rev-parse --show-toplevel` (NOT `--git-common-dir`) when running inside a worktree
  - Return non-zero if no PAS root found (caller decides what to do)
- Add `safe_grep_field()` helper to make `grep | head | awk` patterns crash-resistant under `set -u`/`pipefail`:
  ```bash
  safe_grep_field() { local f="$1" k="$2"; grep "^${k}:" "$f" 2>/dev/null | head -1 | awk '{print $2}' || true; }
  ```
- Modify `guard_pas_project()`: after the existing `$CWD/.pas/config.yaml` check, fall back to `resolve_pas_project_root` and reset `PAS_CONFIG`. Export `PAS_PROJECT_ROOT` so downstream guards can use it.
- Modify `guard_active_workspace()`: build `WORKSPACE_DIR` from `$PAS_PROJECT_ROOT/.pas/workspace`, not `$CWD/.pas/workspace`. (This change makes #70-F2's silent-disable bug go away — a worktree session resolves to the main repo's `.pas/`.)

**Tests added (5):**
- T-C01-1: `CLAUDE_PLUGIN_ROOT` unset + plugin install layout → defensive default fires; no crash
- T-C01-2: `resolve_pas_project_root` from cwd containing `.pas/config.yaml` → returns cwd
- T-C01-3: `resolve_pas_project_root` from a deep subdirectory → walks up, returns project root
- T-C01-4: `resolve_pas_project_root` from a git worktree dir (no `.pas/`) → falls back to `--show-toplevel`, returns main worktree root
- T-C01-5: `resolve_pas_project_root` from `/tmp` (not a git repo, no PAS) → returns non-zero

### C02 — `pas-session-start.sh` graceful display

**`plugins/pas/hooks/pas-session-start.sh`** (lines 92–104):
- Replace the three brittle pipelines with `safe_grep_field` helper from C01:
  ```bash
  TOP_STATUS=$(safe_grep_field "$ACTIVE_STATUS" status)
  PROCESS_NAME=$(safe_grep_field "$ACTIVE_STATUS" process)
  INSTANCE=$(safe_grep_field "$ACTIVE_STATUS" instance)
  ```
- Add `MISSING_FIELDS` accumulator per dx-specialist's §2 template; default `INSTANCE` to `basename "$ACTIVE_WORKSPACE"`, `TOP_STATUS` to `unknown`.
- Print the dx-specialist warning block (verbatim, see `dx-specialist-perspective.md` §2) when `MISSING_FIELDS` is non-empty. Always continue (exit 0).

**Tests added (3):**
- T-C02-1: status.yaml missing `instance:` → exits 0, stdout contains "Missing required fields: instance"
- T-C02-2: status.yaml missing `instance:` AND `status:` → exits 0, INSTANCE defaults to dirname, status shows "unknown"
- T-C02-3: complete status.yaml → no warning, normal display

### C03 — `check-self-eval.sh` `grep -c` fix

**`plugins/pas/hooks/check-self-eval.sh`** (line 38):
- Replace:
  ```bash
  SIGNAL_COUNT=$(grep -cE '\[(PPU|OQI|GATE|STA)-[0-9]+\]' "$AGENT_TRANSCRIPT" 2>/dev/null || echo 0)
  ```
- With:
  ```bash
  SIGNAL_COUNT=$(grep -cE '\[(PPU|OQI|GATE|STA)-[0-9]+\]' "$AGENT_TRANSCRIPT" 2>/dev/null) || SIGNAL_COUNT=0
  ```
- Replace the existing "SELF-EVALUATION MISSING" stderr block with dx-specialist's rewrite from §2 (file path + opt-out instructions + format reference link).

**Tests added (2):**
- T-C03-1: transcript with zero signal patterns → exits 0 cleanly (no integer-comparison crash); `SIGNAL_COUNT` recorded as `0` not `"0\n0"`
- T-C03-2: transcript with one PPU-01 signal → exits 0 cleanly (signal detected, no block needed)

### C04 — `lib/workspace.sh` session-id-first resolution

**`plugins/pas/hooks/lib/workspace.sh` `find_active_workspace_status`:**
- New signature: `find_active_workspace_status "$workspace_dir" "${session_id:-}"`.
- New Pass 0 (only if `session_id` non-empty): scan all `status.yaml` files; pick the one whose `current_session:` field matches `$session_id`. If found, return.
- Existing Pass 1 (in_progress + most recent mtime) and Pass 2 (any + most recent mtime) become fallbacks.

**All callers** (`lib/guards.sh:guard_active_workspace`):
- Read `SESSION_ID` from the parsed JSON in `guard_parse_input` and pass it through:
  ```bash
  ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR" "${SESSION_SHORT:-}") || return 1
  ```
- `verify-task-completion.sh` and `verify-completion-gate.sh` get the corrected workspace automatically because they call `guard_active_workspace`.

**Tests added (4):**
- T-C04-1: two sibling workspaces, one matches `current_session: abcd1234` → resolver picks the matching one even if the other is more recent
- T-C04-2: no `current_session` field anywhere → falls back to mtime (back-compat with PAS 1.x)
- T-C04-3: `session_id` empty in input → falls back to mtime (back-compat with sessions that don't propagate IDs)
- T-C04-4: matching workspace has status `pending` (not in_progress) → still picked (session-id beats status filter)

### C05 — Hook scoping for non-PAS subagents

This is the highest-blast-radius commit. All 4 derail bugs share root cause: hooks treat any subagent as a PAS-process agent.

**`plugins/pas/hooks/lib/guards.sh`** add helper:
```bash
guard_agent_in_active_process() {
  local agent_type="$1"
  [ -z "$agent_type" ] && return 1
  [ "$agent_type" = "unknown" ] && return 1
  guard_active_workspace "$2" || return 1
  local pas_agents
  pas_agents=$(grep '^\s*agent:' "$ACTIVE_STATUS" 2>/dev/null | awk '{print $2}' | sort -u)
  echo "$pas_agents" | grep -qx "$agent_type"
}
```

**`plugins/pas/hooks/check-self-eval.sh`:**
- After `guard_parse_input`, parse `AGENT_TYPE`:
  ```bash
  AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
  ```
- Insert: `guard_agent_in_active_process "$AGENT_TYPE" "$SCRIPT_DIR" || exit 0` before `guard_feedback_enabled`.
- Result: non-PAS subagents (Explore, general-purpose, claude-code-guide, etc.) skip the entire hook silently.
- Soften the blocking message per #71: when `last_assistant_message` is substantive (>200 chars and does not match a small set of summary patterns like "Self-evaluation written"), exit 0 with a stderr note rather than blocking. Heuristic implementation:
  ```bash
  LAST_MSG_LEN=$(echo "$LAST_MSG" | wc -c)
  if [ "$LAST_MSG_LEN" -gt 200 ] && ! echo "$LAST_MSG" | grep -qiE '^(self-evaluation|no issues|written\.)'; then
    # Substantive response present — log warning, do not block
    exit 0
  fi
  ```
  Read `LAST_MSG` from `.last_assistant_message` payload field (confirmed in ecosystem-analyst report).

**`plugins/pas/hooks/pas-session-start.sh`:**
- After `guard_parse_input`, check whether this SessionStart event represents a subagent context. The CC docs confirm `agent_id` is in SessionStart input for v2.1.69+ (per project memory). Pattern:
  ```bash
  AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
  if [ -n "$AGENT_ID" ] && [ "$AGENT_ID" != "null" ]; then
    # Subagent context — emit minimal/no PAS lifecycle injection
    exit 0
  fi
  ```
- This kills the heredoc injection at lines 63–88 for subagents — solves #38 and #68 root cause.

**Cycle-13 OQI-02 (self-eval before idle shutdown):** rolled in here. The softened `check-self-eval.sh` heuristic plus the `agent_type` whitelist mean orchestrator-spawned PAS agents that idle-stop without explicit shutdown still get blocked, while Explore/Plan/general-purpose subagents do not. No additional code beyond what's above; just record OQI-02 as resolved-by-bundle.

**Tests added (8):**
- T-C05-1: `agent_type: "Explore"`, active PAS workspace, no feedback file → SubagentStop exits 0 silently (non-PAS passthrough)
- T-C05-2: `agent_type: "framework-architect"` (defined in active process.md), no feedback file → SubagentStop exits 2 with blocking message (PAS scoping retained)
- T-C05-3: `agent_type: "framework-architect"`, feedback file present → SubagentStop exits 0
- T-C05-4: `agent_type: ""` empty (back-compat) → falls back to existing behavior
- T-C05-5: SessionStart with non-empty `agent_id` → stdout empty/minimal (no PAS lifecycle text injected)
- T-C05-6: SessionStart with empty `agent_id` (orchestrator) → full PAS lifecycle text injected
- T-C05-7: `last_assistant_message` >200 chars, no summary keywords, missing feedback → exits 0 (substantive response preserved)
- T-C05-8: `last_assistant_message` = "Self-evaluation written. No issues detected." (short summary) → exits 2 (block — that summary is the bug we're fixing)

### C06 — `verify-completion-gate.sh` absolute paths + worktree-safe diagnostics

**`plugins/pas/hooks/verify-completion-gate.sh`:**
- After `guard_active_workspace`, compute and use absolute paths in all diagnostic messages:
  ```bash
  ABS_FEEDBACK_DIR=$(cd "$FEEDBACK_DIR" && pwd)
  ABS_EXPECTED="${ABS_FEEDBACK_DIR}/${EXPECTED_FILE}"
  ```
- Replace `${FEEDBACK_DIR}/${EXPECTED_FILE}` references in the failure block (lines 88, 96, 99) with the absolute path.
- Add a one-line "Resolved PAS_PROJECT_ROOT: $PAS_PROJECT_ROOT" diagnostic to the failure block — this is what #70-F4 calls "the deadlock has no actionable error" answer.
- The session-id-first resolution from C04 + the worktree-aware `PAS_PROJECT_ROOT` from C01 jointly close the deadlock: a worktree-cwd session now resolves to the main `.pas/` (because of C01's git rev-parse fallback), the file the agent writes lands where the hook looks, and if the file is still missing the diagnostic shows the absolute path.

**Tests added (3):**
- T-C06-1: missing orchestrator feedback → stderr contains absolute path (starts with `/`), not just filename
- T-C06-2: stderr contains "Resolved PAS_PROJECT_ROOT:" line for diagnosability
- T-C06-3: worktree fixture: agent writes feedback in main `.pas/`; hook called from worktree cwd → exits 0 (file IS found)

### C07 — `route-feedback.sh` framework_signal_repo enforcement

**`plugins/pas/pas-config.yaml`** (the framework default config — bumped per-install at first run): add:
```yaml
framework_signal_repo: ZoranSpirkovski/PAS
```
**`plugins/pas/hooks/route-feedback.sh` `route_framework_signal()`:**
- Read repo from config: `REPO=$(grep '^framework_signal_repo:' "$PAS_CONFIG" | awk '{print $2}')`. If empty, default to `ZoranSpirkovski/PAS`.
- Replace `--repo ZoranSpirkovski/PAS` with `--repo "$REPO"`.
- Before the `gh issue create` call, append to `framework-routing.log`: `INFO: Filing ${signal_id} on repo ${REPO}` so any future regression is auditable.
- Refuse to file (with stderr warning) if `$REPO` resolves to an empty string.

**Tests added (2):**
- T-C07-1: signal with `Route: github-issue` + valid config → audit log records target repo before filing attempt
- T-C07-2: signal with `Route: github-issue` + empty `framework_signal_repo` → no `gh issue create` call attempted, warning logged

### C08 — `verify-task-completion.sh` output_files checkpoint (#49)

**`plugins/pas/hooks/verify-task-completion.sh`:**
- Add new case branch matching `*"Phase: "*` task subjects (created by orchestrator startup):
  ```bash
  *"Phase: "*)
    PHASE_NAME=$(echo "$TASK_SUBJECT" | sed 's/^\[PAS\] Phase: //')
    # Read output_files for this phase from status.yaml
    OUTPUT_FILES=$(awk -v phase="$PHASE_NAME" '
      $0 ~ "name: " phase { in_phase=1 }
      in_phase && /output_files:/ { capture=1; next }
      capture && /^- / { print }
      capture && !/^- / && !/^\s*$/ { capture=0; in_phase=0 }
    ' "$ACTIVE_STATUS")
    MISSING=""
    while read -r path; do
      [ -z "$path" ] && continue
      file=$(echo "$path" | sed 's/^- //')
      [ -f "$ACTIVE_WORKSPACE/$file" ] || MISSING="${MISSING:+$MISSING, }$file"
    done <<< "$OUTPUT_FILES"
    if [ -n "$MISSING" ]; then
      cat >&2 <<EOF
  Cannot complete "$TASK_SUBJECT": phase deliverables missing: $MISSING
  Write each output_files entry to disk before completing this task.
  EOF
      exit 2
    fi
    ;;
  ```
- The implementation reads phase output_files declarations already in `status.yaml` (per `lifecycle.md` schema). If a phase has no `output_files` block, the hook is a no-op for that phase.

**`plugins/pas/library/orchestration/lifecycle.md`:** add a one-paragraph note clarifying that phase tasks (subject `[PAS] Phase: <name>`) get blocked from completion when `output_files` are missing, with one example.

**Tests added (3):**
- T-C08-1: phase with declared `output_files: [discovery/priorities.md]`, file missing → task complete blocked, exit 2, stderr names file
- T-C08-2: phase with declared `output_files: [discovery/priorities.md]`, file present → exit 0
- T-C08-3: phase with no `output_files` block → exit 0 (no-op for un-instrumented phases)

### C09 — `applying-feedback/SKILL.md` UX edits

**`plugins/pas/processes/pas/agents/orchestrator/skills/applying-feedback/SKILL.md`** Step 3:
- Replace the bulleted "ask user preference" block with explicit AskUserQuestion guidance:
  ```markdown
  Use the AskUserQuestion tool to present these options. Do not ask in plain text — the structured prompt makes the choice unambiguous and the user's response routable. Options:

    1. Apply all + remember (apply all signals; remember preference for this artifact)
    2. Apply all once (apply all signals; do not remember)
    3. Just this (let me pick which signals to apply, one at a time)
    4. Review first (show each signal before deciding)
  ```
- After Step 12 ("Clear and Commit"), add a new Step 13 — **Routing rule (HIGH PRIORITY, #41)**:
  ```markdown
  ### 13. Where do changes go?

  Two routes exist; the wrong route will file PAS-internal changes onto the user's product repo. Always:

  - **Apply edits in-repo** to PAS plugin files (`plugins/pas/`, `processes/`, `library/`) — these are direct edits, no GitHub issue needed.
  - **`framework:pas` signals routed to GitHub** are filed ONLY on `ZoranSpirkovski/PAS` (enforced by `route-feedback.sh` framework_signal_repo). Never on the host project's repo.
  - **Process / agent / skill signals** stay local in the artifact's `feedback/backlog/` until an `applying-feedback` session processes them — they NEVER become GitHub issues anywhere.

  If you are about to call `gh issue create` from this skill, stop. The hook handles framework signal filing. This skill applies signals; it does not file them.
  ```
- Append to `plugins/pas/processes/pas/agents/orchestrator/skills/applying-feedback/changelog.md`:
  ```markdown
  ## 2026-04-16 — AskUserQuestion + routing-rule clarification

  Triggered by: cycle-14 hoist of #30, #40 (AskUserQuestion); #41 (routing rule)
  Pattern: agent re-asked options in plain text after explicit preference; agent filed framework signal on user product repo
  Change: Step 3 mandates AskUserQuestion with the four labeled options; new Step 13 codifies routing rules to prevent product-repo contamination
  ```

**Tests:** none — skill content change, not hook behavior. DX-validation in the validation phase covers this (manual: open the skill, read step 3 cold, verify it's unambiguous).

### C10 — Test harness expansion

**`plugins/pas/hooks/tests/test-hooks.sh`:** add the 30 tests itemized in C01–C08 (5+3+2+4+8+3+2+3 = 30 new tests). Current count is 60 per project memory; new total = 90, exceeds the ≥75 target with margin.

**`plugins/pas/hooks/tests/fixtures/worktree-setup.sh`:** new helper:
```bash
#!/usr/bin/env bash
# Set up a temporary git repo + worktree for hook testing.
# Returns: MAIN_DIR (path to main checkout with .pas/) and WORKTREE_DIR (path to worktree).
make_worktree_fixture() {
  local tmp=$(mktemp -d)
  ( cd "$tmp" && git init -q && git commit --allow-empty -m "init" -q )
  mkdir -p "$tmp/.pas/workspace"
  printf 'feedback: enabled\n' > "$tmp/.pas/config.yaml"
  ( cd "$tmp" && git worktree add -q "$tmp/.worktree-test" -b test-branch )
  echo "$tmp $tmp/.worktree-test"
}
```
Used by T-C01-4 and T-C06-3.

**`plugins/pas/hooks/tests/fixtures/agent-type-status.sh`:** helper that writes a `status.yaml` with given `agent:` lines so T-C05-1/2 can build the right allowlist quickly.

### C11 — Version bump

`bump-version.sh` runs as part of the existing pre-commit / CI flow (per cycle-12 memory) and increments `plugin.json` patch version + `marketplace.json`. Expected: `1.3.2 → 1.3.3` (matches #64's call for a forced cache refresh).

---

## 3. Test-additions summary

| Commit | Tests | Cumulative |
|---|---|---|
| Existing | 60 | 60 |
| C01 | 5 | 65 |
| C02 | 3 | 68 |
| C03 | 2 | 70 |
| C04 | 4 | 74 |
| C05 | 8 | 82 |
| C06 | 3 | 85 |
| C07 | 2 | 87 |
| C08 | 3 | 90 |

**Final target: 90 tests**, ≥ 75 mandate met with 15-test buffer.

**Critical fixtures:**
- `tests/fixtures/worktree-setup.sh` — needed for T-C01-4, T-C06-3 (worktree-aware path resolution)
- `tests/fixtures/agent-type-status.sh` — needed for T-C05-1..C05-4 (PAS-vs-non-PAS scoping)
- `tests/fixtures/phase-output-files-status.sh` — needed for T-C08-1..C08-3 (output_files presence checks)

---

## 4. Parallelization plan for execution phase

**Sequential foundation (must serialize):**
- C01 must land first.
- C04 must land before C05 and C06 (they call `guard_active_workspace`, which now session-routes).
- C10 follows incrementally — each commit author writes its own tests in the same commit.
- C11 lands last (auto-bump after all code merges).

**Parallel groups, after C01 lands:**

| Group | Commits | Owner suggestion | Why parallel |
|---|---|---|---|
| **A** | C02, C03 | framework-architect (C02), framework-architect (C03) | Both touch independent files; same author OK to keep context |
| **B** | C04, C07 | framework-architect (C04), framework-architect (C07) | Independent files |
| **C** (after C04) | C05, C06 | framework-architect (C05) — high blast radius, needs senior owner; framework-architect (C06) | Different files (`check-self-eval.sh`+`pas-session-start.sh` vs `verify-completion-gate.sh`) |
| **D** | C08 | framework-architect (C08) | Independent of A/B/C |
| **E** (independent, anytime) | C09 | dx-specialist (skill-edit, owns wording per discovery rationale) | Skill file, no hook overlap |
| **F** (release phase) | close-on-merge admin (#31, #33, #56, #57, #61, #66) | community-manager | After PR merge |

**Recommended execution dispatch:**

1. **Wave 1 (serial):** framework-architect lands C01 (foundational). Review checkpoint.
2. **Wave 2 (parallel, 4 dispatches):** framework-architect on C02 + C03 + C04 + C07 (small commits, can be one wave or two). dx-specialist on C09 in parallel.
3. **Wave 3 (parallel, 2 dispatches, after C04 merged):** framework-architect on C05 (highest scrutiny, paired-review recommended), framework-architect on C06 + C08.
4. **Wave 4 (validation):** all hook tests run; spawn an Explore subagent in active workspace, assert it returns text. Validation owner runs the exit-criteria invariants (§6).
5. **Wave 5 (release):** community-manager drafts PR with all `closes #N` references; bump-version on commit; merge; close-on-merge admin issues.

**Feedback-analyst's role in execution:** track signals as they emerge during execution; ensure no new framework signals get lost; pre-stage the M3-completion changelog notes for `plugins/pas/hooks/changelog.md`.

**Community-manager's role in execution:** parked. (Their `execution/changes/community-manager/` scaffold from cycle-14 was misfiled per team-lead — ignore. Real work begins at release phase.)

---

## 5. Risk / rollback plan

**Smallest reversible commit unit:** any single C0X commit can be reverted via `git revert <sha>` without affecting the others, *with one exception*:

- **C04 + C05 are coupled in revert direction.** C05 assumes session-id-first resolution from C04. If C05 needs revert, leave C04 in place. If C04 needs revert, also revert C05 (else C05's `guard_agent_in_active_process` will resolve workspaces incorrectly).

**Per-commit rollback risk:**

| Commit | Rollback risk | Notes |
|---|---|---|
| C01 | Low — defensive defaults are pure additions | If `resolve_pas_project_root` walks too far up in nested-repo edge cases, fall back can be disabled by reverting just the helper |
| C02 | Trivial — display-only | No gate behavior touched |
| C03 | Trivial — local fix | Only the secondary code path |
| C04 | Medium — workspace selection logic | Changes resolution order, but back-compat path retained (Pass 1, Pass 2 unchanged) |
| C05 | **High — touches the gate that protects feedback contract** | If `agent_type` field is empty/unknown in some CC version, behavior degrades to existing (entire agent set blocked); this is safe-fail. T-C05-4 confirms |
| C06 | Low — diagnostic improvement | Cannot weaken gate; only adds info |
| C07 | Low — repo enforcement | Worst case: framework signals don't file (logged), no wrong-repo damage |
| C08 | Medium — new gate | Could block legitimate phase completions if `output_files` declarations in status.yaml are wrong; T-C08-3 ensures un-instrumented phases pass |
| C09 | Trivial — skill text | Pure documentation change |

**Most likely rollback scenario:** C05's `agent_type` payload field absent in user's CC version → all subagents fall back to existing (blocked) behavior. Detected by T-C05-4. Mitigation: ship with explicit `agent_type` empty-string handling that defaults to "treat as PAS agent" (safe direction) rather than "skip entirely" (could weaken enforcement).

---

## 6. Cycle 14 PR exit criteria

Refined from priorities.md §5.

**Hard gates (PR cannot merge until all green):**

1. `bash plugins/pas/hooks/tests/test-hooks.sh` exits 0 with **≥ 90 PASS / 0 FAIL**.
2. `git grep -nE 'CLAUDE_PLUGIN_ROOT[^:-]' plugins/pas/hooks/` returns nothing (all references default-guarded).
3. `git grep -nE '\$CWD/\.pas' plugins/pas/hooks/` returns only intentional uses (no path-construction inside guard helpers; everything goes through `$PAS_PROJECT_ROOT`).
4. Plugin version in `plugins/pas/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` is `1.3.3` (auto-bumped).
5. `plugins/pas/hooks/changelog.md` has a `## 2026-04-16 — Cycle 14 / Milestone 3` entry listing every closed issue.

**Runnable invariants (manual validation):**

I1. **Worktree write-survival.** From a worktree cwd: agent writes `${PAS_PROJECT_ROOT}/.pas/workspace/.../feedback/orchestrator-${session}.md`, exits cleanly. (Covers #70-F1, F2, F4.)

I2. **Subagent text preservation.** Spawn a generic Explore subagent inside an active PAS workspace; assert (a) it returns its findings as text, (b) it does NOT write any file under `.pas/workspace/*/feedback/`, (c) parent receives substantive output (>200 chars) intact. (Covers #38, #67, #68, #71.)

I3. **PAS agent enforcement preserved.** Spawn a process-defined agent (e.g. `framework-architect`) without writing self-eval; assert SubagentStop blocks with the rewritten dx-specialist message naming absolute path. (Confirms C05 didn't weaken real enforcement.)

I4. **Hook never crashes on missing fields.** Run `pas-session-start.sh` against status.yaml missing `instance:` AND `status:`; assert exit 0, MISSING_FIELDS warning printed, lifecycle injection still happens.

I5. **Phase deliverable enforcement.** Create a phase task `[PAS] Phase: discovery` with declared `output_files: [discovery/priorities.md]`; attempt complete without writing the file; assert TaskCompleted hook exit 2.

I6. **Framework signals stay on PAS repo.** With `framework_signal_repo: ZoranSpirkovski/PAS` and a feedback file containing `Target: framework:pas` + `Route: github-issue`, run `route-feedback.sh`; assert `framework-routing.log` records `INFO: Filing ... on repo ZoranSpirkovski/PAS`. (No actual `gh issue create` in tests — mock.)

I7. **applying-feedback skill changes.** Open `applying-feedback/SKILL.md`; cold-read Step 3 and Step 13; verify they instruct AskUserQuestion + the routing rule respectively (#30, #40, #41).

**Post-merge admin (community-manager):**

- Close #31, #33, #56, #57, #61, #66 with `closes-via #PR-N` comments.
- Close cycle 14 sub-issues against #70 (numbered against community-manager's filing).
- Comment merged-PR link onto each implementation issue (#38, #49, #52, #54, #55, #58, #59, #64, #67, #68, #70, #71, #30, #40, #41).
- After merge: `pr-management` Step 6 — merge `main` back into `dev`.

---

## 7. Out of scope (deferred, explicit)

| Item | Where it goes | Why deferred |
|---|---|---|
| #70 finding 5 (generator emits cwd-relative paths) | M5 (Cycle 16) | Generator work belongs with M5 generator-correctness milestone |
| #70 finding 6 (self-evaluation/SKILL.md cwd-relative) | M5 (Cycle 16) | Skill rewrite pairs with generator emit changes |
| #70 finding 3 (atomic status.yaml writes) | Follow-up (post-M3) | Session-id-first resolution in C04 covers the consumer-facing symptom; atomic-write hardening is a deeper refactor |
| #70 finding 8 (skip_pas_auto_pin escape hatch) | M7 (Cycle 18+) | Needs config schema discussion before implementation |
| #70 findings 9, 10 | M7 / docs | Architectural / policy decisions, not hook bugs |
| #50 (auto-memory contamination) | M6 | Long-tail trust issue; not session-breaking. Flagged for early review during M4 design |
| #34 (GitHub issue template for framework:pas) | M6 | Template design pairs with #59 follow-up + AskUserQuestion edits |
| Full DX audit | M6 (opening phase) | Needs post-M3+M4+M5 state to be useful; checklist locked in priorities.md §6 |
| Cycle-14 dogfood signals (TaskUpdate auto-broadcast, channel precedence) | filed as new issues at release phase, slotted to M4 | Out of M3 scope; signals should be captured before they're forgotten |
| Cycle-13 OQI-02 | rolled into C05 (not deferred — bundled) | Same root-cause family as #38/#67/#68/#71 |
