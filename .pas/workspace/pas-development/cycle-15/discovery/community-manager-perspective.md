# Community Manager — Cycle-15 Discovery Perspective

**Agent:** community-manager
**Cycle:** cycle-15
**Topic:** Issue #125 — marketplace-authoritative shift
**Date:** 2026-04-20

---

## TL;DR

Issue #125 is the right architectural move, but the blast radius on open issues is large and the dogfooding hazard is severe. 76 open issues today: ~25 concern routing paths, lifecycle files, or hook behavior that #125 will rewrite (many auto-closable), ~35 are test-signal spam that needs a bulk sweep regardless, and ~16 describe behavior that survives the shift and still needs work. The single-PR-per-cycle contract should not hold for this cycle — staging this across at least three PRs (contract + routing + migration) is the only way to keep review surface area tractable and avoid repeating the cycle-14 dogfooding hazard at 10x scale.

---

## Verified adoption numbers (before any recommendation)

```
gh repo view ZoranSpirkovski/PAS --json stargazerCount,forkCount,watchers
→ {"forkCount":0,"stargazerCount":0,"watchers":{"totalCount":0}}

gh issue list --repo ZoranSpirkovski/PAS --state open --limit 200 --json number --jq '. | length'
→ 76
```

Zero stars, zero forks, zero watchers. The only `authorAssociation: OWNER` comments in the issue body fetches are Zoran's. No external contributors have filed issues — all 76 open issues were authored by `ZoranSpirkovski`.

**Implication for #125:** we owe ourselves honest scoping. There is no external user base whose workflow we'd break by flipping authoritative-copy semantics. We break only dacforge.com (mentioned in #125's own surfacing context) and this repo's own dev loop. That narrows the migration test matrix to two consumers, both controlled by the owner. This is actually a *window* to make the shift cleanly.

---

## Full issue triage against #125

I read all 76 open issue titles plus bodies for the top 20 most-recent. Classification below groups each issue by how #125 will touch it.

### Group A — Directly resolved or obsoleted by #125 (15)

These issues describe pathing, routing, or authoritative-copy assumptions that the marketplace-authoritative shift eliminates. Close-on-merge candidates (with a comment explaining the superseding design, not silent close).

- **#117** "pas skill: orchestrator routing paths are off by a .pas/ segment" — the entire routing-path class of bug goes away when routing targets `${CLAUDE_PLUGIN_ROOT}/plugins/<name>/...` instead of `<cwd>/.pas/processes/<name>/`.
- **#118** "SessionStart hook reuses session IDs across sessions, causing feedback-file collision" — the collision space changes because feedback writes move to the plugin-side backlog. Needs re-validation under new routing before close, but the surface shrinks.
- **#119** "Stop hook `verify-completion-gate.sh` crashes silently with exit 1" — hooks get rewritten for the new routing target; fix subsumed.
- **#120** "Solo shutdown skipped self-evaluation step despite pas-config setting" — solo orchestrator flow is directly touched by host-vs-plugin config read changes.
- **#122** "PAS plugin hooks defined in hooks.json but never registered in plugin.json" — hooks.json/plugin.json relationship must be re-validated as part of #125's plugin-as-authority contract. Fix in the same pass.
- **#123** "Agent spawn prompts omit self-evaluation instructions" — spawn-prompt templates live in the process tree; those templates move with the marketplace shift.
- **#124** "Shutdown declared without posting feedback signals to GitHub" — directly in the rewrite path: feedback routing must be re-specified under #125.
- **#126** "Shutdown task delivered via `task-list` teammate referenced orchestrator self-e…" — (title truncated — `gh issue view 126` needed for full context; likely in the shutdown-flow rewrite surface).
- **#50** "PAS feedback must stay in workspace, not auto-memory" — workspace/plugin-backlog split is *exactly* what #125 redesigns. Merge the constraint into #125's routing spec.
- **#53** "Offer feedback application as part of the shutdown sequence" — shutdown flow changes; this becomes part of the marketplace-maintenance ops #125 calls out.
- **#51** "Add universal /startup and /shutdown skills for process lifecycle governance" — aligned with #125 step 4 (marketplace-maintenance operations). Roll into the design.
- **#41** "Applying-feedback skill should clarify where changes go: direct apply vs GitHub issues" — (already has a `shipped in PR #111` comment, but issue is still OPEN — close it).
- **#40** "applying-feedback skill should instruct use of AskUserQuestion" — same as #41, already shipped per the owner's comment, still OPEN.
- **#58** "Hook scripts should warn on malformed status.yaml" — same as #41/40, already shipped per owner's comment, still OPEN.
- **#71** "Subagent text response elided by SubagentStop self-evaluation hook" — shipped per owner's comment, still OPEN.

