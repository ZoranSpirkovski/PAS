# Framework Architect — Cycle-15 Perspective

**Driving issue:** [#125 Architectural shift: marketplace-authoritative](https://github.com/ZoranSpirkovski/PAS/issues/125)
**Session:** 99f211ea
**Scope of this perspective:** authority inversion mechanics, feedback-path rewrite, host-config convention, fork semantics, migration, bootstrap.

---

## 1. Overall assessment — is the shift correct?

**Yes, directionally. But #125 over-simplifies the mechanics.**

The intent is right: cross-cutting skills (SEO, social-media, llm-wiki) should not fan out into N consumer-owned forks. One source of truth → feedback concentrates → iteration compounds → every consumer benefits. That's a real net win over today's copy-and-diverge reality.

What #125 under-specifies:

1. **Authority is already partially inverted.** It is not the all-or-nothing flip the issue implies. Read today's code:
   - `plugins/pas/skills/pas/SKILL.md:57` says: *"Processes reference the plugin library directly via `${CLAUDE_PLUGIN_ROOT}/library/` — no copying needed."* The library is already marketplace-authoritative (as of cycle-12; I verified in `upgrading/SKILL.md:40`).
   - `pas-create-process:295-307` still generates a thin launcher that reads `.pas/processes/${NAME}/process.md` — process *definitions* are still consumer-authoritative.
   - So: **library = authoritative-in-plugin. Processes = authoritative-in-consumer. Workspace = always consumer.** The shift in #125 is specifically *promoting processes* into the same category as library.

2. **"Feedback needs to route into the marketplace plugin's path" (#125 point 1) is the hardest part.** Today `route-feedback.sh` targets paths under `$CWD/$PAS_ROOT/processes/...` (see `route-feedback.sh:26-37`). The plugin install directory is typically **read-only on the user's machine** — it lives under `~/.claude/plugins/marketplaces/.../plugins/pas/` or similar. We cannot `mkdir -p` and `echo >` into that path safely. This is the central constraint the issue ignores.

3. **The "Local copy is authoritative — run /pas upgrade" language #125 quotes does not appear in current plugin source.** I grepped the entire `plugins/pas/` tree:
   ```
   $ grep -rn 'Local copy' plugins/pas/ .pas/processes/
   (no matches)
   ```
   That wording lives in downstream consumer projects (dacforge, etc.) that were initialized from earlier PAS versions. We should not chase a literal line that is no longer in our tree. We should decide the *current* behavior of `pas-create-process` and the upgrade skill — which is the real knob.

**Verdict: the shift is correct in spirit, but the implementation plan must be written against the actual substrate, not against #125's prose.** The real question cycle-15 has to answer is: *what exactly changes in `pas-create-process`, `upgrading/SKILL.md`, and `route-feedback.sh` — and what stays the same?*

---

## 2. Authority inversion mechanics

### 2.1 The anchor variable

**`${CLAUDE_PLUGIN_ROOT}` is the correct anchor.** No new variable needed.

Evidence:
- `plugins/pas/hooks/hooks.json:8` already uses it for hook command paths.
- `plugins/pas/hooks/lib/guards.sh:11` defensively resolves it by walking two levels up from the `lib/` file if the harness did not export it — so even older CC versions work.
- Cycle-10 ecosystem findings (in MEMORY.md) confirmed the variable works for library dedup.
- Thirteen files in `plugins/pas/` already reference it (grepped).

Proposing a new env var (e.g. `${MARKETPLACE_ROOT}`) just to rename a confirmed-working anchor would be churn. Reuse `${CLAUDE_PLUGIN_ROOT}`.

### 2.2 What "authoritative" means per resource type

| Resource | Today | Proposed (marketplace-authoritative) | Read path |
|---|---|---|---|
| Library skills | Plugin | Plugin (unchanged) | `${CLAUDE_PLUGIN_ROOT}/library/` |
| Process definition (`process.md`, agents, skills under process) | Consumer (`.pas/processes/{name}/`) | **Plugin** (`${CLAUDE_PLUGIN_ROOT}/processes/{name}/`) | new — via thin launcher |
| Hooks | Plugin | Plugin (unchanged) | `${CLAUDE_PLUGIN_ROOT}/hooks/` |
| Workspace (execution instances, status.yaml) | Consumer | **Consumer** (unchanged — per-invocation data) | `<cwd>/.pas/workspace/` |
| Host config (e.g. `seo/config/clients/dacforge/`) | Consumer, inside process tree | **Consumer**, outside process tree | new — see §4 |
| Process-level feedback backlogs | Consumer | **Plugin**, with fallback | see §3 |
| Session feedback (per-agent self-eval) | Consumer workspace | Consumer workspace (unchanged — ephemeral) | `<cwd>/.pas/workspace/{proc}/{slug}/feedback/` |

**The key insight:** the shift does not re-home session-level artifacts. Only *durable process definition* and *routed (persisted) feedback backlogs* move. Everything ephemeral stays in `<cwd>/.pas/workspace/`.

### 2.3 The read-only install problem

Under a normal plugin install, the plugin's filesystem is owned by the plugin marketplace mechanism and should be treated as **read-only at runtime**. This is the single biggest constraint #125 does not address.

Proposed resolution:

- **Read path = plugin.** Hooks and skills resolve process definitions from `${CLAUDE_PLUGIN_ROOT}/processes/{name}/` by default.
- **Write path = consumer "outbox".** Routed feedback goes to a consumer-owned outbox (`<cwd>/.pas/outbox/{process}/backlog/`) during a session. A dedicated PAS operation ("propagate outbox to marketplace") is the *only* thing that writes into the plugin tree — and it only does so when the consumer has the plugin source checked out locally (i.e. when `${CLAUDE_PLUGIN_ROOT}` points at a git working tree, not a frozen install).
- This makes PAS the *marketplace-maintaining* skill #125 describes: the act of moving feedback from consumer outbox → plugin backlog is an explicit user-consented operation, not a hook-fire-and-forget.

---

## 3. Feedback path rewrite

### 3.1 Today's behavior (verified against `route-feedback.sh`)

```
route-feedback.sh:26-37
  process: $CWD/.pas/processes/{value}/feedback/backlog
  agent:   find $CWD/.pas/processes  -path "*/agents/{value}/feedback/backlog"
  skill:   find $CWD/.pas/processes  -path "*/skills/{value}/feedback/backlog"
           fallback: find $CWD/.pas/library -path "*/{value}/feedback/backlog"
  framework: handled by route_framework_signal() → gh issue create
```

Framework signals are already well-routed — `route_framework_signal` reads `framework_signal_repo` from `$PAS_CONFIG` (consumer) or `$CLAUDE_PLUGIN_ROOT/pas-config.yaml` (plugin), and **hard-refuses if both are empty** (`route-feedback.sh:91-94`, cycle-14 fix). This is the pattern we should generalize.

### 3.2 Proposed behavior under marketplace-authoritative

Two-stage resolution:

1. **Resolve the canonical artifact path.** Given `Target: skill:seo-keyword-research`, search in this order:
   - `${CLAUDE_PLUGIN_ROOT}/processes/*/skills/seo-keyword-research/feedback/backlog/` (plugin — authoritative)
   - `${CLAUDE_PLUGIN_ROOT}/library/seo-keyword-research/feedback/backlog/` (plugin library)
   - `<cwd>/.pas/processes/*/skills/seo-keyword-research/feedback/backlog/` (**consumer fork** — only if this tree exists, see §5)
   - Fail with a warning to `<cwd>/.pas/feedback/warnings.log` (same as today's default path when target doesn't resolve).

2. **Decide write destination based on plugin writability.**
   - If the plugin path is writable (plugin source is a git working tree, detected by `[ -w "$CLAUDE_PLUGIN_ROOT" ] && [ -d "$CLAUDE_PLUGIN_ROOT/.git" ]` OR by a marker file like `${CLAUDE_PLUGIN_ROOT}/.pas-plugin-dev`), write directly into the plugin backlog.
   - Otherwise, write to `<cwd>/.pas/outbox/{process}/{skill|agent}/{name}/feedback-{date}-{id}.md`. This is the consumer-side queue that a later explicit operation (`/pas propagate-feedback`) drains into the plugin.

This gives us: **one-source-of-truth for plugin-dev workflows (where the user is `ZoranSpirkovski/PAS`), and safe outbox-queuing for end-user consumers who run a frozen install.**

### 3.3 Concrete changes to `route-feedback.sh`

Rewrite `resolve_target_path()` (`route-feedback.sh:17-49`) to:
- Add a search-roots list (plugin first, consumer fallback).
- Return both a path AND a `write_mode` (direct vs outbox).
- Wire `route_signal()` to respect `write_mode`.

Add a helper in `lib/guards.sh` next to `resolve_pas_project_root()`:

```bash
# Resolve the authoritative location for a process/skill/agent artifact.
# Echoes: "<path>\t<write_mode>" where write_mode is 'plugin' | 'outbox' | 'consumer-fork'.
resolve_artifact_root() { ... }
```

### 3.4 What stays the same

- Framework signal routing (`route_framework_signal()`) is already correct — #125 does not alter it.
- Session feedback writing (self-eval files) stays in `<cwd>/.pas/workspace/{process}/{slug}/feedback/`. Only the *promotion* of a signal from session-feedback to process-backlog changes.
- The parser (`parse_and_route_signals`) needs no change — the signal format is untouched.

---

## 4. Host-config convention

### 4.1 Proposed canonical path

**`<cwd>/.pas/config/{process}/{key}/...`** — a new top-level `.pas/config/` namespace, parallel to `.pas/workspace/`.

The #125 examples (`seo/config/clients/dacforge/`) collapse to: `<cwd>/.pas/config/seo/clients/dacforge/{client.yaml, ...}`.

Why this shape rather than the alternative (`<cwd>/.pas/workspace/{process}/{slug}/client-config/`):

- **Host config is durable across slugs.** A client roster for SEO doesn't reset between cycles. Putting it under `workspace/{slug}/` makes it look ephemeral and invites accidental deletion when cleaning old workspaces.
- **Host config is process-scoped, not slug-scoped.** Multiple runs share the same client definitions.
- **Top-level `.pas/config/` mirrors existing `.pas/` structure** — consumers already have `.pas/config.yaml` at the top; `.pas/config/{process}/` generalizes that same pattern.
- **Discoverability via convention.** Process skills can look up `<cwd>/.pas/config/{process-name}/` deterministically. The plugin skill code needs to know ONE path. No ambiguity.

### 4.2 Read protocol

A skill that needs host config does:

```bash
HOST_CONFIG_ROOT="${PAS_PROJECT_ROOT:-$(pwd)}/.pas/config/{process-name}"
if [ -d "$HOST_CONFIG_ROOT" ]; then
  # read from here
fi
```

For non-shell skills (plain SKILL.md with Read directives), the convention lives in the process README and is invoked as: *"Read client config from `.pas/config/seo/clients/{client}/client.yaml`."*

### 4.3 Migration from the old `seo/config/clients/` shape

This is a `pas upgrade` responsibility — see §6.

---

## 5. Fork semantics

### 5.1 The signal

**Explicit signal: the presence of `<cwd>/.pas/processes/{name}/process.md`.**

Not a config flag. Not a detected-filesystem-heuristic. The presence or absence of a real consumer-side process definition *is* the signal. This matches how the library dedup shift already works:
- No `.pas/library/` → consumer uses plugin library.
- `.pas/library/` present (legacy) → `upgrading/SKILL.md:40-42` treats it as fork-like and offers to back up + remove.

We apply the same logic to processes:

| Consumer state | PAS interpretation | Behavior |
|---|---|---|
| `.pas/processes/{name}/process.md` does **not** exist | Default (marketplace-authoritative) | Resolve from `${CLAUDE_PLUGIN_ROOT}/processes/{name}/` |
| `.pas/processes/{name}/process.md` **exists** | **Fork** (consumer owns this process) | Resolve from `.pas/processes/{name}/`, ignore plugin copy |

### 5.2 What fork mode changes

- **Read path** flips to consumer tree.
- **Feedback write path** also flips to consumer tree (no outbox; fork owns its own backlog).
- **Upgrades do NOT touch the fork.** Plugin updates never clobber forked processes. The user has explicitly said "I've diverged; leave me alone." `pas upgrade` reports the fork and moves on.
- **Thin launcher wording** notes the fork state when printed.

### 5.3 Keeping forks rare

The current default should actively discourage forking. `pas-create-process` generates a thin launcher that points at the plugin path — no consumer copy. To fork, the user runs an explicit `/pas fork <process>` that copies the plugin's process tree into `.pas/processes/{name}/` and marks it. This keeps forks deliberate, not accidental.

---

## 6. Migration — the THIS-repo problem

This is the highest-risk part of cycle-15 and the memory log already flags it twice: **"NEVER delete `processes/pas-development/`"**.

### 6.1 Classification of existing trees

Walking `.pas/processes/` on this repo:

- `.pas/processes/pas-development/` → **fork by necessity** (the pas-development process is how we develop PAS; it *cannot* live only in the plugin because we're editing the plugin). This stays in the consumer tree. Mark it as a fork.

Walking downstream consumer repos (per #125 context):

- `.pas/processes/seo/`, `.pas/processes/social-media/`, `.pas/processes/llm-wiki/` → **legacy authoritative copies** that should migrate to either:
  - **Fork** (if the consumer has hand-edited them) — stays where it is, marked.
  - **Delete** (if identical or near-identical to plugin) — back up and remove; plugin becomes the source.

### 6.2 Migration command — proposal

Add a new operation `/pas migrate-to-marketplace` (new skill under `processes/pas/agents/orchestrator/skills/migrate-to-marketplace/`) that:

1. **Scans** `<cwd>/.pas/processes/*/`.
2. **For each process, diffs** against `${CLAUDE_PLUGIN_ROOT}/processes/{same-name}/` if it exists.
3. **Classifies** each:
   - `identical` → safe to delete (plugin supersedes).
   - `diverged` → ask user: mark as fork, or overwrite with plugin version, or compare+merge.
   - `orphan` (no plugin equivalent) → consumer-only process, stays where it is (not a fork — just a consumer-specific process).
4. **Migrates host config:** for each process, scan `.pas/processes/{name}/config/` (and common variants like `.pas/processes/{name}/clients/`) and move the contents to `.pas/config/{name}/`.
5. **Writes a backup** to `.pas/processes.bak-{date}/` before removing anything. Non-destructive by default.

This skill is explicitly a bootstrap exception (`implementation-planning/SKILL.md:84-89`) — it is not generated with `pas-create-skill`, because it operates *on* PAS itself.

### 6.3 pas-development specifically

**Do not touch `.pas/processes/pas-development/` in this cycle.** Reasons:
1. It is used to *run* cycle-15. Editing it mid-cycle is the exact dogfooding hazard from cycle-14 (memory: "modifying hooks while the cycle runs on those hooks makes live integration tests unreliable"; issue #113 is still open).
2. pas-development is legitimately consumer-specific — it has no plugin counterpart to migrate to.
3. If we later want to move pas-development into the plugin as a `processes/pas-development/` tree, that is a separate cycle with its own validation plan.

Propose: classify `pas-development` as **orphan** in the migration skill — explicitly flagged as "this process has no plugin equivalent; it stays in the consumer tree." Not a fork, not legacy. Orphan.

---

## 7. Bootstrap under the new model

### 7.1 Today's first-run logic

Per `plugins/pas/skills/pas/SKILL.md:41-47`:
> 1. Create `.pas/config.yaml` with defaults
> 2. Create `.pas/workspace/` directory

That's it. There is no copying of processes into `.pas/` anymore (cycle-12 dedup removed library copying; processes were never copied by first-run because they are created on demand via `pas-create-process`).

### 7.2 Proposed first-run under marketplace-authoritative

Minimal change:

1. Create `.pas/config.yaml`.
2. Create `.pas/workspace/`.
3. **(new)** Create `.pas/config/` (empty — for per-process host config).
4. **(new)** Create `.pas/outbox/` (empty — for routed feedback that awaits propagation).

No process trees are copied. No library is copied. Thin launchers, if any, point to plugin paths.

### 7.3 What about thin launchers?

`pas-create-process:295-307` currently writes `.claude/skills/{name}/SKILL.md` with the line:
```
Read `.pas/processes/${NAME}/process.md` for the process definition.
```

Proposed: change to:
```
Read `${CLAUDE_PLUGIN_ROOT}/processes/${NAME}/process.md` for the process definition.
Fork override: if `.pas/processes/${NAME}/process.md` exists, read that instead.
```

This makes the thin launcher encode the fork-override rule in plain text, visible at skill-load time. Simple, auditable, no hook magic.

### 7.4 Process creation flow

Today `pas-create-process` writes to `<cwd>/.pas/processes/{name}/`. Under the new model, `pas-create-process` is *marketplace-plugin maintenance* (#125's point 4), so:

- **Default target = plugin tree** (`${CLAUDE_PLUGIN_ROOT}/processes/{name}/`) — i.e., writing directly into the plugin source. This is the "marketplace-maintaining" operation.
- **Require that `${CLAUDE_PLUGIN_ROOT}` is a git working tree** (safety check: `git rev-parse --show-toplevel` succeeds there). If not, the command refuses with "PAS plugin is not editable from this environment — clone the plugin repo to enable marketplace-maintaining operations."
- **After generation, bump plugin version** using `plugins/pas/hooks/lib/bump-version.sh` (memory: already exists from cycle-12).
- **For forks:** `--fork` flag writes to `<cwd>/.pas/processes/{name}/` instead, marking it fork-local. Opt-in, not default.

This is the one big behavioral change that makes PAS into the "marketplace-maintaining" tool #125 describes. It should land as its own sub-cycle after the routing/bootstrap pieces are solid.

---

## 8. Risks I see

### R1 — Read-only install (HIGH)

Most real consumers install PAS via plugin-install, which may not give the user write access to the plugin tree. If cycle-15 ships code that assumes writability (e.g., `route-feedback.sh` writing into `${CLAUDE_PLUGIN_ROOT}`), it will silently or loudly fail in production. **Mitigation:** outbox pattern (§3.2), writability check before any plugin write.

### R2 — Dogfooding the shift on THIS repo (HIGH)

This repo has `.pas/processes/pas-development/` as authoritative. The shift, if applied literally, would classify it as legacy and migrate it away. We must explicitly mark pas-development as orphan-and-never-touch (§6.3). Same memory-documented hazard as cycles past: "has happened TWICE."

### R3 — Fork detection false-positives (MEDIUM)

If the fork signal is "consumer-side `processes/{name}/process.md` exists," then leftover stale copies from pre-cycle-15 consumers will be silently treated as forks — even though the user didn't intend that. **Mitigation:** `pas upgrade` explicitly asks on each such directory rather than auto-classifying.

### R4 — Host-config path churn (MEDIUM)

Downstream consumers (dacforge) already have `.pas/processes/seo/config/clients/{client}/` populated. Migrating this to `.pas/config/seo/clients/{client}/` is straightforward but must be lossless. **Mitigation:** migrate-to-marketplace skill (§6.2) includes the config-relocation step; back up before moving.

### R5 — Mid-cycle hook changes breaking the cycle (MEDIUM)

Cycle-14 issue #113 is still open. If cycle-15 modifies `route-feedback.sh`, the cycle that is *using* that hook to route its own feedback can fail mid-flight. **Mitigation:** treat hook rewrites as N/N+1 — write tests in cycle-15, ship in cycle-15, but validate the behavior from a fresh cycle-16 session. Don't claim "hook works" until a fresh session confirms.

### R6 — Feedback targets that pre-date the shift (LOW)

Existing feedback files in workspaces carry `Target: skill:X` entries that were written expecting the consumer-tree path. After the shift, `route-feedback.sh` will route them to the plugin tree or outbox. This is actually desirable (accumulated feedback lands on the skill), but may surprise users who expected it local. **Mitigation:** upgrade skill announces the change clearly.

---

## 9. Concrete recommendations

In priority order, each with a specific file + change:

### REC-1 — Rewrite `route-feedback.sh:resolve_target_path()`

- Add search-path list: plugin → consumer-fork → consumer-library.
- Emit a `write_mode` alongside the path.
- Update `route_signal()` to use outbox when not writable.
- Add `lib/guards.sh::resolve_artifact_root()` helper.

### REC-2 — Change `pas-create-process:295-307` thin launcher template

- Template reads plugin process first, falls back to consumer fork.
- Remove the implicit assumption that consumer always holds the process.

### REC-3 — Update `upgrading/SKILL.md` items 3 and 5

- Item 3 ("processes location"): currently says consumer owns `.pas/processes/`. Expand to handle the three cases — legacy-to-delete, fork, orphan.
- Item 5 ("thin launcher references"): currently says launchers reference `${CLAUDE_PLUGIN_ROOT}/library/`. Extend to say launchers reference `${CLAUDE_PLUGIN_ROOT}/processes/{name}/` with a fork override.

### REC-4 — Add new skill `migrate-to-marketplace`

Path: `plugins/pas/processes/pas/agents/orchestrator/skills/migrate-to-marketplace/SKILL.md` (bootstrap exception — created manually).

Behavior described in §6.2.

### REC-5 — Add new convention: `<cwd>/.pas/config/{process}/`

- Document in `plugins/pas/skills/pas/SKILL.md` under "Project Convention."
- Document in `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md` — generated processes get an example reference to this path.
- Update first-run detection in `plugins/pas/skills/pas/SKILL.md:41` to create `.pas/config/` (empty).

### REC-6 — Add new convention: `<cwd>/.pas/outbox/`

- Document alongside `.pas/config/`.
- `route-feedback.sh` writes here when plugin is not writable.
- Add a `/pas propagate-feedback` operation (new skill or extension of upgrading skill) that drains outbox → plugin backlog when user explicitly asks.

### REC-7 — Explicitly protect `pas-development` process

- In `migrate-to-marketplace` skill: hard-skip `pas-development` with a comment.
- In `.claude/CLAUDE.md` "Protected Files" section: already says "NEVER delete `.pas/processes/pas-development/`" — keep. Consider adding an explicit "NEVER migrate to plugin" bullet to close the loop.

### REC-8 — Do NOT add a new env var

Reuse `${CLAUDE_PLUGIN_ROOT}`. Any new variable is churn.

### REC-9 — Version-bump on marketplace-maintenance ops

When `pas-create-process` writes into the plugin tree, invoke `plugins/pas/hooks/lib/bump-version.sh` (memory-confirmed present). When it writes a fork in consumer tree, do NOT bump. This differentiates plugin-maintenance from consumer-operation cleanly.

### REC-10 — Defer actual process migration to cycle-16+

Cycle-15 ships the *mechanism* (routing rewrite, config/outbox conventions, upgrade-skill additions, migration skill). It does not ship the *per-process migration* (moving dacforge's SEO into the plugin, or similar). That is user-consented, per-consumer work that happens after the mechanism is stable.

---

## 10. What should NOT change (stability anchors)

- **`${CLAUDE_PLUGIN_ROOT}` as the plugin anchor.** Already works, already deployed in 13 files. Leave alone.
- **Framework signal routing.** `route_framework_signal()` already has the hard-refusal behavior (cycle-14 fix). Do not touch it.
- **Session-level feedback path.** `<cwd>/.pas/workspace/{proc}/{slug}/feedback/{agent}-{session}.md`. This is ephemeral; no reason to move it. `check-self-eval.sh` and `verify-task-completion.sh` both depend on it.
- **Status tracking.** `status.yaml` schema, session lifecycle, completion gate — all stay.
- **Hook dispatch location.** `${CLAUDE_PLUGIN_ROOT}/hooks/` — unchanged.

The cycle-14 cluster of stability fixes (agent-type scoping, worktree-aware resolution, safe-fail grep) is load-bearing for everything I'm proposing. Do not regress any of it.

---

## 11. Open questions for round 2

### Q1 — (for ecosystem-analyst) Does Claude Code expose plugin-source writability?

Is there a documented CC API/variable indicating whether `${CLAUDE_PLUGIN_ROOT}` is an editable working copy vs a frozen install? If not, I propose we detect it via:
```bash
[ -d "${CLAUDE_PLUGIN_ROOT}/.git" ] && [ -w "${CLAUDE_PLUGIN_ROOT}" ]
```
…but I'd rather use an official signal if one exists. What does `gh`/CC docs say?

### Q2 — (for community-manager) Who actually installs PAS as a frozen plugin vs as a git checkout?

Zero external adoption today (memory). If every "consumer" is actually a separate checkout of the PAS repo, the read-only concern (R1) is largely theoretical and we can ship simpler code. If dacforge and others install via marketplace (plugin-install), outbox is required. Please confirm the real deployment mix.

### Q3 — (for feedback-analyst) Have we accumulated feedback that targets plugin paths already?

If any existing `Target: skill:X` signals in the backlog already resolve correctly under the new plugin-first resolution, we can verify the rewrite is backward-compatible. If they all target paths that no longer exist, we need an explicit migration of the backlog too.

### Q4 — (for dx-specialist) Is `.pas/config/` vs `.pas/workspace/{slug}/client-config/` the right shape for users?

My §4 argument is durability-based. But a DX perspective on what users find discoverable might override this. What does the user see when they `ls .pas/` and what makes sense as a first-encounter?

### Q5 — (team) Scope of cycle-15: mechanism-only or mechanism + first migration?

I propose mechanism-only (REC-10). If the team wants cycle-15 to also migrate a specific consumer process end-to-end, that's a materially larger cycle.

### Q6 — (team) Do we split cycle-15 into a planning sub-cycle + implementation sub-cycle?

Given R5 (mid-cycle hook changes breaking the cycle that runs on those hooks), I'd prefer to lock the plan in cycle-15 and ship the rewrite in cycle-16 so we can validate from a fresh session. That trades ship-speed for dogfooding safety. Worth debating.

---

*End of framework-architect perspective.*
