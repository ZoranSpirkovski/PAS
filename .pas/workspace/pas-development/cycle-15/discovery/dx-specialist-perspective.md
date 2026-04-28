# DX Specialist Perspective — cycle-15 (issue #125)

## TL;DR

Issue #125 is directionally right for cross-project skills, but the framing "shift PAS to marketplace-authoritative" is too coarse — it conflates two different user journeys (build-once-share-many vs. fork-and-evolve) and assumes a Thin Launcher wording problem that, for *this* repo, does not exist. Before we change the model, we should name the journey we are optimizing for and leave the other one supported. And the journey we ship first should be the lower-risk one: **shared library of process definitions**, not "feedback routes into an installed plugin path."

---

## Framing correction — the premise of my assignment is partially wrong

My spawn prompt said:

> audit every `plugins/pas/processes/*/SKILL.md` — how many say "Local copy is authoritative"? Propose the new wording. Verify with `grep -rn "authoritative" plugins/pas/processes/`

I did that. Here is the grep:

```
$ grep -rn "authoritative" plugins/pas/processes/
plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md:47:2. Store the original source material in `reference/source/` — this is the authoritative knowledge base
```

**One match, and it is unrelated** — it refers to the `reference/source/` dir inside a generated process (raw source material is authoritative over distilled reference docs). It is not a Thin Launcher statement.

Broader search:

```
$ grep -rn "Local copy" plugins/pas/  →  No matches found
$ grep -rn "source of truth" plugins/pas/  →  2 matches, neither a Thin Launcher
```

So the stated premise of #125 — "all current Thin Launcher SKILL.md files in the marketplace tell the user the local copy is authoritative" — **is not true in this repo today**. There is exactly one generated Thin Launcher template (in `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process`, lines 297–307) and it is already neutral:

```
---
name: ${NAME}
description: ${GOAL}
---

Read `.pas/processes/${NAME}/process.md` for the process definition.
Read `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md` for shared lifecycle protocol ...
Read the orchestration pattern from `${CLAUDE_PLUGIN_ROOT}/library/orchestration/` as specified in the process.
Execute.
```

It says nothing about authority. It points the launcher at a *relative* path (`.pas/processes/...`) for the process def, and at `${CLAUDE_PLUGIN_ROOT}/library/` for the library. That is the current model: **consumer owns its process tree; plugin owns the library.**

So the "wording rewrite" is not the problem. The underlying **path binding** in that template, plus the hook that *resolves* the path, plus the `pas:pas` router — those are the artifacts that would change under marketplace-authoritative. Wording is downstream of that.

**This matters for cycle scoping.** If we treat #125 as a wording-sweep job, we'll ship a cosmetic change that doesn't actually move authority. The real work is in:
1. `plugins/pas/hooks/route-feedback.sh:17-49` — `resolve_target_path()` hardcodes `$CWD/$PAS_ROOT/processes/...`.
2. `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process:303` — generated launcher points `.pas/processes/...`.
3. `plugins/pas/skills/pas/SKILL.md:17,27,30` — the router resolves paths "relative to `.pas/`".
4. `plugins/pas/library/orchestration/hub-and-spoke.md:25,29,88` — agents are told where to find their definition with a `.pas/processes/...` literal.

If those four don't change, no amount of SKILL.md rewording changes authority.

---

## Is the shift the right move?

**Partially yes, partially no.** Breaking it into the two actual journeys:

### Journey A — reusable cross-project skills (SEO, social-media, llm-wiki)

The motivating case in #125. User has 8 consumer repos, each needs to run a `/seo` process, and they don't want 8 forks. Marketplace-authoritative is **clearly right** here. Iteration should improve the skill for all consumers at once.

### Journey B — bespoke, project-specific processes

Someone builds a `/dacforge-release` process for exactly one codebase. It encodes *this project's* deploy steps, *this project's* gate criteria. The marketplace is irrelevant. Forcing this into the plugin path would be overengineering and would require the user to publish an entire plugin for a workflow that will never leave their repo.

**#125 only addresses Journey A but writes it as if it were the whole framework.** That's the framing error I want the team to push back on. The issue's "Out of scope" note ("if a consumer truly needs to fork a process, they can copy it locally") hand-waves Journey B as an edge case; in practice it is probably 60–80% of what users will build early on.

**Recommendation**: frame cycle-15 as introducing a **second mode** ("library-backed process"), not as replacing Journey B. A process's `process.md` frontmatter should declare its source-of-truth location; the tooling reads that declaration instead of assuming.

Proposed frontmatter field:

```yaml
authority: consumer   # default — current behavior
# or
authority: plugin     # new — plugin path is canonical; consumer holds only workspace + host-config
```

This lets existing processes keep working (zero migration), while letting new "shared skill" processes opt into marketplace-authoritative.

---

## DX of the new model — ergonomic critique

Assume we ship Journey A. Walk through the user's experience.

### Fresh consumer repo, plugin installed, no `.pas/`

**Today**: `/pas:pas I want to build a code review pipeline` → PAS clarifies → runs `pas-create-process` → `.pas/processes/code-review/` and `.claude/skills/code-review/SKILL.md` appear in the consumer. README walkthrough (README.md:61-116) reflects this. First-run detection in `plugins/pas/skills/pas/SKILL.md:39-49` creates `.pas/config.yaml` + `.pas/workspace/`.

**Under marketplace-authoritative (Journey A)**: running `/seo` as a consumer should… do what? The plugin has `/seo` already; the consumer repo just runs it. No `.pas/processes/seo/` ever needs to exist in the consumer. That's *better* ergonomically — the first-run experience is literally "install plugin, type command, it works."

**But**: the consumer still needs `/seo` to have a place to write outputs. Today that's `.pas/workspace/seo/{slug}/`. That survives — workspace stays consumer-side, which #125 correctly identifies.

**Concrete first-run change I'd recommend**: when `/pas:pas` creates a *Journey-A* process, don't scaffold `.pas/processes/{name}/` in the consumer at all. Only scaffold the Thin Launcher in `.claude/skills/{name}/SKILL.md` (which then reads from `${CLAUDE_PLUGIN_ROOT}/processes/{name}/process.md`). The `pas-create-process` script at line 303 needs a mode switch.

### Plugin not installed