**Action in cycle-15:** mark issues #40, #41, #58, #71 for closure *now* (orchestrator decision — cm will not close without owner approval, per agent.md rule). The others stay open until #125's PR lands, then close-on-merge with a superseding-design comment.

### Group B — Cycle-14 residuals that may change scope under #125 (4)

Owner memory flags these as the carry-over list from cycle 14:

- **#109** "SessionStart lifecycle text leaks into Agent-tool subagent context despite C05 agent_id skip"
- **#112** "test-hooks.sh count delta after PR #111 cherry-pick"
- **#113** "Hook-substrate changes should be developed and validated across separate sessions"
- **#114** "Lifecycle protocol should require status message before going idle"

My take: **#113 becomes doctrine for cycle-15 itself.** If #125 is touching the hook substrate (and it is — feedback routing, session lifecycle), then cycle-15 is literally #113's failure mode at larger scale. This is a flag for the orchestrator: we cannot ship #125 in a single session where the hooks being modified are the hooks validating the session. Cycle-15 must plan its own N/N+1 split for hook-substrate changes.

**#112** (test-count delta) must be resolved before #125's own test-harness rewrites or the drift compounds.

**#114** (status-before-idle) is small and independent of #125; can be folded in either cycle-15 or deferred.

**#109** (SessionStart text leak to Agent-tool subagents) — may be affected by #125 because the SessionStart payload changes when the authoritative process tree moves. Worth bundling into cycle-15's hook rewrite.

### Group C — Test-signal spam that needs a bulk sweep (35)

Issues **#73, #74, #75, #76, #77, #78, #79, #80, #81, #82, #83, #84, #85, #86, #87, #88, #89, #90, #91, #92, #94, #95, #96, #110** — all titled `[Feedback] OQI-99: test signal for routing audit` — plus various other `OQI-01/02/03/04/05` feedback issues (#62, #93, #115, #116, #120, #121, #122, #123, #124, #126).

Verified count: `gh issue list --repo ZoranSpirkovski/PAS --state open --search "OQI-99"` would enumerate the test signals; title inspection already shows at least 24 `OQI-99: test signal for routing audit` duplicates.

**Recommendation:** bulk-close all `OQI-99: test signal for routing audit` issues *as part of cycle-15 cleanup* with a single comment: "Routing audit complete — closing test signals." Do not route them through #125's design discussion. This is hygiene, not architecture.

