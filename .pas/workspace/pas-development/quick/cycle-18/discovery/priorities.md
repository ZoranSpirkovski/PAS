# Cycle 18 — Discovery: Quiet Stop Hook + Version Diagnostic

## The pain

User invokes a long-running maintainer-style skill (`/process-maintainer`, `/v2-agency-delivery`, etc.) and tries to *talk* about a process. Claude does ORIENT work, yields, Stop hook fires, "Ran 3 stop hooks" header + sub-list + per-hook stderr appear in the transcript. Even when the gate correctly skips (cycle-16 binding mismatch, cycle-17 no-advanced-phases), the skip *itself* prints to stderr:

```
[PAS] Stop hook: resolved workspace .../status.yaml has no advanced phases —
skipping completion gate (orchestrator-side binding without phase work; ...)
```

Combined with `Ran 3 stop hooks` and the hook-script listing, every conversational yield shows ~5 lines of PAS bookkeeping noise. The user's words: "its just derailing the conversations."

The cycle-17 fix made the gate *not block*. It did not make the gate *not announce itself*. That announcement is the actual UX problem.

## What Claude Code emits vs. what PAS emits

Claude Code prints `Ran N stop hooks` and the hook-command listing whenever any Stop hook runs, regardless of exit code. **We cannot suppress that.** What we control is whether each hook adds stderr output below.

When a hook exits 0 with no stderr, Claude Code typically renders the listing collapsed and minimal. When a hook prints stderr or exits non-zero, Claude Code expands the entry. So **silent exit 0** = visually quiet conversation.

## Audit of every Stop-fired hook's stderr

| Hook | Line | Output | Classification |
|---|---|---|---|
| `verify-completion-gate.sh` | 44 | Cycle-16 binding-mismatch skip msg | **SKIP — make silent** |
| `verify-completion-gate.sh` | 61 | Cycle-17 no-advanced-phases skip msg | **SKIP — make silent** |
| `verify-completion-gate.sh` | 163 | "COMPLETION GATE FAILED" demand block | DEMAND — must stay |
| `route-feedback.sh` | — | (no stderr writes; only writes to outbox files / signal targets) | OK |
| `check-self-eval.sh` | 71 | "substantive response detected, gate bypassed" INFO | **SKIP — make silent** |
| `check-self-eval.sh` | 77 | "self-evaluation missing" demand block | DEMAND — must stay |
| `verify-task-completion.sh` | 43, 58, 71, 117 | "Cannot complete" demand blocks | DEMAND — must stay |

Three lines need to go silent. Every "demand" / "block" message stays — those are the user-visible signals that something needs doing.

## Version diagnostic — minimal scope

The cycle-17 → cycle-18 transition surfaced a real diagnostic gap: when the user reports "the gate fired in my consumer", I had no way to confirm *which* PAS version's hook actually ran. `${CLAUDE_PLUGIN_ROOT}` is only set in hook subprocess context, so users can't inspect it from a shell.

**Cheap fix that doesn't add output noise:** every demand-block message includes a one-line version footer. So when the gate fails and prints its block, the bottom of the message says:

```
(PAS plugin 1.4.3, install: /home/zoran/.claude/plugins/cache/pas-framework/pas/1.4.3)
```

The user (or another Claude session) immediately knows which install + version emitted the block. No clutter on quiet paths, full attribution on noisy paths. Good signal-to-noise.

Skip the `/tmp/pas-hook-<pid>.log` idea — clutter for low return. The version footer in demand blocks is sufficient.

## Out of scope (deferred)

- **Phase-boundary feedback redesign.** Considered, rejected for cycle 18 — loses session-level observations, doesn't fix the actual UX pain (which is hook *verbosity*, not feedback *timing*). May revisit if the broader "what is feedback for" question gets a real review.
- **SessionEnd hook adoption.** Considered, rejected — fires after Claude has no remaining turns, so it can't drive reflective writing. Not the right hook for this purpose.
- **Investigating why 1.4.0 hooks may still fire on a 1.4.2 user-scoped install.** Diagnostic data was inconclusive; the version-footer fix in cycle-18 makes the next inquiry trivial. Defer the investigation until we have a fresh post-1.4.3 transcript.
- **Consumer-side `process-maintainer` session-tracking convention.** The consumer's skill writes session entries on every yield. PAS plugin can't fix consumer skill behavior. The fix here makes PAS *itself* quiet; if the consumer skill still adds bookkeeping, that's the consumer's call.

## Files in scope

- `plugins/pas/hooks/verify-completion-gate.sh` — silent skip on lines 44, 61; version footer on demand block at 163
- `plugins/pas/hooks/check-self-eval.sh` — silent skip on line 71; version footer on demand block at 77
- `plugins/pas/hooks/verify-task-completion.sh` — version footer on each demand block (43, 58, 71, 117)
- `plugins/pas/hooks/lib/guards.sh` — small helper `pas_version_footer()` that resolves the version + install path once
- `plugins/pas/hooks/tests/test-hooks.sh` — assert silent skip paths produce no stderr; assert demand blocks include version footer
- `plugins/pas/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — bump to 1.4.3
- `plugins/pas/hooks/changelog.md` — entry

## Out-of-scope items filed at shutdown

- Possibly a framework signal: "version footer should be machine-parseable" if the test framework cycle wants it.
