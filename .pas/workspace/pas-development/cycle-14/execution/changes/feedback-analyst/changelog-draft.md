# Changelog Draft — Cycle 14 / Milestone 3 (Hook Safety & Stability)

> **For community-manager:** copy the entry below into `plugins/pas/hooks/changelog.md` (create the file if it does not exist — only the orchestration / process / skill changelogs exist today; this is the first hooks-area changelog). Adjust commit SHAs and sub-issue numbers (filed against #70) once they are known.

---

## 2026-04-16 — Cycle 14 / Milestone 3: Hook Safety & Stability

Triggered by: 14 GitHub issues — sessions silently disabled from worktrees, hooks crashing on missing yaml fields, `SubagentStop` derailing non-PAS subagents, completion gate deadlocking with no diagnostic, framework signals filed on product repos. Plus cycle-13 dx-specialist OQI-02 (idle-shutdown self-eval), bundled.

Pattern: every hook script assumed `cwd == project root` and used `set -euo pipefail` on `grep` pipelines that legitimately match nothing. Subagent-context detection was absent, so any subagent in a PAS-enabled repo was treated as a PAS process agent. One root cause family expressed across hooks, scaffolds, and the inherited self-eval contract.

Changes (11 commits, 30 new tests, harness now ≥ 90 / 0 fail):

- `lib/guards.sh`: defensive default for `CLAUDE_PLUGIN_ROOT`; new `resolve_pas_project_root` (cwd → `.pas/config.yaml` walk → `git rev-parse --show-toplevel` worktree fallback); new `safe_grep_field` helper; new `guard_agent_in_active_process` (PAS-vs-non-PAS scoping); `guard_active_workspace` now resolves via `$PAS_PROJECT_ROOT` (#64, #70-F1, #70-F2)
- `pas-session-start.sh`: tolerate missing `instance:` / `status:` / `process:` fields; print `MISSING_FIELDS` warning instead of silently degrading; skip lifecycle injection when `agent_id` is non-empty (#54, #58, #38, #68 — context-injection side)
- `check-self-eval.sh`: fix `grep -c || echo 0` integer-comparison crash; gate on `guard_agent_in_active_process` so non-PAS subagents pass through silently; preserve substantive `last_assistant_message` (>200 chars, no summary keyword) instead of blocking with elided summary (#55, #38, #67, #68, #71, cycle-13 dx-specialist OQI-02)
- `lib/workspace.sh`: session-id-first resolution in `find_active_workspace_status` — match `current_session:` field before falling back to mtime; resolves wrong-workspace bugs in multi-instance projects (#52)
- `verify-completion-gate.sh`: absolute paths in failure diagnostics; `Resolved PAS_PROJECT_ROOT:` line for diagnosability; jointly with the workspace + project-root fixes, closes the worktree deadlock (#70-F4)
- `verify-task-completion.sh`: new `[PAS] Phase: <name>` matcher reads `output_files` from status.yaml and blocks completion when files are missing — first phase-deliverable enforcement gate (#49)
- `route-feedback.sh`: read repo from new `framework_signal_repo:` config key (defaults to `ZoranSpirkovski/PAS`); refuse to file when target is empty; audit log entry written to `framework-routing.log` before every `gh issue create` (#59)
- `pas-config.yaml`: add `framework_signal_repo: ZoranSpirkovski/PAS` so consumers cannot accidentally route PAS-internal signals onto product repos
- `processes/pas/agents/orchestrator/skills/applying-feedback/SKILL.md`: Step 3 mandates `AskUserQuestion` with four labeled options; new Step 13 codifies routing rules (in-repo edits vs framework GitHub issues vs local backlog) so the skill cannot be the source of a wrong-repo filing (#30, #40, #41)
- `tests/test-hooks.sh`: 30 new tests across the 8 affected scripts; `tests/fixtures/worktree-setup.sh` and `tests/fixtures/agent-type-status.sh` added
- `plugin.json`, `marketplace.json`: version auto-bumped from 1.3.2 → 1.3.3 by `bump-version.sh`

Closed: #38, #49, #52, #54, #55, #58, #59, #64, #67, #68, #70 (findings 1, 2, 4, 7), #71, #30, #40, #41. Duplicates closed via constituent fix: #31, #33, #56, #57, #61 (and #66 — community-manager admin).

Deferred to M5: #70 findings 5 (generator emits cwd-relative paths), 6 (self-evaluation/SKILL.md cwd contract). Deferred to M7: #70 findings 8, 9, 10. Deferred to M6: #50, #34. Cycle-14 dogfood signals filed for M4: TaskUpdate ownership-change auto-broadcasts, agent task_assignment auto-claim, subagent self-eval filename mismatch.