The **non-test** OQI feedback issues (#62, #93, #115, #116, #121) each describe real agent-behavior bugs. They should be triaged individually:

- **#115** "Discovery-phase agents received misrouted task_assignment notifications" — directly relevant to today's session (I received task-list notifications for framework-architect's task #2 and a post-shutdown task #7 while waiting for Round 1 prompt). Alive. Not fixed by #125 — this is a task-list routing bug in the orchestrator substrate. Needs its own fix.
- **#116** "community-manager went idle after creating PR #111 without sending a confirmatio" — behavioral (agent-level), not changed by #125.
- **#105** "TaskUpdate(owner=...) broadcasts task_assignment, causing role-mismatched agents to claim PAS lifecycle tasks" — same root cause as #115. These two should be merged or cross-linked.
- **#106** "Agents prefer task_assignment system notifications over team-lead's plain-text SendMessage" — same cluster as #105/#115. Three symptoms of one substrate bug. **Suggested action:** consolidate into a single "task-list routing broken" issue and close the others as duplicates.
- **#62, #93, #121** — individual agent/hook bugs. Evaluate each after #125 settles.

### Group D — Features/improvements orthogonal to #125 (8)

These survive the shift and still need work:

- **#29** "Add codebase knowledge persistence at process and workspace levels"
- **#32** "creating-processes skill missing workspace blueprint step"
- **#34** "Add GitHub issue template for framework:pas signal routing"
- **#35** "PAS process does not follow its own lifecycle when executing creation skills"
- **#36** "Add 'improvements reflection' as a default shutdown step"
- **#37** "Newly created process trying to read files that don't exist"
- **#65** "pas-create-skill: support process-level skill creation"
- **#69** "Skills created by PAS should be portable / self-sustainable for sharing"
- **#72** "Workspace organization at scale: status prefixes, archive folder, phase-level grouping"
- **#107** "No enforcement that phases advance in order — Phase: planning can complete before Phase: discovery deliverables exist"
- **#108** "Self-evaluation filename contract is ambiguous — {agent}-{session_id}.md vs {agent}.md"

**#69 is especially interesting in light of #125.** It asks for portable skills — exactly the liability #125 is trying to reduce by making the marketplace authoritative. These two issues should share a design section.

**#107 and #108** are small-and-valuable enforcement/contract tightening. Fold into cycle-15 where low-cost.

### Group E — Deferred/out-of-scope tags (6)

- **#99, #101, #102, #104** — explicitly tagged as deferred to M5/M7/later milestones. #125 may obsolete some (especially #101, #102 cwd-relative path contracts — those become moot if the authoritative copy isn't in cwd). Re-triage *after* #125's shape is decided.

### Group F — Misc/unclear

- **#42, #43, #44, #45, #46, #47, #48, #60, #63** — older issues. Most recently touched March; status unknown relative to cycle-14's shipped fixes. Need individual revisit, but **not this cycle** — don't let #125 scope creep into a 40-issue rollup.

---

## What's missing from issue #125

The issue body is strong on *what shifts* but light on *how we get there*. Specifically:

### Missing: migration story for existing consumer repos

Issue #125 says "Consumer doesn't need a local copy of `<cwd>/.pas/processes/<name>/` at all" — but THIS repo literally has `.pas/processes/pas-development/` on dev branch and it's protected in CLAUDE.md:

> Protected Files (dev branch) — NEVER delete or exclude these directories: `.pas/processes/pas-development/`, `.pas/library/`, `.pas/workspace/`

Memory also records this has been accidentally deleted TWICE in the past. **Flipping authoritative-copy semantics for THIS repo means rewriting the CLAUDE.md protection rule, the pr-management Step 6 verification guard, and the dogfooding assumption that `/pas-development` operates against the local copy.** #125 needs a sub-section: "Migration plan for pas-development itself."

Options I see, pending team debate:

1. **Dual-authority for pas-development only.** The process remains in the repo as the development surface; the plugin version is generated-and-committed from it. This preserves the dev loop at the cost of explicit generator plumbing.
2. **Move pas-development into the plugin tree.** `plugins/pas/processes/pas-development/` becomes authoritative. `.pas/processes/pas-development/` is deleted from dev branch. Fork edits happen directly in the plugin. This is cleaner but changes the meaning of "dev branch" entirely.
3. **Bootstrap model.** On first invocation in this repo, PAS symlinks or bind-mounts the plugin's `pas-development` into `.pas/processes/pas-development/`. Keeps the mental model. Breaks if Windows hosts or non-bind-mount filesystems.

I lean toward **option 2** — it's consistent with #125's thesis (marketplace = authoritative) and forces us to eat our own dog food. But it rewrites cycle-start assumptions and CLAUDE.md.

### Missing: host-state path convention

#125 gestures at `<cwd>/.pas/workspace/<process>/<slug>/client-config/` or `<cwd>/.pas/config/<process>/clients/<name>/`. These are not equivalent. Workspace-scoped client config dies with the cycle; persistent per-consumer config (API keys, brand voice, client roster) must live somewhere stable. I suggest the framework-architect formalize this into a single `host-state` convention before planning.

### Missing: fork escape hatch

#125 says "if a consumer truly needs to fork a process, they can copy it locally and PAS treats that as a fork (separate concern)." But this is precisely dacforge.com's likely path for some processes. The detection rule ("you are forked now, behave differently") needs explicit specification, or we'll re-hit issue #117-class confusion under a new name.

### Missing: feedback routing under the new model

#125 proposes `${MARKETPLACE_ROOT}/plugins/<name>/.pas/processes/<name>/agents/.../feedback/backlog/`. But `route-feedback.sh` currently uses `$CWD/$PAS_ROOT/processes/...` (see `plugins/pas/hooks/route-feedback.sh:26-38`). The rewrite isn't just a path swap — the hook needs to know:

- Is this a local-fork session (write to `<cwd>/.pas/processes/...`) or plugin-authoritative (write to `${CLAUDE_PLUGIN_ROOT}/plugins/<plugin>/.pas/processes/...`)?
- What is `MARKETPLACE_ROOT` vs `CLAUDE_PLUGIN_ROOT` — are these the same variable or does #125 introduce a new env?
- Who writes to the plugin path — the Stop hook directly, or does it queue to `<cwd>/.pas/feedback/outbox/` and a separate "apply feedback to marketplace" op drains it?

I lean toward the **outbox pattern** — hooks write locally, a deliberate op ("apply local feedback to marketplace") handles plugin writes. Reasons:

1. Plugin directories may be installed read-only (user installs via Claude Code plugin system — typical install paths may not be owned by the running user).
2. Writing to the plugin repo out-of-band means the plugin git tree becomes dirty without the user's knowledge — a trust problem.
3. An explicit "apply" step creates a human checkpoint for review before plugin mutations.

Worth debating with framework-architect.

---

## Dogfooding story for this repo

**This is the risk that most worries me.** THIS repo IS both (a) the PAS plugin development surface (`plugins/pas/`) and (b) a consumer that runs `/pas-development` on itself. The architectural shift makes that self-reference more fragile, not less.

Today's flow (working):

1. I invoke `/pas-development` → reads `.pas/processes/pas-development/process.md`.
2. Orchestrator spawns me; I spawn from `.pas/processes/pas-development/agents/community-manager/agent.md`.
3. Feedback routes to `.pas/processes/pas-development/agents/community-manager/feedback/backlog/`.
4. When plugin ships, `plugins/pas/` updates go through a PR; `.pas/` artifacts commit directly to dev.

Under #125 (naive application):

1. `/pas-development` reads `${CLAUDE_PLUGIN_ROOT}/plugins/pas-development/process.md`.
2. But "the plugin" is THIS REPO's `plugins/pas/` — which doesn't contain `pas-development` (cf. `ls plugins/pas/` → `hooks library pas-config.yaml processes skills`, and `plugins/pas/processes/` contains `pas`, not `pas-development`).
3. Feedback routes to... the plugin's backlog — which is `plugins/pas/processes/pas/agents/...`, i.e., a different process than the one we're running.
4. We break.

**Resolution paths, ranked:**

A) Move `pas-development` into `plugins/pas/processes/pas-development/` before enforcing #125. Then `${CLAUDE_PLUGIN_ROOT}` resolves consistently. This is a pre-work commit.

