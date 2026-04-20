# Ecosystem Analyst Perspective — Cycle 15 (Issue #125)

**Scope**: external-facing view of issue #125's proposed shift to "marketplace-authoritative" PAS. Verifies Claude Code plugin semantics, compares to package-manager precedents, assesses adoption implications, and flags roadmap-timing risks.

**Verification norm**: every external claim below is backed by a URL, a documented quote, or an observable command on this machine. No speculation where evidence is checkable.

---

## TL;DR

The core framing of #125 is correct — *conceptually* a plugin should be the source of truth for its content. But the **specific mechanism it implies — "feedback routes into the marketplace plugin's path" under `${CLAUDE_PLUGIN_ROOT}`** — collides head-on with two explicit Claude Code design contracts:

1. `${CLAUDE_PLUGIN_ROOT}` points at a **cache directory that changes when the plugin updates**, and the docs are explicit that "files you write here do not survive an update."
2. There is a purpose-built, update-persistent location — **`${CLAUDE_PLUGIN_DATA}`** — but it's still user-local (`~/.claude/plugins/data/...`), not "in the marketplace repo."

What #125 actually wants — feedback accumulating *on the skill, for everyone* — is a *sync-upstream* problem, not a *write-into-the-plugin-dir* problem. That distinction is what round 2 needs to pin down.

Zero external adoption today (0 stars / 0 forks / 0 watchers, verified below) means migration cost is nearly free *for our consumers*, so the window to restructure is open. But the adoption signal this sends — "PAS couples you to the PAS marketplace" — is a forward cost worth weighing.

---

## 1. Verified facts about Claude Code plugins

### 1.1 Where installed plugins live

Source: <https://code.claude.com/docs/en/plugins-reference> → "Plugin caching and file resolution".

> "For security and verification purposes, Claude Code copies marketplace plugins to the user's local plugin cache (`~/.claude/plugins/cache`) rather than using them in-place. ... Each installed version is a separate directory in the cache. When you update or uninstall a plugin, the previous version directory is marked as orphaned and removed automatically 7 days later."

Observed on this machine:

```
$ find ~/.claude/plugins/cache -maxdepth 4 -type d
~/.claude/plugins/cache/pas-framework/pas/1.3.3
~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1
~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.5
...
```

Path pattern: `~/.claude/plugins/cache/{marketplace-name}/{plugin-name}/{version}/`. Per-version directories. That confirms the doc claim.

### 1.2 `${CLAUDE_PLUGIN_ROOT}` — explicit contract

Source: same page → "Environment variables".

Quoted verbatim:

> `${CLAUDE_PLUGIN_ROOT}`: the absolute path to your plugin's installation directory. Use this to reference scripts, binaries, and config files bundled with the plugin. **This path changes when the plugin updates, so files you write here do not survive an update.**

Emphasis mine. This is the *documented* answer to "is `${CLAUDE_PLUGIN_ROOT}` writable for persistent state?" — **no, treat it as read-only for anything the user cares about.** The path is OS-writable (I verified: `touch` into `~/.claude/plugins/cache/pas-framework/pas/1.3.3/.write-test` succeeded), but writes are erased on update and garbage-collected after 7 days for orphaned versions.

This is a **make-or-break fact for #125's "feedback routes into `${MARKETPLACE_ROOT}/plugins/<name>/.pas/...`" proposal**. Under the current plugin contract, that routes feedback into a per-version cache that the plugin manager will overwrite the next time the plugin bumps. The marketplace repo on disk (the place #125 actually wants the signal to live) is a Git clone that exists *elsewhere* — the consumer never sees it directly.

### 1.3 `${CLAUDE_PLUGIN_DATA}` — the persistent-write primitive

Same reference page:

> `${CLAUDE_PLUGIN_DATA}`: a persistent directory for plugin state that survives updates. Use this for installed dependencies such as `node_modules` or Python virtual environments, generated code, caches, and any other files that should persist across plugin versions.
>
> The `${CLAUDE_PLUGIN_DATA}` directory resolves to `~/.claude/plugins/data/{id}/`, where `{id}` is the plugin identifier...

Observed on this machine:

```
$ ls ~/.claude/plugins/data/
pas-pas-framework/
superpowers-claude-plugins-official/
superpowers-superpowers-marketplace/
```

