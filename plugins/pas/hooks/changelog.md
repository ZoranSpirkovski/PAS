# Hooks Changelog

## 2026-04-20 — Cycle 15 / Milestone 4: Marketplace-Authoritative

Triggered by: issue #125 — PAS becomes a tool for maintaining user-controlled marketplaces of skills. Consumer projects hold only workspace state; skill definitions live in the marketplace; feedback flows back to the marketplace.

Hook-level changes (10 commits, 13 new tests, harness now 130 / 0 fail):

**lib/guards.sh** — hardened `${CLAUDE_PLUGIN_ROOT}` resolver. Replace the silent-fail one-liner with `resolve_claude_plugin_root()` — 4-strategy chain (validated env, walk-up, install-cache, fail-loud). Every hook sources guards.sh + calls it at startup; SessionStart uses `|| exit 0`, others `|| exit 1`. New helpers: `resolve_marketplace_root()` (walk-up for `.claude-plugin/marketplace.json`), `resolve_origin_marketplace()` (derives `<installLocation, plugin>` from plugin install path via `~/.claude/plugins/known_marketplaces.json`), `resolve_host_id()` (stable per-project id for filename disambiguation).

**route-feedback.sh** — three-tier target resolution: (1) marketplace clone in `~/.claude/plugins/marketplaces/<m>/`, (2) plugin install path (read-only target lookup), (3) legacy consumer `.pas/processes/` (transitional backward-compat). Successful marketplace writes are `git add && git commit`-ed locally so they survive CC's `/plugin marketplace update`. New `_route_to_outbox()` fallback stages unwriteable signals at `${CLAUDE_PLUGIN_DATA}/pas/feedback-outbox/` + logs to `warnings.log` — signals are never silently lost. Filename format: `<date>-<host-id>-<source>-<signal-id>.md` (was: `<date>-<source>-<signal-id>.md`).

**guards.sh: guard_pas_project / guard_feedback_enabled** — relaxed to accept workspace-only consumer projects. `guard_pas_project` now matches either `.pas/config.yaml` (legacy) OR `.pas/workspace/` (marketplace-authoritative). `guard_feedback_enabled` falls back to `${CLAUDE_PLUGIN_ROOT}/pas-config.yaml` when the consumer has no config.