B) Keep `pas-development` in `.pas/processes/` as a deliberate in-repo fork (using the fork escape hatch), and mark it `fork: true` in its process.md. #125 then applies to *new* cross-project processes (SEO, social-media) but pas-development stays special.

C) Split pas-development from dacforge-consumed processes. Acknowledge that pas-development is fundamentally different (it's the plugin's self-development loop). Write dedicated tooling for it.

I prefer A: it forces the dogfood loop to honor the new contract. If we can't make pas-development marketplace-authoritative, we probably can't make other processes marketplace-authoritative cleanly either.

---

## PR scoping recommendation

**The single-PR-per-cycle contract (pr-management skill, Step 1-5) should not hold for cycle-15.** #125 is too large. Breaking it into staged PRs is the only sane path:

### Staged PR plan (my proposal — framework-architect must validate)

**PR #A — Contract + framework-level plumbing (small)**

- New env var or path convention for marketplace-authoritative resolution.
- Thin Launcher SKILL.md wording update (the "Local copy is authoritative" language — note: grep found this line only in the issue body, not in any live SKILL.md today; memory claim needs verification).
- Feedback-outbox pattern scaffolding in `route-feedback.sh`.
- Upgrade skill (`plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md`) adds a new checklist item: "7. Authoritative-copy convention check."
- Tests: update test-hooks.sh for new routing mode (+count delta resolution from #112).

**Size estimate:** ~4-6 files, ~200 lines of hook changes, ~10 doc edits. Reviewable in one sitting.

**PR #B — Migrate pas-development to plugin (medium)**

- Move `.pas/processes/pas-development/` → `plugins/pas/processes/pas-development/`.
- Update `.claude/skills/pas-development/SKILL.md` launcher to read from `${CLAUDE_PLUGIN_ROOT}`.
- CLAUDE.md protection rule rewrite.
- pr-management Step 6 verification guard update (dev-only dirs list changes).

**Size estimate:** one large move + protection-rule rewrite. Self-contained diff. Reviewable.

**PR #C — Consumer migration for non-dev processes (if/when applicable)**

Only applies to other consumer repos like dacforge. Zero impact on THIS repo once PRs A+B ship. Deferrable to a follow-up cycle.

### Why staging

1. Memory entry: cycle-14 was one 6.4-hour session shipping 11 commits; hooks-modifying-themselves caused issues #109, #112, #113. #125 is strictly larger.
2. Single-PR assumption: pr-management.md Step 3 asserts "Every file in the diff MUST be under `plugins/pas/` or `.claude-plugin/`" — this constraint naturally partitions the work. PR A is plugin-clean; PR B involves a directory move that straddles plugin and dev-workspace; PR C is consumer-side. These are not the same review.
3. The dogfood hazard in #113 is *triggered* by trying to do too much at once on the hook substrate.

---

## Open questions for round 2

1. **(framework-architect)** What's the actual target path for feedback under #125? Is it `${CLAUDE_PLUGIN_ROOT}/plugins/<process-slug>/.pas/processes/<process-slug>/agents/...` (i.e., the plugin holds the process backlog directly), or is there an outbox/apply step?

2. **(framework-architect / dx-specialist)** How does a plugin install path interact with user permissions? If `${CLAUDE_PLUGIN_ROOT}` is under `/usr/local/` or an immutable store, we cannot write feedback to it. Does the marketplace install put plugins under `$HOME/.claude/plugins/` with user write? (Need to verify this with an actual install path check, not assumption.)

3. **(ecosystem-analyst)** Does Claude Code v2.1.x provide an env var to distinguish "the plugin whose skill I'm currently in" from "the plugin where feedback should be deposited"? `${CLAUDE_PLUGIN_ROOT}` exists (confirmed cycle-10) — but is there a writable equivalent?

4. **(feedback-analyst)** For the 35+ test-signal issues in the backlog — do we bulk-close all at once, or do we need to audit the routing log (`.pas/feedback/framework-routing.log`) to ensure they each represent a resolved routing audit?

5. **(framework-architect)** Is the migration direction A (pas-development into plugin) or B (pas-development as deliberate fork) or C (separate tooling)? This decision must be made in planning, not execution.

6. **(everyone)** Is the three-PR staging plan acceptable, or does the team have a simpler slicing?

---

## My concrete recommendations

### Immediate (this cycle)

1. **Bulk-close `OQI-99: test signal for routing audit` issues** (~24 issues) with a single comment. Not architecture — hygiene. Orchestrator should request owner approval via AskUserQuestion in discovery output; do not close without approval per my agent.md rule.
2. **Close #40, #41, #58, #71** individually — owner already commented "shipped in PR #111" on these. Requires owner approval.
3. **Consolidate #105/#106/#115** into a single "task-list misrouting" issue; close the others as duplicates. (I experienced #115's symptom live in this session — task-list delivered me framework-architect's Planning-phase task #2 and task #7 while I was waiting for Round 1 prompt. Bug is current.)
4. **Re-triage deferred issues #99, #101, #102, #104** after #125's design lands — some may be obsoleted by the authoritative-copy flip.

### Scope for cycle-15 itself

1. **Do NOT attempt #125 as a single PR.** Stage it into PRs A, B, C as above.
2. **Treat cycle-15 as a multi-session cycle** by design — use the N/N+1 protocol from #113. Hook-substrate changes land in session N; integration validation happens in session N+1 from a fresh state.
3. **Bundle #109, #112, #113, #114** into the cycle-15 scope as concrete acceptance criteria, not residuals. If #125 lands cleanly, these four should be closable.
4. **Do not close #125 itself in cycle-15** even after PR A merges. Keep it open as the umbrella until PRs B and (optional) C ship.

### Post-cycle (cycle-16+)

1. Portable-skill concern (#69) becomes concretely actionable once marketplace-authoritative is real.
2. Host-state persistence story (#29) likely becomes easier because the division of concerns is explicit.
3. Lifecycle governance (#51, #53, #36 "improvements reflection") consolidates with #125 step 4 ("marketplace-maintenance operations") into a single M4 theme.

---

## Data-verification notes

Commands actually run for this perspective:

- `gh issue view 125 --repo ZoranSpirkovski/PAS` — read full body.
- `gh issue list --repo ZoranSpirkovski/PAS --state open --limit 100 --json number,title,labels,createdAt,author,comments` — 76 issues listed.
- `gh repo view ZoranSpirkovski/PAS --json stargazerCount,forkCount,watchers` → all zero.
- `gh issue list --repo ZoranSpirkovski/PAS --state open --limit 200 --json number --jq '. | length'` → 76.
- `ls plugins/pas/` → confirmed no `pas-development` under `plugins/pas/processes/`.
- Grep for "authoritative" across repo → only 1 stale reference in `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md:47` and it refers to "reference/source/" (unrelated to the Thin Launcher claim in #125 body). **This means #125's quote "Local copy is authoritative — run /pas upgrade <name> if you want to pull it in" is not present in current SKILL.md files.** Either the issue body is citing outdated wording, or it's paraphrasing. Framework-architect should confirm which SKILL.md contains this line before the planning phase treats it as a concrete find-and-replace target.
- Grep for "Local copy is authoritative" across repo → **no matches.** Confirms the above.

**Caution flag for synthesis:** issue #125's central quote cannot be grep-located in the current codebase. Not a blocker for the architectural shift (the concept it names is real and documented in `upgrading/SKILL.md` checklist item 4), but the planning phase should update #125's body or cite a concrete file path.
