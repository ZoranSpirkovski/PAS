# feedback-analyst perspective — cycle-15 (issue #125)

**Topic:** Shift PAS to marketplace-authoritative. Marketplace plugin = source of truth. Consumer holds workspace outputs + host-specific config. PAS becomes marketplace-maintaining.

**My focus:** What do accumulated feedback signals tell us about this shift? What signals will it address, which will it *create*, which become obsolete? And — critically for *this* cycle — where will PAS session feedback actually land during and after the architectural transition?

---

## 1. Signal inventory (verified counts)

Backlog scan: `find .pas/processes/pas-development -path '*/feedback/backlog/*.md' -not -name '.gitkeep' | wc -l`

- **Total signal files:** 47 (46 pre-cycle-15 + 1 from this session — see §6 for that one)
- **By type:** 36 OQI, 1 PPU, 10 STA, 0 GATE
- **By tier:**
  - Process-root (`processes/pas-development/feedback/backlog/`): 19
  - Agent-local (`processes/.../agents/<name>/feedback/backlog/`): 15
  - Skill-local (`processes/.../agents/<name>/skills/<skill>/feedback/backlog/`): 13
- **Routing warnings log** (`.pas/feedback/warnings.log`): 6 lines spanning 2026-03-10 → 2026-04-17; unresolved targets include `skill:creating-processes`, `skill:check-self-eval`, `pas-development:process`.
- **Framework signals routed to GitHub** (`.pas/feedback/framework-routing.log`): at least 5 OK entries; most recent open issues #117–#126 are largely `[Feedback]`-prefixed.

Every signal file used in this report was read in full. I did not sample.

---

## 2. Assessment — is the shift the right move?

**Yes, with three structural caveats.** The shift is directionally correct and addresses a real duplication liability, but issue #125 underspecifies three mechanisms that feedback signals show are already fragile.

### Signals that support the shift

- **Library dedup already proved the pattern works.** Cycle 12 (per project memory) removed `.pas/library/` in favor of `${CLAUDE_PLUGIN_ROOT}/library/`. The upgrading skill at `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md:40` already calls this out: "No `.pas/library/` directory (processes reference `${CLAUDE_PLUGIN_ROOT}/library/` directly)". This is the library-side version of what #125 proposes for processes — and it worked.
- **Consumer-side process tree is a maintenance pain for cross-cutting skills.** Issue #125 cites dacforge.com trying to clean up `.pas/processes/{seo,social-media,llm-wiki}/` — a real scenario. No feedback signal argues *for* the current consumer-authoritative model. The only signal tangentially aligned with "local copy is authoritative" is `.pas/processes/pas-development/feedback/backlog/2026-03-08-orchestrator-STA-01.md` ("mid-cycle owner directive was absorbed cleanly") — that's about orchestrator flexibility, not about where process trees live.

### Signals that expose structural risks the shift will *create*

Three clusters matter here:

**Cluster A — Path resolution breaks under marketplace-authoritative.** `plugins/pas/hooks/route-feedback.sh:26-39` (`resolve_target_path`) hardcodes the consumer search path:

```
process) echo "$CWD/$PAS_ROOT/processes/$value/feedback/backlog" ;;
agent)   find "$CWD/$PAS_ROOT/processes" -path "*/agents/$value/feedback/backlog" ...
skill)   find "$CWD/$PAS_ROOT/processes" -path "*/skills/$value/feedback/backlog" ...
         [fallback] find "$CWD/$PAS_ROOT/library" -path "*/$value/feedback/backlog" ...
```

Under the new model, `$CWD/.pas/processes/` doesn't exist. Every non-`framework:pas` signal will hit the final `else` branch at line 151/178 and log `Unknown target` to `warnings.log`. The warnings log already has 6 such entries — under marketplace-authoritative **every** signal would land there unless the resolver is taught to look in the plugin. This is the single largest implementation risk.

