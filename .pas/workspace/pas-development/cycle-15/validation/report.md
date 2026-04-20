# Cycle-15 Validation Report

**Branch:** `feature/cycle-15-marketplace-authoritative` (off `dev`)
**Commits:** 11 (C01–C11) — `84b546b` through `1134c61`
**Version bump:** 1.3.3 → 1.4.0
**Mode:** Option B (stop at PR, cycle-16 validates live behavior per N/N+1 doctrine)

---

## Commit sequence (verified)

| # | SHA | Subject |
|---|---|---|
| C01 | 84b546b | fix(hooks): harden CLAUDE_PLUGIN_ROOT resolver |
| C02 | 550d363 | feat(pas): marketplace gate for /pas skill |
| C03 | 061980c | feat(pas): relax consumer to workspace-only |
| C04 | 14863f3 | docs(library): add orchestration doctrines |
| C05 | fcd80b4 | feat(hooks): marketplace-aware feedback routing + host-id |
| C06 | 7af9883 | feat(pas): pas-create-process/pas-create-skill → marketplace |
| C07 | 5901c62 | feat(pas): bootstrap-marketplace skill |
| C08 | fec329f | docs(pas): sweep .pas/library refs + upgrading skill |
| C09 | 74ce6a9 | refactor(pas): migrate pas-development into plugin tree |
| C10 | c0c19c3 | chore: bump version to 1.4.0 |
| C11 | 1134c61 | docs: cycle-15 changelog entry |

---

## In-session validation (mandatory, per plan §8)

### Harness