So Claude Code already provides a per-user, per-plugin, update-persistent scratch directory. It's still **user-local**, not marketplace-repo-local. Good for caches and local state; *not* a path to the upstream repo.

### 1.4 Plugins cannot reference files outside their directory

Same page → "Path traversal limitations":

> "Installed plugins cannot reference files outside their directory. Paths that traverse outside the plugin root (such as `../shared-utils`) will not work after installation because those external files are not copied to the cache."

Symlinks are preserved but resolved at runtime against the target path — so anything a plugin needs at runtime either ships inside the plugin or is at a well-known absolute path.

### 1.5 How the user's upstream plugin actually lives on disk

A marketplace is a Git repo. The consumer running `/plugin install` never clones it into their project — Claude Code clones the *marketplace* into its own cache, then copies the named plugin subdirectory into `~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/`. From the "Plugin installation scopes" section:

> `user` → `~/.claude/settings.json`
> `project` → `.claude/settings.json`
> `local` → `.claude/settings.local.json`
> `managed` → managed settings (read-only, update only)

The scope files record *which plugins are enabled*, not *where the code is*. The code always lives in the user-local cache. There is no "`${MARKETPLACE_ROOT}` pointing at the marketplace's Git working copy" variable — that concept doesn't exist in the current plugin contract.

---

## 2. What this means for #125 — corrections to the framing

Quoting #125:

> Feedback needs to route into the marketplace plugin's path — e.g., `${MARKETPLACE_ROOT}/plugins/<name>/.pas/processes/<name>/agents/.../feedback/backlog/` — so the signal ends up with the skill it's about, not with the consumer that happened to generate it.

The `${MARKETPLACE_ROOT}` variable as written **does not exist** in Claude Code's plugin environment (verified against the "Environment variables" section — only `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` are documented). Even if we substituted `${CLAUDE_PLUGIN_ROOT}`, we'd be writing into a cache that evaporates on update.

There are three *actual* mechanisms that could realize the spirit of #125:

**Mechanism A — Stage-then-sync.** Feedback is written to `${CLAUDE_PLUGIN_DATA}/feedback-outbox/` (persistent, per-plugin, user-local). A separate maintenance op (invoked by the user, or by a hook) pushes this outbox into the marketplace's Git working copy — which the *owner of the marketplace* has checked out somewhere like `~/projects/.../PAS/plugins/pas/...`. For a PAS owner, that's trivially discoverable (`git config --get remote.origin.url` of `${CLAUDE_PLUGIN_ROOT}` / its parents or a configured `marketplace_path`). For a non-owner consumer, a PR or issue is the realistic push mechanism.

**Mechanism B — GitHub-issue-only routing.** Drop the idea of writing into the plugin path at all. Every framework-level signal becomes a GitHub issue on the marketplace repo. We already do this for `framework:pas` signals (see `plugins/pas/hooks/route-feedback.sh:65` — `route_framework_signal` files issues via `gh`). Extend the same pattern to *all* process/agent/skill targets when the process is marketplace-hosted: "this skill lives upstream → file an issue there." The consumer never holds the process tree at all; the issue tracker is the backlog.