**verify-completion-gate.sh / verify-task-completion.sh / check-self-eval.sh** — error-message references swept from `.pas/library/` → `${CLAUDE_PLUGIN_ROOT}/library/`. Fixed T-C07-2 fixture (cherry-pick delta from #112) — the fake-plugin path now satisfies the hardened resolver's validation, restoring the "empty framework_signal_repo → REFUSED" assertion.

Non-hook deltas in this cycle (see plugin-level docs for full release notes):
- `/pas` gains a **Marketplace Gate** — refuses to run outside a marketplace; offers to cd / bootstrap.
- `bootstrap-marketplace` skill — scaffold a new marketplace repo.
- `pas-create-process` / `pas-create-skill` default target flipped to `<marketplace>/plugins/<plugin>/...` (opt out with `--fork`).
- `plugins/pas/library/orchestration/doctrines.md` — codifies N/N+1 Protocol (#113), Dogfooding Hazard Awareness, Data Verification Norm.
- `plugins/pas/processes/pas-development/` — now the authoritative location (migrated from `.pas/processes/pas-development/` via git mv, history preserved).
- `.claude/CLAUDE.md` protected-path rule updated; `pr-management` Step 6 verification updated.

N/N+1 note: per the codified doctrine, cycle-16 validates live behavior of the new resolver + routing from a fresh session. In-session validation covers static checks (grep, tests, version bumps) only.

## 2026-04-16 — Cycle 14 / Milestone 3: Hook Safety & Stability

Triggered by: 14 GitHub issues — sessions silently disabled from worktrees, hooks crashing on missing yaml fields, `SubagentStop` derailing non-PAS subagents, completion gate deadlocking with no diagnostic, framework signals filed on product repos. Plus cycle-13 dx-specialist OQI-02 (idle-shutdown self-eval), bundled.

Pattern: every hook script assumed `cwd == project root` and used `set -euo pipefail` on `grep` pipelines that legitimately match nothing. Subagent-context detection was absent, so any subagent in a PAS-enabled repo was treated as a PAS process agent. One root cause family expressed across hooks, scaffolds, and the inherited self-eval contract.

Changes (11 commits, 30 new tests, harness now 117 / 0 fail):

- `lib/guards.sh`: defensive default for `CLAUDE_PLUGIN_ROOT`; new `resolve_pas_project_root` (cwd → `.pas/config.yaml` walk → `git rev-parse --show-toplevel` worktree fallback); new `safe_grep_field` helper; new `guard_agent_in_active_process` (PAS-vs-non-PAS scoping); `guard_active_workspace` now resolves via `$PAS_PROJECT_ROOT` (#64, #70-F1, #70-F2)
- `pas-session-start.sh`: tolerate missing `instance:` / `status:` / `process:` fields; print `MISSING_FIELDS` warning instead of silently degrading; skip lifecycle injection when `agent_id` is non-empty (#54, #58, #38, #68 — context-injection side)
- `check-self-eval.sh`: fix `grep -c || echo 0` integer-comparison crash; gate on `guard_agent_in_active_process` so non-PAS subagents pass through silently; preserve substantive `last_assistant_message` (>200 chars, no summary keyword) instead of blocking with elided summary; SUBAGENT NOTE carve-out + `tr -d '[:space:]'` for `LAST_MSG_LEN` (#55, #38, #67, #68, #71, cycle-13 dx-specialist OQI-02)
- `lib/workspace.sh`: session-id-first resolution in `find_active_workspace_status` — match `current_session:` field before falling back to mtime; resolves wrong-workspace bugs in multi-instance projects (#52)
- `verify-completion-gate.sh`: absolute paths in failure diagnostics; `Resolved PAS_PROJECT_ROOT:` line for diagnosability; jointly with the workspace + project-root fixes, closes the worktree deadlock (#70-F4)
- `verify-task-completion.sh`: new `[PAS] Phase: <name>` matcher reads `output_files` from status.yaml and blocks completion when files are missing — first phase-deliverable enforcement gate (#49)
- `route-feedback.sh`: read repo from new `framework_signal_repo:` config key (defaults to `ZoranSpirkovski/PAS`); refuse to file when target is empty; audit log entry written to `framework-routing.log` before every `gh issue create` (#59)
- `pas-config.yaml`: add `framework_signal_repo: ZoranSpirkovski/PAS` so consumers cannot accidentally route PAS-internal signals onto product repos
- `processes/pas/agents/orchestrator/skills/applying-feedback/SKILL.md`: Step 3 mandates `AskUserQuestion` with four labeled options; new Step 13 codifies routing rules (in-repo edits vs framework GitHub issues vs local backlog) so the skill cannot be the source of a wrong-repo filing (#30, #40, #41)
- `tests/test-hooks.sh`: 30 new tests across the 8 affected scripts; `tests/fixtures/worktree-setup.sh` and `tests/fixtures/agent-type-status.sh` added
- `plugin.json`, `marketplace.json`: version auto-bumped from 1.3.2 → 1.3.3 by `bump-version.sh`

Closed: #38, #49, #52, #54, #55, #58, #59, #64, #67, #68, #70 (findings 1, 2, 4, 7), #71, #30, #40, #41. Duplicates closed via constituent fix: #31, #33, #56, #57, #61 (and #66 — community-manager admin).

Known residual (deferred to cycle 15): SessionStart lifecycle text leaks into Agent-tool subagent context despite the `agent_id` skip in `pas-session-start.sh`. Hook-layer enforcement holds (the rogue feedback file is benign, gates do not block), but the directive text reaches the subagent. Tracked as a fresh issue; root-cause hypothesis is that Claude Code's SessionStart payload may not populate `agent_id` for Agent-tool subagents.

Deferred to M5: #70 findings 5 (generator emits cwd-relative paths), 6 (self-evaluation/SKILL.md cwd contract). Deferred to M7: #70 findings 8, 9, 10. Deferred to M6: #50, #34. Cycle-14 dogfood signals filed for M4: TaskUpdate ownership-change auto-broadcasts, agent task_assignment auto-claim, subagent self-eval filename mismatch.