**Today**: `/code-review` works because the consumer has `.claude/skills/code-review/SKILL.md` pointing at `.pas/processes/code-review/process.md`. Even without the plugin, most of the process runs; only library-dependent steps fail (agents can't read `${CLAUDE_PLUGIN_ROOT}/library/...`). Degrades gracefully-ish.

**Under marketplace-authoritative**: `/seo` is 100% dead. Thin Launcher points at `${CLAUDE_PLUGIN_ROOT}/processes/seo/process.md`, which doesn't exist. Error surfaces as a Read failure deep inside the orchestrator run — bad DX.

**Mitigation**: the Thin Launcher should check plugin presence before routing. Proposed wording for a Journey-A Thin Launcher:

```markdown
---
name: seo
description: SEO audit and improvement process.
---

This skill is provided by the PAS plugin and reads its process definition from the plugin directly.

If you see a Read error for `${CLAUDE_PLUGIN_ROOT}/processes/seo/process.md`, the plugin is not installed. Install it via:

    /plugin marketplace add ZoranSpirkovski/PAS
    /plugin install pas@pas-framework

Read `${CLAUDE_PLUGIN_ROOT}/processes/seo/process.md` for the process definition.
Read `${CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md` for shared lifecycle.
Execute.
```

Error text inline in the launcher is cheap and genuinely useful.

### Read-only / permission-blocked plugin path

Not answered by #125. A user on a locked-down machine where `${CLAUDE_PLUGIN_ROOT}` is read-only runs `/seo`. Today (consumer-authoritative) this is fine — everything writable lives under the consumer's `.pas/`. Under marketplace-authoritative with feedback routing into the plugin path, feedback writes fail silently (hooks use `2>/dev/null`) or noisily — either way, the user has no idea their feedback was lost.

**Concrete recommendation**: feedback routing must degrade gracefully.

- Attempt to write to plugin-path backlog.
- On write failure, fall back to `<cwd>/.pas/pending-upstream/{process}/{skill}/...` with a `.md` and a `README.md` in that dir explaining: "these feedback files couldn't write upstream; submit them manually at <GitHub issue link>."
- Hook log entry: `WRITE_FAILED: <path> — buffered at <fallback>`.

This is the single biggest DX hole I see in #125.

---

## Discoverability — "show my contributions"

#125 moves feedback from `<cwd>/.pas/processes/.../backlog/` (visible to the user in their own repo) to the plugin path (opaque — user doesn't normally browse `~/.claude/plugins/pas/...` or wherever CC installs plugins). This is a **serious regression** in visibility.

Today a user can answer "what feedback did I leave on the SEO skill?" with `ls .pas/processes/seo/feedback/backlog/`. Under marketplace-authoritative they have no affordance.

**Recommendation**: add a router intent.

```
/pas:pas what feedback did I submit?
```

Implementation: PAS grepps `${CLAUDE_PLUGIN_ROOT}/processes/*/feedback/backlog/*.md` (and descendant agent/skill backlogs) for entries whose filename contains the consumer's `$CWD` basename (or a host-id baked into the filename at route time), prints them grouped by target.

To support that grep cleanly, the router at `route-feedback.sh:59` should include a **host identifier** in the destination filename:

```
# today
dest_file="$target_path/${today}-${source_basename}-${signal_id}.md"
# proposed
dest_file="$target_path/${today}-${HOST_ID}-${source_basename}-${signal_id}.md"
```

Where `HOST_ID` is a stable, non-sensitive identifier (basename of `$CWD`, or a hash, or a user-configured `host_id:` in `.pas/config.yaml`). This makes "my contributions" queryable without a separate index.

---

## Error messages

Below is where I expect error UX to break under #125, plus proposed wording.

**1. Plugin not installed, Thin Launcher invoked.** Covered above — inline install instructions in the launcher.

**2. Feedback routing to unwritable plugin path.** Covered above — buffered fallback + log entry.

**3. `resolve_target_path()` returns empty.** Today at `route-feedback.sh:150-152`, an unknown target writes a warning to `$CWD/$PAS_ROOT/feedback/warnings.log`. Under marketplace-authoritative, warnings should still write *consumer-side*, not plugin-side — the consumer is the one who needs to see them. Keep this.

**4. Upgrading skill still says "move processes/ to .pas/processes/".** `upgrading/SKILL.md:30-36` describes the consumer's `.pas/processes/` as the expected state. Under marketplace-authoritative, that check becomes ambiguous: is the consumer expected to *have* `.pas/processes/` or not? The upgrade skill needs a new checklist item that says: "for plugin-provided processes, no local `.pas/processes/{name}/` should exist — if it does, it's a fork or a stale copy."

---

## README & docs impact

The README walkthrough (README.md:61-116) is entirely consumer-authoritative. Under marketplace-authoritative, the example directory tree at lines 73-88 is wrong (no `.pas/processes/code-review/` in the consumer). We have two options:

- **A. Reshape the walkthrough around Journey A** (install the plugin, run `/seo`, see feedback). Makes the framework look easier to onboard but hides the creation story.
- **B. Keep the walkthrough as Journey B** (build your own process) and add a short section: "Using shared library processes." I recommend B — the walkthrough's current value is that it *explains what PAS does*, and "build your own" is the clearer demonstration.

Proposed addition after the walkthrough (new section at README.md:~116):

```markdown
## Using Library Processes

The PAS plugin ships with library processes (e.g., `/seo`, `/social-media`) that run against any consumer repo without needing to scaffold them locally. Install the plugin, then:

    /seo audit

Outputs go to `.pas/workspace/seo/{slug}/` in your repo. Feedback you write at shutdown is routed back to the plugin's feedback backlog — so improvements accumulate across every project that runs `/seo`, not just this one.

To inspect the feedback you've submitted on a library process:

    /pas:pas what feedback did I submit?
```

Explicit, concrete, shows both the upside (accumulating improvements) and the affordance (how to find your own feedback).

---

## DX audit (every-3rd-cycle, last was cycle-12)

Things that have accumulated friction since cycle-12 that aren't strictly about #125:

### D1 — Duplicate `pas` name
`/pas:pas` as the user-facing command is a known awkwardness. `plugins/pas/skills/pas/SKILL.md` is the skill named `pas` in the plugin named `pas`. CC's namespace rule (`plugin:skill`) surfaces the doubled name. Low-severity but keeps looking weird in docs.
**Fix candidate**: rename the skill from `pas` to something like `manage` or `router`. Then it's `/pas:manage`. Breaking change — would need a deprecation cycle.

### D2 — Library references `.pas/library/` in many places despite cycle-12's dedup
Grep hit:
```
plugins/pas/library/orchestration/hub-and-spoke.md:17:   carry `.pas/library/self-evaluation/SKILL.md` for shutdown
plugins/pas/library/orchestration/hub-and-spoke.md:29:   "read `.pas/library/self-evaluation/SKILL.md`"
plugins/pas/library/orchestration/lifecycle.md:34:   "Write feedback/orchestrator.md using .pas/library/self-evaluation/SKILL.md"
plugins/pas/library/orchestration/lifecycle.md:103:  "Each agent writes self-evaluation using `.pas/library/self-evaluation/SKILL.md`"
plugins/pas/hooks/verify-task-completion.sh:46: "Use .pas/library/self-evaluation/SKILL.md for the format."
plugins/pas/hooks/verify-completion-gate.sh:107:  "Use .pas/library/self-evaluation/SKILL.md for the format"
plugins/pas/hooks/check-self-eval.sh:86:          "Format reference: .pas/library/self-evaluation/SKILL.md"
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md:9
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md:99
plugins/pas/processes/pas/agents/orchestrator/skills/creating-hooks/references/pas-feedback-hooks.md:117
```
Cycle-12 removed `.pas/library/` as a *location* but the prose in library orchestration files, hook error messages, and hook references still tells users/agents to read from `.pas/library/`. After cycle-12, that path doesn't exist in consumer repos; the correct path is `${CLAUDE_PLUGIN_ROOT}/library/`.
**Impact**: an agent following these instructions verbatim will do `Read .pas/library/self-evaluation/SKILL.md` and fail. It works today only because LLMs pattern-match around the literal path. This is a cycle-12 follow-up that was missed.
**Fix**: sweep-and-replace `.pas/library/` → `${CLAUDE_PLUGIN_ROOT}/library/` across library/, hooks/, and the `pas-feedback-hooks.md` reference doc. Low-effort, high-clarity win.

### D3 — No "what does this do?" in `plugins/pas/library/orchestration/`
The four orchestration pattern files are named by pattern (`hub-and-spoke.md`, `solo.md`, `sequential-agents.md`, `discussion.md`) but only `SKILL.md` in that directory provides the decision matrix. A user browsing the library directly has no index page that says "read SKILL.md first." Not breaking, but worth adding a one-line README or moving the decision matrix to a neutral `INDEX.md`. Skip if controversial.

### D4 — `visualize-process` not in README or router
`plugins/pas/library/visualize-process/` exists but isn't mentioned in README.md. It *is* in `plugins/pas/skills/pas/SKILL.md:29` ("Visualizing a process") but the README walkthrough ends at "apply feedback" — never tells the user they can see their process as HTML. Missed marketing.

### D5 — Thin launcher generated against `.pas/processes/...` regardless of first-run state
At `pas-create-process:303`, every new Thin Launcher is hardcoded to `.pas/processes/${NAME}/process.md`. There's no mode flag. For Journey A processes (per this cycle's direction), the launcher needs to be generated against `${CLAUDE_PLUGIN_ROOT}/processes/...` instead. This is a template fork in that script.

### D6 — README Install section doesn't mention the `/pas-development` launcher
`/pas-development` is the development workflow for evolving the plugin itself. It's referenced in the session-start hook's text (`pas-session-start.sh:97`) but never in the README. Contributors won't find it. Could stay out of README if that's by design, but worth a line under `## Contributing` (which also doesn't exist yet).

---

## Risks

**R1 — Dogfooding hazard for `.pas/processes/pas-development/`.** This repo's own `pas-development` process is consumer-authoritative by its nature: it lives here, it is this repo's. Any #125 implementation must explicitly leave `pas-development` as Journey B. If the cycle-15 implementation accidentally sweeps `pas-development` into "library-backed" mode, the protected-dirs rule in `.claude/CLAUDE.md` gets violated (dir gets deleted and expected to live in the plugin), repeating the twice-before dev-branch deletion incident called out in MEMORY.md. **Mitigation**: the authority-declaration frontmatter I proposed (`authority: consumer`) should default to `consumer` and be explicitly opted-in for Journey A. Never infer authority from presence/absence of a directory.

**R2 — Cycle-14 hook surface hasn't stabilized.** Memory notes issues #109, #112, #113, #114 as cycle-14 residuals. Feedback routing changes in cycle-15 will touch the same hook substrate. If we ship routing-to-plugin-path while #109 (SessionStart text leaking into Agent-tool subagents) is unresolved, every subagent-invoked PAS run will route feedback into the wrong place. **Mitigation**: gate #125 routing work on #109 being closed first, or explicitly carve out that the `HOST_ID` filename disambiguator is enough to recover routing-by-host even if subagent scoping is wrong.

**R3 — Multi-user contention on plugin-path feedback.** If two users have the plugin installed and both run `/seo` and both leave feedback, and the plugin path is shared (it is, if installed via CC's plugin mechanism), feedback files collide on timestamp. The `HOST_ID` in the filename mitigates this. Without it, two users writing feedback on the same day produce name collisions. **Mitigation**: implement `HOST_ID` disambiguator before shipping plugin-path routing.

**R4 — Migration story is absent from #125.** Existing consumers have `.pas/processes/{name}/` directories on disk. After #125, are those directories stale? Should `/pas:pas upgrade` delete them? The `upgrading/SKILL.md` checklist doesn't cover this. **Mitigation**: cycle-15 must produce an `upgrading/SKILL.md` checklist item for "detect orphaned local process copies of plugin-provided processes" with a clear delete-or-keep prompt.

---

## Recommendations — concrete

1. **Reframe #125 as "introduce library-backed processes" rather than "shift PAS to marketplace-authoritative."** Authority is a per-process attribute. Default stays consumer-authoritative. Opt-in to plugin-authoritative via `authority: plugin` in `process.md` frontmatter.

2. **Change `pas-create-process` (line 303) to a mode-aware template.** One branch writes a Journey-B launcher (today's behavior), one branch writes a Journey-A launcher that points at `${CLAUDE_PLUGIN_ROOT}/processes/${NAME}/process.md` and includes the plugin-not-installed inline warning shown above.

3. **Update `route-feedback.sh:17-49` (`resolve_target_path`) to honor authority.** Read the target process's `process.md` frontmatter; if `authority: plugin`, resolve to `${CLAUDE_PLUGIN_ROOT}/processes/{value}/feedback/backlog`; else today's behavior.

4. **Add `HOST_ID` to the routed filename at `route-feedback.sh:59`** so plugin-path feedback is queryable per-host. Read host-id from `.pas/config.yaml` with a default of `basename $CWD`.

5. **Add router intent `"/pas:pas what feedback did I submit?"`** to `plugins/pas/skills/pas/SKILL.md:21-31`, grepping the plugin-path feedback backlogs filtered by `HOST_ID`.

6. **Add graceful-degradation write logic to `route-feedback.sh`** for plugin-path write failures: buffer at `<cwd>/.pas/pending-upstream/` with a README explaining the manual path.

7. **Sweep `.pas/library/` → `${CLAUDE_PLUGIN_ROOT}/library/` across library orchestration files, hook error messages, and `pas-feedback-hooks.md`** (D2 above, cycle-12 follow-up).

8. **Extend `upgrading/SKILL.md` checklist** with: (a) detect legacy `.pas/processes/{name}/` directories that duplicate plugin-provided processes and prompt to delete; (b) retire the "local library copy" check (legacy is already gone, check is now a no-op from cycle-12).

9. **Update README walkthrough** to add a short "Using Library Processes" section (text proposed above) without removing the Journey-B walkthrough.

10. **Explicitly mark `pas-development` as `authority: consumer`** in its process.md frontmatter as an anti-regression anchor for R1.

---

## Open questions for round 2

- **Q1 (framework-architect)**: does the authority-per-process model I'm proposing fragment the framework too much, or is it the right granularity? An alternative is authority-per-process-set (the plugin declares a list of library processes and everything else is consumer; no per-process flag). Which has cleaner implementation in hook scoping?

- **Q2 (hook-specialist / whoever owns routing)**: is there a cleaner mechanism than reading `process.md` frontmatter from inside the hook to decide routing? Hooks run under `set -euo pipefail`, and frontmatter parsing in bash is fragile. Could we express authority in a dedicated `.pas/authority-map.yaml` the plugin writes on install, and have the hook look up by name?

- **Q3 (ecosystem-analyst)**: do CC plugins actually install to a shared location on a given machine, or is `${CLAUDE_PLUGIN_ROOT}` per-user? The "multi-user contention" risk in R3 depends on the answer. If per-user, R3 is moot.

- **Q4 (process-owner)**: should cycle-15 explicitly ship Journey A for *one* canonical library process (e.g., convert a real skill to `authority: plugin`) as a validation step, or is this cycle pure framework plumbing with no target process? I'd argue the former — framework changes without an integration test are the cycle-14 dogfooding lesson restated.

- **Q5 (everyone)**: the `HOST_ID` disambiguator — is a basename of `$CWD` (e.g., `dacforge-site`) ergonomic enough, or should we require users to set a real identifier in `.pas/config.yaml`? Tradeoff: defaults mean zero-configuration but risk collision; explicit config means better queries but breaks zero-conf first-run.

---

## What's missing from #125

- No migration story for existing consumer-side `.pas/processes/` (R4).
- No write-failure / read-only path UX (covered above).
- No per-user feedback discoverability story ("show my contributions").
- No acknowledgment of Journey B existing as a separate, legitimate use case.
- No integration test proposal — which canonical skill gets converted to validate the model end-to-end.
- No backwards-compatibility guarantee. Does a v1.3.3 consumer still work when the plugin upgrades to v1.4.0 with marketplace-authoritative? Today #125 implies we flip the world; that's probably too sharp.
