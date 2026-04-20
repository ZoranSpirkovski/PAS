# Cycle-15 Discovery — Synthesis & Proposed Priorities (v2)

**Issue:** [#125](https://github.com/ZoranSpirkovski/PAS/issues/125) — Architectural shift to marketplace-authoritative
**Status:** round-1 perspectives complete + product-owner redirects on framing incorporated. Ready for planning gate.

---

## The model (final framing after owner redirect)

PAS transforms into **a tool for maintaining user-controlled marketplaces of skills**. A marketplace is a git repo (public or private) containing plugins. Users own their marketplace. Consumer projects install skills from that marketplace via Claude Code's existing `/plugin marketplace add` + `/plugin install` flow. When those skills are used in any consumer project, feedback routes back to the marketplace — so the skill improves across every project that uses it. Workspaces stay local to the consumer.

### Hard rules

1. **PAS-the-skill runs only inside a marketplace.** Marketplace detected by walking up from cwd for `.claude-plugin/marketplace.json`. Invoked outside a marketplace → refuse, offer three options: cd to existing marketplace / bootstrap a new one / bail.
2. **PAS-the-infrastructure (hooks) runs everywhere the plugin is installed.** Hooks catch feedback signals in any session (including consumer sessions) and route them to the marketplace where the skill originated.
3. **Consumer projects have only `.pas/workspace/`.** No `.pas/processes/`, no `.pas/library/`, no `.pas/config.yaml`. Workspace is created on first use of any PAS-installed skill.
4. **A skill's origin marketplace is derived from its install identity** (`<plugin>@<marketplace>` per `~/.claude/plugins/installed_plugins.json`). No `marketplace:` frontmatter field needed — Claude Code's registry already has it.

### Claude Code primitives we rely on

| Primitive | Location | Role |
|---|---|---|
| `known_marketplaces.json` | `~/.claude/plugins/known_marketplaces.json` | Maps marketplace name → git repo + local clone path |
| `installed_plugins.json` | `~/.claude/plugins/installed_plugins.json` | Maps `<plugin>@<marketplace>` → install path per scope |
| Marketplace clones | `~/.claude/plugins/marketplaces/<name>/` | Writable git clone of each registered marketplace |
| `${CLAUDE_PLUGIN_ROOT}` | env var into hooks | Install path of the running plugin (read-only cache) |
| `${CLAUDE_PLUGIN_DATA}` | `~/.claude/plugins/data/<plugin-id>/` | Persistent per-plugin scratch, survives updates (backstop) |

No new PAS-side registry. No new env vars.

---

## Priorities (planning input)

### P0 — Issue backlog hygiene (owner-gated pre-work)

- Bulk-close ~24 `OQI-99: test signal for routing audit` issues with one comment.
- Close #40, #41, #58, #71 (already shipped per owner comments).
- Consolidate #105/#106/#115 into one "task-list misrouting" issue.

Gated on owner approval at the discovery gate.

### P1 — Harden `${CLAUDE_PLUGIN_ROOT}` resolver

Replace the defensive one-liner in `plugins/pas/hooks/lib/guards.sh:11` with a named resolver that:

1. Prefers harness-exported env var, **validates** it points at `plugin.json` + `hooks/`.
2. Falls back: walk up from `${BASH_SOURCE[0]}` for the same validation markers.
3. Falls back: scan `~/.claude/plugins/cache/*/pas/*/` for an install.
4. **Fails loudly** to stderr + exits non-zero on miss. No silent empty strings.

Every hook sources guards.sh and calls `resolve_claude_plugin_root || exit 1` at startup.

Test matrix adds ~4 cases: (a) env set + valid, (b) env empty + walk-up succeeds, (c) env empty + cache fallback, (d) all strategies fail → loud exit. Target harness count goes from 117 → ~121.

### P2 — `/pas:pas` detects marketplace + refuses outside

- Walk up from cwd looking for `.claude-plugin/marketplace.json`.
- If found → proceed. Export `PAS_MARKETPLACE_ROOT` for skills to consume.
- If not found → present three choices via AskUserQuestion: (a) cd to a registered marketplace (list via `~/.claude/plugins/known_marketplaces.json`), (b) bootstrap a new marketplace here, (c) exit.
- Implementation in `plugins/pas/skills/pas/SKILL.md` + shared resolver helper.

### P3 — Marketplace-aware feedback routing

Rewrite `plugins/pas/hooks/route-feedback.sh:resolve_target_path()` to:

1. Determine the origin marketplace of the target skill/process. Resolution order:
   - If signal includes `Plugin: <name>@<marketplace>` (explicit) → use that.
   - Else walk the `${CLAUDE_PLUGIN_ROOT}` or the skill's origin path + consult `installed_plugins.json` to derive.
2. Look up `known_marketplaces.json[<marketplace>].installLocation` → the writable local clone.
3. Compute backlog destination: `<installLocation>/plugins/<plugin>/<relative-path-to-target>/feedback/backlog/<date>-<host-id>-<signal-id>.md`.
4. Write the file. Optionally `git add && git commit` locally (no push — user pushes explicitly).
5. **Fallbacks, in order:**
   - Marketplace not registered → file GitHub issue on `source.repo` via `gh`.
   - Write fails (permissions, disk) → stage at `${CLAUDE_PLUGIN_DATA}/pas/feedback-outbox/` + log to `<cwd>/.pas/workspace/feedback/warnings.log`.

Add `lib/guards.sh::resolve_origin_marketplace()` helper.

### P4 — Host-id in routed filenames

- Filename format: `<date>-<host-id>-<source>-<signal-id>.md`.
- `host-id` reads from `.pas/workspace/host-id` (auto-created on first run, defaults to `basename $CWD`) or from a user-level config.
- Prevents collisions in multi-host marketplace clones.

### P5 — pas-development migrates into the plugin tree

Atomic migration:

1. `git mv .pas/processes/pas-development/ plugins/pas/processes/pas-development/`.
2. Update `.claude/skills/pas-development/SKILL.md` launcher to read from `${CLAUDE_PLUGIN_ROOT}/processes/pas-development/process.md`.
3. Rewrite `.claude/CLAUDE.md` "Protected Files" — the protected path moves to `plugins/pas/processes/pas-development/`.
4. Update `pr-management` Step 6 (post-merge main→dev sync) — verify new location.
5. Smoke test: fresh session, run `/pas-development` (can use quick cycle to avoid full orchestration), confirm it resolves from the new path.

The migration is a single reviewable commit. CLAUDE.md update in the same commit.

### P6 — `pas-create-process` / `pas-create-skill` write into the marketplace

- Default target: the marketplace root detected from cwd (P2).
- Write path: `<marketplace-root>/plugins/<plugin>/processes/<name>/` (ask user which plugin if >1).
- Thin launcher template points at `${CLAUDE_PLUGIN_ROOT}/processes/<name>/process.md` (consumer-installable).
- Sweep the existing `pas-create-process` script (currently at `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process`) to match.

### P7 — Consumer-side shrink

- First-run detection in `plugins/pas/skills/pas/SKILL.md:41` creates only `.pas/workspace/` (on demand; not eagerly).
- No `.pas/config.yaml` in consumers. Any setting currently in consumer config moves to: (a) plugin-level `${CLAUDE_PLUGIN_ROOT}/pas-config.yaml`, or (b) `.pas/workspace/config.yaml` per-workspace if actually per-project.
- No `.pas/library/`, no `.pas/processes/` ever in consumers.

### P8 — Bootstrap-marketplace skill

New skill at `plugins/pas/skills/bootstrap-marketplace/SKILL.md`. Invoked when P2 detects no marketplace and user chooses "bootstrap here."

Scaffolds:
- `git init` if not already a git repo.
- `.claude-plugin/marketplace.json` with a starter entry.
- `plugins/<first-plugin>/plugin.json`, `hooks.json` stub.
- Optional: suggest `gh repo create` for a new remote.

Keep minimal — most work is a templated `Write` of the scaffold files.

### P9 — Upgrading skill + cycle-12 residual sweep

- Add checklist item for "No `.pas/processes/` in consumer (use plugin installs instead)."
- Add checklist item for "No `.pas/config.yaml` in consumer."
- Sweep remaining `.pas/library/` → `${CLAUDE_PLUGIN_ROOT}/library/` references in orchestration prose, hook error messages, and `pas-feedback-hooks.md` (dx-specialist D2, cycle-12 follow-up).
- Thin-launcher references across `creating-hooks/references/pas-feedback-hooks.md` updated.

### P10 — Cycle-14 residuals to bundle

- **#113** (N/N+1 protocol doctrine) → codify in the cycle-15 planning output as a meta-rule.
- **#112** (test-count delta) → resolve as part of P1 hook harness bump.
- **#114** (status-before-idle) → small, bundle if execution budget allows.
- **#109** (SessionStart text leak to Agent-tool subagents) → likely survives intact since SessionStart content is orthogonal to routing; re-evaluate post-cycle.

### P11 — Umbrella issue management

- Do NOT close #125 at cycle-15 end. Keep as umbrella.
- Post cycle-15 summary comment on #125 listing what shipped and what deferred.

---

## Risks (consolidated)

| ID | Risk | Severity | Mitigation (folded above) |
|---|---|---|---|
| R1 | `${CLAUDE_PLUGIN_ROOT}` silent-fail in edge contexts | HIGH | Hardened resolver P1 |
| R2 | Dogfooding — hooks modifying themselves | HIGH | Keep old resolver path as fallback during transition; smoke test from fresh session at end of cycle |
| R3 | pas-development migration breaks something | HIGH | Atomic single-commit migration; smoke test; CLAUDE.md + pr-management updated in same commit |
| R4 | Consumer write to marketplace clone is destructive during `/plugin marketplace update` | MEDIUM | Local commits only, never push; user does push; if CC's update pulls, commits survive |
| R5 | Multi-host collisions in shared marketplace clones | MEDIUM | `host-id` filename disambiguator (P4) |
| R6 | Feedback written before marketplace detection works | MEDIUM | Resolver fails loudly on miss; fallback to GitHub issue |
| R7 | Scope creep in a single cycle | MEDIUM | Explicit non-goals below |

## Explicit non-goals for cycle-15

- **No migration of downstream consumer repos** (dacforge, etc.). They continue using whatever they have until PAS 1.4.0 is installed.
- **No migration of other processes** currently in the plugin (e.g., `plugins/pas/processes/pas/`). Those are already marketplace-resident.
- **No bootstrap-marketplace push to remote** — user pushes manually.
- **No automated commit-push of feedback to marketplace** — local write + commit only.
- **No renaming `pas` skill to `manage`** (dx D1) — defer.

## Deferred to cycle-16+

- Fresh-session validation of the resolver (cycle-14 N/N+1 lesson).
- Any feedback-propagation UX improvements found in cycle-15's own workspace.
- Cross-marketplace dependency graph (when >1 user-owned marketplace exists in the wild).
- `plugin.json` `userConfig` integration for client-config paths (ecosystem-analyst Opp-3).

---

## Cycle scope size — honest self-check

This is a **large cycle**: ~8 net-new skills/files, 2 rewritten hooks, 1 large mv, ~6 sweep edits, ~4 new tests. Estimate 2–3 implementation sessions.

Compare to cycle-14 (6.4 hours, 11 commits, 25 issues closed, milestone 3). Similar scope; arguably more impact. The PR strategy stays single-PR to match pr-management conventions, but the cycle itself may legitimately span sessions. That's fine — status.yaml tracks mid-cycle state; resume works.

---

## Gate

Priorities above reflect the final framing after owner redirects. Ready to proceed to planning phase with framework-architect (solo) producing `planning/implementation-plan.md`.