**Cluster B — The "who owns local feedback" signals become obsolete — but only partly.** Nine signals target `agent:<name>` or `skill:<name>` (e.g., `.pas/processes/pas-development/agents/community-manager/skills/pr-management/feedback/backlog/2026-04-17-*-OQI-01.md`). Under marketplace-authoritative, those backlogs live *in the plugin*. That means:
- Feedback written from a consumer session must route *across repos* (write in consumer cwd, file into the plugin repo).
- `route-feedback.sh` currently writes files to disk (not to git). Under the new model, a disk write to the plugin repo (`${CLAUDE_PLUGIN_ROOT}/...`) would either (a) modify a read-only install path or (b) require the plugin to be installed as an editable checkout. Neither is stated in #125.
- Alternatively, feedback could stage locally and be pushed up via a new "marketplace-maintenance" operation (#125 bullet 4). This is cleaner, but **no signal in the backlog describes this workflow**; it's net-new behavior.

**Cluster C — Verification discipline must move with the feedback.** Six OQI signals (`2026-03-08-orchestrator-OQI-01.md`, `.../feedback-analyst-OQI-01.md`, `.../dx-specialist-OQI-01.md`, `.../ecosystem-analyst-OQI-02.md`, `.../qa-engineer-OQI-01.md`, `.../community-manager-OQI-01.md`) all target the *same* root cause: the 104-cloners fabrication in cycle-8. All are HIGH priority. They are addressed in `.pas/library/orchestration/discussion.md:39-47` (Data Verification Norm), which is already plugin-resident — so this cluster is *already on the correct side of the authoritative line*. No action needed from #125, but also nothing lost.

### What's missing from #125

1. **No explicit contract for `route-feedback.sh`'s resolver under the new model.** The issue says feedback should land in `${MARKETPLACE_ROOT}/plugins/<name>/.pas/processes/<name>/agents/.../feedback/backlog/` — but doesn't say *who writes it* (hook? orchestrator? a new marketplace-maintenance skill?) or *when* (session end? explicit "apply feedback" op?).
2. **No chicken-and-egg treatment for local-editable plugins.** If the marketplace plugin is installed via `claude plugin install`, it's likely under a read-only cache. Writing feedback files into it would break the install. The issue needs to specify: does every consumer need a *writeable* marketplace checkout, or does feedback stage locally and propagate via a separate operation?
3. **No migration path for existing consumer `.pas/processes/<name>/`.** The upgrading skill (item 4 at `upgrading/SKILL.md:40-42`) handles `.pas/library/` → plugin. It doesn't yet handle the parallel process case. A new checklist item is needed: "No local process tree copy (unless explicitly forked)".
4. **No treatment for the current workspace feedback path.** Agents today write `.pas/workspace/<process>/<slug>/feedback/<agent>-<session>.md`. Under the new model, *workspace* stays consumer-side (correct per #125 "workspace data still lives in the consumer"). But the workspace feedback is scanned by the Stop hook and fan-routed to `processes/<name>/.../feedback/backlog/` via `parse_and_route_signals`. If that destination is now in the plugin, the hook must bridge consumer→plugin — which is a cross-repo write with all the complications in bullet 2.

---

## 3. Risks — especially dogfooding and THIS repo

### Risk 1 (HIGH) — Dogfooding hazard for cycle-15 itself

This repo **is** the marketplace plugin (`plugins/pas/`) *and* it carries its own `.pas/processes/pas-development/` (dev-branch protected per `.claude/CLAUDE.md`). When cycle-15 executes a marketplace-authoritative migration, it will be modifying the very substrate the cycle runs on.

Signal evidence: Project memory notes cycle-14 already hit this — "I2 dogfooding lesson: modifying hooks while the cycle runs on those hooks makes live integration tests unreliable mid-cycle. Validate hook fixes from a fresh session in cycle N+1" (filed as #113).

For cycle-15 specifically, if execution rewrites `route-feedback.sh` to search plugin paths and simultaneously the test-fixtures are under `plugins/pas/hooks/tests/`, integration tests run during validation may be chasing moved goalposts.

**Mitigation:** Treat this cycle as a spec-and-scaffold cycle, not a full rip-out-and-replace. Cycle-16 (fresh session, N+1) should be the one that flips the resolver default. This echoes dx-specialist's cycle-14 signal (`2026-04-16-a4cb1041f550fb26f-OQI-02.md`) about session-boundary trust.

### Risk 2 (HIGH) — Feedback path collapse during migration

If `route-feedback.sh` is updated to resolve targets under `${CLAUDE_PLUGIN_ROOT}` *before* the consumer-side `.pas/processes/` trees are removed, the hook will find the consumer path first and keep writing there — silently defeating the migration. If it's updated *after*, there's a window where no path resolves and signals land in `warnings.log` unread.

**Mitigation:** The resolver needs a dual-search order (plugin first, consumer fallback) with a logged precedence, so both the migration window and the post-migration state produce identifiable artifacts.

### Risk 3 (MEDIUM) — The protected-dirs rule (CLAUDE.md §Protected Files) contradicts the spec

CLAUDE.md says `.pas/processes/pas-development/` MUST remain on the dev branch. Under marketplace-authoritative, this contradicts the new model — unless we explicitly carve out "PAS is its own special case: the plugin repo's `.pas/processes/pas-development/` is both the authoritative copy and the consumer copy." Feedback signal `2026-03-08-orchestrator-OQI-01.md` (fabricated-metrics cycle-8) landed in both `processes/.../feedback/backlog/` tiers; the dual location isn't new but hasn't been formalized.

**Mitigation:** Issue #125 should add a "self-hosting" clause: PAS dogfoods marketplace-authoritative by treating its own `plugins/pas/` as the authoritative copy and `.pas/processes/pas-development/` as the editable source that feeds into `plugins/pas/processes/pas/` via a (new or existing) sync operation.

### Risk 4 (LOW-MEDIUM) — Verification discipline against external metrics

Six HIGH-priority signals already codify "verify external metrics" (cluster C above). Under marketplace-authoritative, the orchestrator will sometimes be checking cross-repo state (does plugin X at version Y carry process Z?). This is a *new class of external fact*. The data-verification norm in `.pas/library/orchestration/discussion.md:39-47` is phrased around stars/clones/downloads — it should be extended to cross-repo artifact existence claims.

### Risk 5 (LOW) — Premature feedback routing

Evidence from this very session (§6): the Stop hook routed an OQI signal I had explicitly retracted, because routing happened on text emission, not on file persistence. Under marketplace-authoritative this risk compounds — retracted signals could reach the plugin repo and open spurious GitHub issues. This is adjacent to #125 but surfaces because of it.

---

## 4. Concrete recommendations

These are specific file paths / text changes. Other agents can refine.

### R1 — Extend `plugins/pas/hooks/route-feedback.sh:17-49` resolver

Add a plugin-search arm before the consumer search:

```
case "$type" in
  process)
    local found="${CLAUDE_PLUGIN_ROOT}/processes/$value/feedback/backlog"
    [ -d "$found" ] && echo "$found" && return
    echo "$CWD/$PAS_ROOT/processes/$value/feedback/backlog"
    ;;
  agent)
    local found
    found=$(find "${CLAUDE_PLUGIN_ROOT}/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1)
    [ -z "$found" ] && found=$(find "$CWD/$PAS_ROOT/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1)
    echo "${found:-}"
    ;;
  # skill/framework similarly
```

Log which arm resolved (plugin vs consumer) so migration state is visible in `framework-routing.log`.

**Caveat:** This breaks under read-only plugin installs (Risk 1, sub-point 2). If the plugin root isn't writeable, we need a staging path (see R3).

### R2 — Add checklist item 7 to `upgrading/SKILL.md`

```
### 7. No local process tree copy (except forks)
- **Expected:** `.pas/processes/<name>/` does NOT exist unless explicitly forked for consumer-specific customization.
- **Legacy:** Consumer carries full `.pas/processes/<name>/` tree copied from an earlier PAS version.
- **Fix:** Before removing, confirm the plugin still ships the same process. Back up to `.pas/processes.bak/<name>/` and delete. Mark `.pas/processes/<name>.fork` if the consumer intentionally forked.
```

Place between current items 3 and 4 so process removal precedes library removal in the workflow.

### R3 — Define a "staging feedback" convention

For read-only plugin installs, introduce `.pas/feedback/staged/<target-type>/<target-name>/<signal-id>.md` on the consumer side. A new `apply-feedback-to-marketplace` skill (under `plugins/pas/processes/pas/agents/orchestrator/skills/`) moves staged signals into the plugin repo when the user has a writeable checkout. This separates **detection** (always works, always consumer-local) from **application** (requires permissions).

### R4 — Amend `.claude/CLAUDE.md` §Protected Files with a self-hosting clause

Current text: "NEVER delete or exclude these directories when merging, cleaning, or restructuring: `.pas/processes/pas-development/`...". Add:

> **Self-hosting exception:** `.pas/processes/pas-development/` on the dev branch is the editable source for `plugins/pas/processes/pas/` (authoritative copy in the plugin). Under marketplace-authoritative semantics, both exist simultaneously by design: the `.pas/` tree is where PAS is *developed*, the `plugins/pas/` tree is what is *shipped*. Do not remove either without explicit directive.

### R5 — Extend data-verification norm in `.pas/library/orchestration/discussion.md:39-47`

Add a bullet after the "Trend claims" entry:

> - **Cross-repo artifact claims**: Any claim that a plugin at `${CLAUDE_PLUGIN_ROOT}/<plugin>/<path>` contains file X or version Y must be verified by reading the file or running `gh api` against the plugin repo. Under marketplace-authoritative, consumers and plugin authors are distinct actors; trust boundaries differ from within-repo verification.

### R6 — Add a routing-retraction mechanism

In `route-feedback.sh`, before routing a signal from `last_assistant_message`, check whether the signal ID already exists as a `.routed` sidecar from a file *that was deleted in the same session*. If so, skip. Alternatively, process files only — drop the inline `last_assistant_message` routing path at line 205-208 entirely, relying on persisted files as the single source of truth. Evidence: this session (§6).

---

## 5. Open questions for round 2

Questions I can't answer alone; I flag them for specific other agents.

**Q1 (for framework-architect):** Is there a clean architectural way to treat the plugin install path as writeable-by-default for feedback purposes, or must we accept a staging model? The choice has cascading effects on R1 vs R3.

**Q2 (for dx-specialist):** From the consumer's onboarding path, what does "my feedback accumulates on the skill, not on my repo" *feel like*? Is there a risk a user writes feedback, doesn't see it in their local backlog, and assumes it was dropped? How does the UX flag "staged / filed / applied" states?

**Q3 (for community-manager):** If feedback flows into the plugin repo as files (not GitHub issues), do we lose the current `framework:pas` → GitHub issue bridge? The routing log shows 5+ successful `gh issue create` calls. Should marketplace-local feedback stay file-based, or does all non-trivial feedback now route through the tracker?

**Q4 (for ecosystem-analyst):** Does Claude Code's plugin install mechanism support writeable plugin installs, or are plugins effectively read-only caches? The answer decides whether R1 (direct write) or R3 (staging) is feasible.

**Q5 (collectively):** Should this cycle produce the *spec* of the shift (docs + checklist + upgrade-skill additions) and defer the *hook resolver change* to cycle-16, given the dogfooding hazard? My read of the evidence says yes, but I want agreement before recommending it at planning gate.

---

## 6. The chicken-and-egg — where THIS cycle's feedback will land

This matters because cycle-15 must dogfood the very mechanism it's redesigning.

### What actually happens today

The Stop hook `route-feedback.sh` runs at every subagent shutdown. It scans two sources:
1. Files under `$FEEDBACK_DIR` (workspace feedback dir) — `.pas/workspace/pas-development/cycle-15/feedback/*.md`
2. `last_assistant_message` — any inline `[OQI-NN]` / `[PPU-NN]` blocks in the final message of the session.

For each signal it finds a `Target:` line, resolves it, and either writes a routed copy to the backlog *or* files a GitHub issue (when `Target: framework:pas` + `Route: github-issue`).

### Evidence from this very session

Earlier in this conversation I wrote `feedback-analyst-99f211ea.md` with two signals, believing I was at shutdown. Team-lead corrected me and asked me to delete the file. I deleted `.pas/workspace/pas-development/cycle-15/feedback/feedback-analyst-99f211ea.md` and the `.routed` sidecar.

**But the Stop hook had already fired:**

- The signal block survived at `.pas/processes/pas-development/feedback/backlog/2026-04-20-feedback-analyst-99f211ea-OQI-01.md` (Target: `process:pas-development`).
- The framework signal survived as **GitHub issue #126** (`[Feedback] OQI-02: Shutdown task delivered via task-list teammate...`) per `gh issue list`.

Both survived the deletion because the hook had already emitted them. The workspace file was deleted; its effects were not.

**Implication:** Under marketplace-authoritative, this same hazard scales up. A signal routed cross-repo to the plugin (possibly as a commit or a PR or a GitHub issue) cannot easily be retracted. The cycle-15 spec needs to distinguish "in flight" from "accepted" feedback.

### Where cycle-15 feedback will actually land

Given the current (consumer-authoritative) hooks are still active through this cycle:
- Workspace-phase feedback: `.pas/workspace/pas-development/cycle-15/feedback/<agent>-<session>.md`
- Post-shutdown routed copies: `.pas/processes/pas-development/{agents,agents/*/skills/*}/feedback/backlog/<date>-<source>-<signal-id>.md`
- Framework signals marked `Route: github-issue`: filed as GitHub issues on `ZoranSpirkovski/PAS` (per `framework_signal_repo` in `plugins/pas/pas-config.yaml` and the audit log line at `route-feedback.sh:98`).

This repo happens to be *both* the consumer and the plugin, so cycle-15's feedback lands in the "right place" even without any behavior change. **That's the dogfooding fig-leaf that lets us punt the resolver change to cycle-16.** For any other consumer running pas-development, post-migration their feedback would hit `warnings.log` until the hook is rewritten.

---

## 7. Summary of signal-pattern conclusions

- **36 OQI signals, 10 STA, 1 PPU, 0 GATE** across 47 files. No GATE signal — nothing in the backlog says "do NOT ship this shift". That is itself notable: there's no historical veto on the direction.
- **~6 signals in Cluster C** address verification discipline; these are already plugin-resident via `discussion.md:39-47` and are unaffected by #125 except for a cross-repo-claims extension (R5).
- **~9 agent/skill-local signals** target artifacts that would move into the plugin under the new model. Their backlog location stays valid (they're already tracking `agent:<name>` and `skill:<name>`) but the *destination of future signals with those targets* is what changes — the hook resolver is the chokepoint.
- **No signals in the backlog argue against marketplace-authoritative.** The flexibility signal (`2026-03-08-orchestrator-STA-01.md`) is about orchestrator responsiveness, orthogonal to this architectural question.
- **At least 3 high-priority gaps in #125** (bullet list in §2 end) are supported by signals: resolver contract (Cluster A), consumer→plugin write path (Cluster B), migration for existing consumer process trees (upgrading-skill gap).

My recommendation: **spec + upgrade-skill extensions + staging convention this cycle. Defer the hook resolver flip to cycle-16.** Reasoning in Risk 1 and Q5.
