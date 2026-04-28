# DX Specialist — Cycle 14 Discovery Perspective

**Lens:** user-experience impact of the M3 hook bugs and adjacent UX issues. The unifying theme: PAS hooks fail in ways the user cannot diagnose without reading shell scripts. Every M3 P0 is a DX failure, not just a bug.

---

## 1. M3 DX Impact Rankings (severity × frequency)

Severity = how bad the user's experience is when it hits. Frequency = how likely a typical session triggers it.

| # | Issue | Severity | Frequency | DX score | What the user sees | What they expect | Discoverability | Workaround |
|---|---|---|---|---|---|---|---|---|
| 1 | **#68** SessionStart hijacks subagents | CRIT | EVERY subagent spawn while PAS active | **9.8** | Subagent returns "Self-evaluation written" instead of the requested research | The task output (web fetch result, code findings, review) | None — output looks deliberate, not broken | Defensive prompt preamble per spawn (issue calls this out as "shouldn't be needed") |
| 2 | **#67** SubagentStop fires on non-PAS subagents, lands feedback in unrelated workspace | CRIT | Every non-PAS subagent in any PAS-enabled project | **9.5** | An attorney-process workspace gets random Explore-agent self-evals dropped into its `feedback/` dir | Subagent stops cleanly; nothing pollutes unrelated workspaces | Only if user inspects `feedback/` and notices files that don't belong | None — must disable PAS feedback globally |
| 3 | **#38** system-reminder derails Explore subagents | CRIT | Every Agent-tool spawn during PAS session | **9.5** | Same symptom class as #68; agent writes feedback file instead of findings | Findings | Same as #68 — silent miscarriage | Same as #68 |
| 4 | **#71** SubagentStop elides substantive subagent text | HIGH | Every subagent that DOES return a useful response | **9.0** | Parent receives `"Self-evaluation written. No issues detected."` instead of the actual review/report | The full review/exploration text | Issue reporter saw it 5× in one session before recognising the pattern | Prompt subagent to "return full report inline" + re-prompt via SendMessage if elided. Adds 1 round-trip per dispatch |
| 5 | **#64** `CLAUDE_PLUGIN_ROOT: unbound variable` crash | HIGH | Every session for users on the cached buggy 1.3.2 build | **8.5** | "SessionStart:startup hook error" + missing "PAS Framework Active" banner | Banner with workspace context | Error visible but cryptic — user has no clue it's a cache-version-collision issue | None on user side; needs version bump to force cache refresh |
| 6 | **#54** SessionStart crashes on missing `instance:` field | HIGH | Any older or hand-crafted workspace | **7.5** | "SessionStart:startup hook error" on every session start | Graceful display | Error message names the line but not the cause | Hand-edit status.yaml to add `instance:` |
| 7 | **#55** `check-self-eval.sh` line 39 integer comparison | HIGH | Every shutdown where agent transcript has zero signals | **8.0** | `[: 0\n0: integer expression expected` followed by SELF-EVALUATION MISSING blocked shutdown | Clean exit OR a clear "please write a self-eval" prompt | Error reveals the bug but blames the user | Write a self-eval anyway (wastes a round-trip) |
| 8 | **#58** silent degradation on malformed status.yaml | MEDIUM | Any malformed workspace post-#54 fix | **6.5** | `Active workspace: / (status: )` — user can't tell what state they're in | Workspace name + state OR a clear warning about the malformed file | Visible but baffling | Manually inspect status.yaml |