- `bash plugins/pas/hooks/tests/test-hooks.sh` — **exit 0, 130 passed, 0 failed** (baseline was 117 + 1 pre-existing fail on dev).
- Net new tests: 13 (C10-1..C10-4 resolver, C11-1..C11-3 marketplace-gate, C12-1..C12-4 routing + host-id, C13-1..C13-2 consumer-shrink).
- Pre-existing C07-2 failure (#112 cherry-pick delta) resolved as a bonus during C01.

### Static checks (grep-verified)

1. **No active-use `.pas/library/` refs in plugin code:**
   ```
   grep -rn '\.pas/library/' plugins/pas/ | grep -v "test-hooks.sh"
   ```
   Remaining matches are intentional prose:
   - `plugins/pas/hooks/changelog.md` — describes the sweep.
   - `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md` — "Legacy" markers guiding consumer upgrades.

2. **No active-use `.pas/processes/pas-development/` refs in plugin/launcher code:**
   ```
   grep -rn '\.pas/processes/pas-development' plugins/ .claude/ | grep -v CLAUDE.md | grep -v changelog.md
   ```
   Empty result.

3. **New pas-development location exists:**
   ```
   test -f plugins/pas/processes/pas-development/process.md  # exists
   ls plugins/pas/processes/pas-development/
   # agents  changelog.md  feedback  modes  overview.html  process.md  processes
   ```

4. **Old location removed:**
   ```
   test ! -d .pas/processes/pas-development  # OK
   test ! -d .pas/processes                  # OK (removed empty dir)
   ```

5. **Version bumped:**
   ```
   grep '"version"' plugins/pas/.claude-plugin/plugin.json .claude-plugin/marketplace.json
   # plugins/pas/.claude-plugin/plugin.json:  "version": "1.4.0",
   # .claude-plugin/marketplace.json:    "version": "1.4.0"          (metadata.version)
   # .claude-plugin/marketplace.json:      "version": "1.4.0"        (plugins[0].version)
   ```

6. **Launcher reads from new path:**
   ```
   grep -n CLAUDE_PLUGIN_ROOT .claude/skills/pas-development/SKILL.md
   # Line 28: Read `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/process.md`
   # Line 36: Read `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/processes/quick/process.md`
   ```

7. **CLAUDE.md protected path updated:**
   ```
   grep -A1 "Protected Files" .claude/CLAUDE.md
   # Line 43: "plugins/pas/processes/pas-development/" — protected path moved
   ```

### Git history preservation (C09 migration check)

- `git log --follow plugins/pas/processes/pas-development/process.md` — history preserved back to original authoring commits.
- `git mv` applied to 109 files in the tree; all show as renames (R status) in `git status`.

---

## Out-of-session validation (deferred to cycle-16 per N/N+1 doctrine)

Per `plugins/pas/library/orchestration/doctrines.md`, hook-substrate changes must be validated from a fresh session. Cycle-16's scope includes:

- [ ] Fresh `/pas-development` invocation — confirm launcher resolves `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/process.md` and the process starts.
- [ ] Fresh session inside a consumer project (no `.pas/config.yaml`) — confirm `guard_pas_project` accepts `.pas/workspace/`-only layout and `route-feedback.sh` routes correctly.
- [ ] Fresh session in a non-marketplace cwd — confirm `/pas` presents the three-option gate.
- [ ] `/pas:pas` → "bootstrap here" — confirm `scaffold-marketplace.sh` produces a valid marketplace and the next `/pas:pas` run detects it.
- [ ] Live feedback routing — open an OQI signal targeting an agent/skill, confirm the file lands under `~/.claude/plugins/marketplaces/pas-framework/plugins/pas/.../feedback/backlog/` with a host-id-prefixed filename.
- [ ] SessionStart hook under the new resolver — confirm context injection is unaffected.

---

## Scope deviations from plan

- Plan targeted 129 tests; shipped at **130** (+1 bonus — C13-1 workspace-only consumer test).
- Plan §4 suggested C04 optional bundling of #114 (status-before-idle). Deferred to cycle-16 to keep scope tight.
- Plan §1/P6 mentioned updating the SKILL.md docs for creating-processes / creating-skills / creating-agents. Creating-agent SKILL.md docs weren't updated in this cycle (only the pas-create-agent script template). Follow-up: minor doc pass.
- Plan §1/P9 listed ~13 files for the `.pas/library/` sweep; shipped 11 (skipped two already-aligned references that weren't in the grep).

No scope deviations affect correctness — the behavioral contract in the priorities doc is met.

---

## Risks realized vs flagged (plan §7)

- **R1 (CLAUDE_PLUGIN_ROOT walk-up ambiguity):** Not triggered. C10-2 test explicitly exercises the walk-up path.
- **R2 (`git mv` in worktree race):** Not triggered. Workspace dir (`.pas/workspace/pas-development/cycle-15/`) was quiescent; migration touched only `.pas/processes/pas-development/`.
- **R3 (installed_plugins.json shape evolves):** Not exercised — today's schema version 2 used in tests; resolver has graceful fallback if shape changes.
- **R4 (multi-plugin marketplace):** Not exercised — current repo is single-plugin. `--plugin <name>` flag added preemptively; errors clearly when >1 plugin detected.
- **R5 (CHANGELOG convention):** Used `plugins/pas/hooks/changelog.md` following cycle-14 pattern. Per-process changelogs under `plugins/pas/processes/*/changelog.md` can be updated in cycle-16.
- **R6 (C12 test isolation):** All C12 tests use `mktemp -d` fixtures; no pollution of `~/.claude/plugins/marketplaces/`.
- **R7 (cycle length):** Shipped in one extended session. Commit sequence ended at C11 as planned.

---

## Known unchanged / carry-forward

- **#109** (SessionStart text leak to Agent-tool subagents) — re-evaluate post-cycle, no code change here.
- **#114** (status-before-idle) — deferred; small enough to bundle in cycle-16.
- **docs/plans/** and cycle-15 workspace artifacts — to be committed directly to dev after PR merge (per pr-management convention).

---

## Verdict

**Ready for PR.** Harness green, static checks clean, migration atomic, version bumped, changelog written. Proceed to Phase 5 (Release) — push branch, open PR, stop at PR open per owner-approved Option B.