**Mechanism C — Two-mode PAS.** Processes explicitly declare `ownership: marketplace | local`. Marketplace-owned processes route feedback via Mechanism A or B. Local processes (a consumer's own custom work) keep the current "write into `.pas/processes/.../feedback/backlog/`" model. This preserves the current behavior where a project can define its own process without owning a marketplace.

My preference (subject to round 2 debate): **B for cross-cutting skills like SEO / social-media / llm-wiki, A for the marketplace owner's own iteration on PAS itself, and C as the umbrella.** This matches how npm/cargo/homebrew actually work (see §3).

---

## 3. Package-manager precedents

**npm**: the installed package lives in `node_modules/<pkg>/`, is treated as read-only by convention (writing to it breaks npm's checksum/integrity), and *feedback is file-an-issue-on-the-repo*. There is no "write feedback into the package dir and the next `npm publish` picks it up." Ref: <https://docs.npmjs.com/about-package-readmes> — the repo is the source of truth, the install is a snapshot.

**Cargo**: `~/.cargo/registry/cache/` and `~/.cargo/registry/src/` are both treated as a cache. Cargo explicitly warns against editing files there because the next `cargo update` overwrites them. Ref: <https://doc.rust-lang.org/cargo/guide/cargo-home.html>.

**Homebrew**: `/opt/homebrew/Cellar/<formula>/<version>/` gets clobbered on `brew upgrade`. State that survives upgrades lives in `/opt/homebrew/var/`. Feedback flows via PRs against `homebrew-core` on GitHub.

**Common pattern across all three**: "package is source of truth" is preserved, but **they never ask consumers to write into the install directory.** They separate:

- Install dir (read-only, version-scoped, replaceable): what `${CLAUDE_PLUGIN_ROOT}` is today.
- Persistent user state (survives upgrades, scoped per package, still user-local): what `${CLAUDE_PLUGIN_DATA}` is today.
- Upstream contribution channel (issues, PRs, merge requests, formula edits): file-an-issue / open-a-PR.

**#125 is rediscovering this pattern.** PAS's GitHub-issue routing for `framework:pas` signals is already aligned with it. What #125 is asking for is: *make this the default*, not an opt-in.

---

## 4. Adoption implications

### 4.1 Current adoption (verified)

```
$ gh repo view ZoranSpirkovski/PAS --json stargazerCount,forkCount,watchers
{"stargazerCount":0,"forkCount":0,"watchers":{"totalCount":0}}
```

Repo created 2026-03-06. ~45 days old. Zero external adopters today. Memory record of this matches observation. Migration cost *for consumers* is effectively zero — there are no consumers besides the owner's other projects.

### 4.2 Signal to future adopters

This is the more interesting adoption question. Two forward-facing reads:

**"Easier to adopt."** A single `/plugin install pas@...` gives the user the full framework plus every published process. No per-project `.pas/processes/` tree to keep in sync. No "I forked SEO three months ago and now my version is stale" problem. One install, one upgrade, all skills move forward together. This is how npm gained adoption — you don't copy `lodash` into your repo, you depend on it.

**"Harder to adopt / lock-in."** Coupling the framework to a specific marketplace means consumers hitch themselves to the owner's release cadence and priorities. If PAS's marketplace disappears or diverges, every consumer loses their processes. Fork-to-customize becomes expensive — you have to stand up your own marketplace. Contrast with the current model: if a consumer likes SEO but wants to change a prompt, they edit their `.pas/processes/seo/` and ship on. That editability is part of why low-adoption early tools sometimes survive — they're trivially modifiable.

**My read**: the "one marketplace for everything" failure mode (lock-in) only bites at scale. At 0 adopters, the right bet is "make onboarding frictionless now, preserve an escape hatch." The escape hatch is exactly what Mechanism C above provides — `ownership: local` lets a consumer clone a marketplace process into their repo and own it, at which point PAS treats it as a fork. #125 explicitly calls this out as "out of scope" but I'd argue it needs to be *in scope* as a first-class supported mode, because it's the pressure-relief valve for the lock-in risk.

### 4.3 The "source of truth shift" signal

This is subtle. Today PAS's README and thin launcher all tell users "local copy is authoritative — run `/pas upgrade`." Flipping that changes what PAS *is* in the user's mental model:

- **Old model**: "PAS is a meta-skill for creating your own processes." Users expect ownership of the artifacts.
- **New model**: "PAS is a curated library of processes, plus a way to contribute upstream." Users expect dependency, not ownership.

Both are legitimate positions, but they attract different users. The second attracts people looking for a cross-project toolkit; the first attracts people building bespoke workflows. #125's framing is explicitly about the *first kind of user becoming the second* — the dacforge.com session where 8 projects had diverging SEO copies. That's a real pain point. The question is whether we optimize the default for *that* user (Zoran across his own projects) or for the hypothetical third-party adopter who might want something closer to the old model.

**Round 2 question for the group**: is PAS primarily a *framework I use across my own projects* (marketplace-authoritative makes total sense) or a *meta-tool others will use to build their own frameworks* (ownership-by-default makes more sense)? Both can be served, but the default matters.

---

## 5. Roadmap timing — is anything coming that we should coordinate with?

No Anthropic-published roadmap items exist that I could verify as directly relevant to #125. What *is* available today and worth noting:

**Hook events (v2.1+)**: the plugins-reference page lists `SessionStart`, `SessionEnd`, `PostCompact`, `FileChanged`, etc. Nothing called "plugin-updated" or "marketplace-sync" — so detecting "the plugin just updated, re-install `node_modules` or whatever" still requires the diff-based pattern the docs show:

```
diff -q "${CLAUDE_PLUGIN_ROOT}/package.json" "${CLAUDE_PLUGIN_DATA}/package.json" || ... reinstall
```

This is directly relevant: if we go with Mechanism A (stage-then-sync), we'd use exactly this pattern to detect when a PAS version bump implies the consumer's workspace config might need migration.

**`pluginConfigs[<plugin-id>].options` + `userConfig`**: the plugin manifest supports user-configurable values (see "User configuration" in plugins-reference). This is a viable channel for #125's "host-specific config" problem — e.g., `${user_config.project_config_root}` substituted into hook commands could tell PAS where to look for client-specific config. Currently PAS doesn't use this mechanism at all. Worth exploring in round 2 as a solution for *where does `seo/config/clients/dacforge/` live now* — answer: at `${user_config.project_config_root}/seo/clients/dacforge/` with the default being `.pas/config/seo/clients/`.

**`extraKnownMarketplaces` in `.claude/settings.json`**: team marketplaces (see discover-plugins page). If a consumer project ships `extraKnownMarketplaces` in its `.claude/settings.json`, Claude Code prompts on first trust. This is a clean way to say "this project expects PAS to be installed" without forking anything. Relevant for #125 because it means a project can declaratively require a marketplace without the user running `/plugin install` manually.

**Dependencies between plugins**: `dependencies: [{ "name": "secrets-vault", "version": "~2.1.0" }]` in plugin.json (verified in the schema). Means a process-plugin could declare it depends on PAS as a framework-plugin. Relevant if we split PAS into "framework plugin" vs "process plugins" later.

No urgent timing constraint. Nothing imminent that blocks the shift.

---

## 6. Risks specific to dogfooding this repo

Cycle 14's lesson (memory record): *modifying hooks while the cycle runs on those hooks makes live integration tests unreliable mid-cycle.* This cycle has a higher version of that risk.

This repo's `.pas/processes/pas-development/` — the entire development process you are running right now — is a consumer artifact under the *old* model. If #125 migrates it to marketplace-authoritative, **the process that ran this migration no longer exists in its old location on completion.** That is a category of "rug-pull" dogfooding hazard that warrants its own named cycle protocol (memory record #113 — "codify N/N+1 cycle protocol for hook-substrate changes" — applies verbatim here).

**Concrete risks:**

1. **Mid-cycle disappearance of `.pas/processes/pas-development/`.** If the migration is executed within this cycle, the orchestrator may try to read `process.md` after it's been moved. CLAUDE.md's Protected Files section (`.pas/processes/pas-development/`, `.pas/library/`, `.pas/workspace/`) explicitly calls this out as *never delete*. The migration plan has to reconcile: #125 wants these to *become* marketplace-owned, CLAUDE.md says never remove. Resolution: leave the local copy in place as the *last fork*, flip the plugin's default path via `skills`/`agents` manifest fields in plugin.json to point at the plugin-shipped copies *for new consumers*, and keep the local copies as a temporary bootstrap that maps to `ownership: local` in the new scheme.

2. **Hook-path scoping breaks.** `route-feedback.sh:26` resolves `process(name)` as `$CWD/$PAS_ROOT/processes/$value/feedback/backlog`. If processes move out of `$CWD`, this lookup fails silently. The hook would need a new resolution step: "if not found locally, treat as marketplace process and route to issue/outbox." That's a non-trivial hook change being planned in a cycle that already runs on this hook.

3. **`status.yaml` / workspace writes still need somewhere to land.** Workspace is unambiguously consumer-local (it captures the consumer's run-specific output — `.pas/workspace/pas-development/cycle-15/...`). #125 acknowledges this but leaves the convention underspecified. This needs a clear rule: *processes are plugin-owned; workspaces are consumer-owned; feedback target depends on the signal's target's ownership.*

4. **Upgrade skill conflicts.** `plugins/pas/processes/pas/agents/orchestrator/skills/upgrading/SKILL.md` currently tells users "no `.pas/library/` directory (processes reference `${CLAUDE_PLUGIN_ROOT}/library/` directly)" — that pattern is the one #125 generalizes. So upgrading is *already* partially marketplace-authoritative for library content. The shift for processes is the next logical step and is internally consistent.

---

## 7. Open questions for round 2

1. **Where does feedback actually land?** `${CLAUDE_PLUGIN_DATA}` outbox + GitHub issues (Mechanism B), or file-an-issue only? Framework-architect and feedback-specialist probably have strong opinions here.

2. **Can processes carry their own marketplace pointer?** If a process declares `source_marketplace: ZoranSpirkovski/PAS`, the feedback router knows where to file issues. If it declares `ownership: local`, keep current behavior. Proposed answer: yes, introduce this field.

3. **How do we handle the `.pas/processes/pas-development/` rug-pull during this cycle?** See §6(1). Plan-design-agent should own this.

4. **Does `userConfig` in plugin.json solve the "where does client config go" question?** §5 suggests yes. Framework-architect: does that fit the existing PAS conventions or conflict?

5. **Is `ownership: local` a first-class mode or an edge case?** I argue first-class (§4.2). Others may disagree.

6. **Does this imply splitting PAS into framework-plugin + process-plugins?** Feature-level: yes, eventually. Cycle-level: not yet — do the routing shift first, split later when we have >1 marketplace-shipped process.

---

## 8. Ranked opportunities (from ecosystem-scan output format)

**Opportunity 1 (HIGH)**: Adopt `${CLAUDE_PLUGIN_DATA}` as the persistent-state primitive. It already exists, is update-safe, and is per-plugin. Use it for feedback-outbox and any cross-session state the plugin needs to persist without touching the consumer project. Specific: define `${CLAUDE_PLUGIN_DATA}/feedback-outbox/{date}-{signal-id}.md` as the staging area.

**Opportunity 2 (HIGH)**: Extend the existing GitHub-issue routing (currently `Route: github-issue` only for `framework:pas`) to all marketplace-owned targets. Mechanism: when target resolves to a process/agent/skill that's shipped from the plugin path (not the consumer path), route to issue. Minimal new code — reuse `route_framework_signal`.

**Opportunity 3 (MEDIUM)**: Add `userConfig` to plugin.json for host-specific paths (client config root, workspace override). Shifts "host config convention" from implicit to declared.

**Opportunity 4 (MEDIUM)**: Add `ownership: local | marketplace` to process.md frontmatter. Makes the authoritativeness explicit per-process. Backwards compatible: default = `local` (today's behavior).

**Opportunity 5 (LOW)**: Document the "marketplace is source of truth" model in a short `docs/plugin-model.md` so future adopters aren't surprised when they install PAS and don't see `.pas/processes/` in their repo.

---

## 9. Risks (from ecosystem-scan output format)

**Risk 1**: `${CLAUDE_PLUGIN_ROOT}` semantics could change. Low probability — it's a documented, public contract. But any PAS design that depends on `${CLAUDE_PLUGIN_ROOT}` being writable is building on sand *today*.

**Risk 2**: Team marketplaces via `extraKnownMarketplaces` require repository trust. If a consumer hasn't trusted a repo that declares PAS as a dependency, the install prompt doesn't fire. Adoption friction we should document.

**Risk 3**: Plugin cache garbage-collection (7-day orphan purge) could surprise users who check out an old branch of a consumer project and expect an older PAS version to still be available. Not blocking, but document.

**Risk 4**: Version skew between marketplace-shipped processes and consumer workspaces. If a consumer's workspace was written under PAS 1.3.3 and they upgrade to 2.0.0 mid-session, the schema may not match. Needs a workspace-format-version field and upgrade-in-place logic. Out of scope for this cycle but tracks as a followup.

---

## Sources

- <https://code.claude.com/docs/en/plugins> — plugin creation guide
- <https://code.claude.com/docs/en/plugins-reference> — full technical reference (source for all `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}` / caching quotes)
- <https://code.claude.com/docs/en/discover-plugins> — install flow, scope system, `extraKnownMarketplaces`
- `gh repo view ZoranSpirkovski/PAS --json stargazerCount,forkCount,watchers` → `{stargazerCount:0, forkCount:0, watchers:0}` (verified 2026-04-20)
- `ls ~/.claude/plugins/cache/pas-framework/pas/1.3.3/` — observed plugin install path
- `plugins/pas/hooks/route-feedback.sh:65` — existing `route_framework_signal` pattern we should generalize
- `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process:304` — current thin-launcher template that needs its wording flipped