**Headline:** five of eight M3 bugs (#38, #67, #68, #71, #64) score above 8.5 on a 0–10 DX scale. **None of them produce a clear, actionable error message.** Three actively masquerade as success ("Self-evaluation written") which is the worst possible failure mode — the user doesn't know to look for a bug.

---

## 2. Concrete Error-Message Rewrites for Silent-Failure Cases

Current state in #54/#55/#64: scripts crash with `set -euo pipefail` traceback. In #58: scripts emit garbage output. None of these tell a user what to do.

### #54 / #58 — `pas-session-start.sh` malformed status.yaml

**Replace:** `Active workspace: / (status: )`

**With:**
```
PAS workspace detected at: .pas/workspace/{derived-from-dirname}/
  Status file: .pas/workspace/{path}/status.yaml
  Missing required fields: instance, status
  See: library/orchestration/lifecycle.md (status.yaml schema)
  Continuing with derived values — fix status.yaml to silence this warning.
```

Rationale: tells the user *where* the file is, *what's missing*, *where the spec lives*, and *that the session continues*. No user has to read shell to understand it.

### #55 — `check-self-eval.sh` zero-signal path

**Replace:** the current crash + `SELF-EVALUATION MISSING` block when the underlying bug is just a bad integer comparison.

**With (when feedback truly is missing):**
```
PAS feedback hook: agent {agent_id} is shutting down without writing self-evaluation.

This is required when feedback is enabled in .pas/config.yaml.

To resolve, write your evaluation to:
  .pas/workspace/{process}/{slug}/feedback/{agent_name}-{session_id}.md

If nothing went wrong, the file may contain just: "No issues detected."

Format reference: .pas/library/self-evaluation/SKILL.md
To disable feedback for this project: edit .pas/config.yaml → feedback: disabled
```

Rationale: today's message names the file path, but doesn't tell the user *how to opt out* or *how to write the minimal valid file*. Add both — the opt-out is the missing escape hatch.

### #64 — `CLAUDE_PLUGIN_ROOT: unbound variable`

**Replace:** raw bash traceback.

**With (after the defensive guard the issue proposes):**
```
PAS hook: CLAUDE_PLUGIN_ROOT was not set by the harness. Falling back to script location: {derived path}.
If hooks misbehave, your plugin cache may be stale. Try:
  rm -rf ~/.claude/plugins/cache/pas-framework
  (Claude Code will re-download on next session.)
```

Rationale: the issue itself notes that two builds of `1.3.2` exist in the wild. Tell the user the recovery command instead of leaving them to guess. **Pair this with the version bump to 1.3.3 the issue proposes** — the message is the diagnostic, the bump forces the actual cache refresh.

---

## 3. DX Audit Recommendation: **Defer to a dedicated cycle (M6 or M6.5)**

This is the 3rd cycle since the last DX audit, so cadence is due — but **fold-in is wrong for cycle 14**, for three reasons:

1. **Audit findings would land on top of unfixed hook bugs.** Any onboarding test in cycle 14 would surface the same crashes M3 is fixing — duplicated work.
2. **Cycle 14 already has a heavy execution scope** (8 hook fixes + worktree RFC #70). Adding an audit dilutes focus.
3. **A real audit needs post-fix state to evaluate.** Test the new error messages from §2, the new hook scoping, the new generators after M3+M4+M5 land — *that's* the audit worth doing.

**Counter-proposal:** schedule the DX audit as the **opening phase of M6 (Feedback UX Polish)** — the milestone is already UX-shaped, and by then M3 (hooks) + M4 (lifecycle) + M5 (generators) have shipped, giving the audit fresh state to evaluate.

**Sketch checklist for that future audit (lock in now so it doesn't get forgotten):**
- Frontmatter clarity: every `SKILL.md` in `plugins/pas/` has a `description` that a first-time user understands without reading the body
- Hook error messages: every `set -euo pipefail` failure path has a user-facing message (use the §2 templates as baseline)
- `lifecycle.md` prose accuracy: matches what the hooks actually enforce post-M3
- Generator scaffolds: `creating-processes` / `pas-create-skill` / `pas-create-process` produce artifacts that pass their own validation hooks on first run
- Onboarding path: README → first `/pas-development` run → first feedback signal applied — measure friction at each step
- Naming audit: `framework:pas` vs `process:` vs `agent:` vs `skill:` target syntax — is it intuitive without reading docs?

---

## 4. Cross-Milestone DX Hoist Proposals

### #30 / #40 (`AskUserQuestion` for option prompts) → **HOIST to M3**

Rationale:
- These are 2-line edits to `applying-feedback/SKILL.md` (literally: "Use AskUserQuestion to present these options").
- #40 explicitly notes the agent **already failed twice** despite the signal sitting in the backlog ("the instruction needs to be in the skill itself, not just the backlog"). Every cycle we defer is another cycle the agent reproduces the failure.
- M3 PRs already touch hook + library files; piggybacking these into the same PR costs nothing and ships UX wins now.

### #41 (clarify direct-apply vs GitHub-issue routing) → **HOIST to M3**

Rationale:
- Issue describes the agent filing a bogus issue on the user's *product repo* during a PAS feedback application. That's not a polish bug — it's a **trust-breaking accident** affecting a downstream consumer's actual GitHub project.
- Same skill file as #30/#40, same trivial edit (add a routing-rule callout). Bundle it.

### #34 (GitHub issue template for `framework:pas` routing) → **STAY in M6**

Rationale:
- Genuinely larger scope (template design + decision between `library/github-issue-routing/SKILL.md` vs `.github/ISSUE_TEMPLATE/`).
- Doesn't break sessions or derail subagents — it makes filed issues better.
- Belongs with the broader feedback UX rework in M6 where the template can be designed alongside the AskUserQuestion + routing-clarity changes.

### #50 (PAS feedback must stay in workspace, not auto-memory) → **STAY in M6** but flag for early review

Rationale: not in the cross-milestone list above but worth noting. Auto-memory contamination is a long-tail trust issue, not session-breaking — M6 is the right home, but the team should review before M4 lands so any lifecycle-skill design doesn't accidentally re-introduce memory writes.

---

## Summary

- **M3 is a DX cycle disguised as a bug-fix cycle.** Every P0 hook bug is a UX failure where the user can't diagnose what's wrong. Treat the *error-message rewrites* (§2) as first-class deliverables, not afterthoughts.
- **Five M3 bugs score 8.5+ on the DX impact scale.** Three masquerade as success — the worst failure mode.
- **Hoist #30 / #40 / #41 into M3.** Two-line skill edits with high impact and zero cost; #41 fixes a trust-breaking accident on user repos.
- **Defer the full DX audit to M6.** Audit needs post-fix state. Lock in the checklist now (frontmatter, error messages, lifecycle prose, generator scaffolds, onboarding path, naming) so M6 inherits a concrete plan.
