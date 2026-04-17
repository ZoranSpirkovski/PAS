# Ecosystem Analyst — Cycle 14 Discovery (Round 1)

Source-of-truth for platform claims: `https://code.claude.com/docs/en/hooks` and `https://code.claude.com/docs/en/plugins` (fetched 2026-04-16). Local repo evidence: `plugins/pas/hooks/check-self-eval.sh`, `plugins/pas/hooks/hooks.json`, `plugins/pas/hooks/lib/guards.sh`, `plugins/pas/hooks/verify-completion-gate.sh`.

## 1. Capability matrix — CC platform feature → M3 issue → fix complexity

| Issue | Symptom | Right fix from CC platform | Complexity |
|---|---|---|---|
| #38, #67, #68 | `check-self-eval.sh` and SessionStart fire on **every** subagent (including generic Explore/Plan), making them write PAS feedback instead of returning findings | Use `agent_type` in the SubagentStop payload (confirmed field, value = agent name like `"Explore"`, `"Plan"`, `"Bash"`, or custom). Scope `check-self-eval.sh` to PAS-spawned agents only by maintaining an allowlist read from the active workspace's `status.yaml` `agent:` entries. `agent_id` further disambiguates which specific PAS agent it was. | Low — pure JSON parse + allowlist check |
| #71 | SubagentStop hook elides subagent's text response | Same scoping fix as #38/#67/#68 — once non-PAS subagents are skipped, the hook never fires for them and never blocks. For PAS agents, use `last_assistant_message` (confirmed payload field) to verify a self-eval marker was emitted before exit 2 | Low |
| #54 | SessionStart crashes on missing `instance` field | Defensive `jq -r '.instance // empty'` and `${VAR:-default}` everywhere. Independent of platform features. | Trivial |
| #55 | `grep -c` returns multi-line, breaks `[ "$X" -gt 0 ]` | `| head -1` or `| wc -l` normalization | Trivial |
| #56, #57 | Umbrella reliability — both resolve once #54/#55/#64 land | n/a — closure tracking | n/a |
| #58 | Silent degradation on malformed `status.yaml` | Print structured warning to stderr, continue with safe defaults | Trivial |
| #59 | PAS framework signals filed on product repos | The hook reads `cwd` (confirmed payload field) but routes by current working dir. Add a guard that compares `cwd` against the PAS repo URL recorded in `pas-config.yaml`; route GitHub-issue signals only if cwd is the PAS plugin repo. | Low |
| #64 | `pas-session-start.sh` crashes with `CLAUDE_PLUGIN_ROOT: unbound variable` | `set -u` collision. Use `${CLAUDE_PLUGIN_ROOT:-}` everywhere, or relax `set -u` in scripts. **Confirmed in docs:** `${CLAUDE_PLUGIN_ROOT}` is plugin-scope only — it's available in plugin hooks but the variable can be empty in standalone-config invocations. Always default-guard. | Trivial |
| #52 | `verify-task-completion` checks wrong workspace under multi-instance | Read `cwd` from payload (always present) and resolve workspace under `cwd/.pas/workspace/`, not via `find` from arbitrary roots. For multi-instance disambiguation, prefer the workspace whose `status.yaml current_session` matches the payload's `session_id`. | Medium |
| #70 (worktree) | Silent disable, cwd-relative paths, deadlocked completion gate | See section 3 below — `git rev-parse --git-common-dir` is the right resolver | Medium |

**One-liner for the agent_type approach (sketch):**
```bash
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
PAS_AGENTS=$(grep '^\s*agent:' "$ACTIVE_STATUS" | awk '{print $2}' | sort -u)
echo "$PAS_AGENTS" | grep -qx "$AGENT_TYPE" || exit 0   # not a PAS agent, skip silently
```

## 2. Agent-based hooks — adopt or stay with bash?

`"type": "agent"` hooks are confirmed in docs: a hook handler can spawn a subagent with a `prompt` and `timeout`, receives the full event JSON via `$ARGUMENTS`, and can use Read/Grep/Glob/Bash to verify conditions before returning a decision.

**Recommendation: stay with bash for M3.** Reasons:

1. **Latency.** `verify-completion-gate.sh` runs on every Stop event. An agent hook spins up a subagent (model latency + token cost) for what is currently a sub-200ms bash check. Wrong cost profile.
2. **Reliability.** Agent hooks depend on model availability and are non-deterministic — a wrong call here would leave PAS sessions either unable to stop or stopping when they shouldn't. The current bugs are deterministic bugs in deterministic code, fixable in deterministic code.
3. **Debuggability.** A failing bash hook produces stderr you can `bash -x`. A failing agent hook produces a transcript that may or may not exist.
4. **Where they DO fit (defer to M7 / RFC).** A `framework:pas` signal classifier — deciding whether a feedback signal is novel vs duplicate before filing as GitHub issue — is a good agent-hook fit. That's #34's territory, not M3.

## 3. `PAS_PROJECT_ROOT` resolution algorithm (#70 finding 1)

Goal: every hook script needs an unambiguous "where is this PAS project rooted?" that survives worktrees, subdirectories, and the `${CLAUDE_PLUGIN_ROOT}` red herring.

**Confirmed platform variables:**
- `$CLAUDE_PROJECT_DIR` — project root, available in **all** hook types (per docs table)
- `${CLAUDE_PLUGIN_ROOT}` — plugin install dir, **plugin hooks only**, changes on update
- Hook payload always carries `cwd`

**Proposed algorithm (in `lib/guards.sh`):**

```bash
resolve_pas_project_root() {
  # 1. Trust the payload's cwd first — it's the active session's cwd
  local candidate="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

  # 2. Walk up to find .pas/config.yaml (handles subdirectory invocation)
  local dir="$candidate"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/.pas/config.yaml" ] && { echo "$dir"; return 0; }
    dir=$(dirname "$dir")
  done

  # 3. Worktree fallback — git's common dir is shared across worktrees,
  #    but the worktree's .git points to a unique location. Use rev-parse
  #    to find the worktree root, then check its parent for .pas/.
  if command -v git >/dev/null 2>&1; then
    local worktree_root
    worktree_root=$(cd "$candidate" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || return 1
    [ -f "$worktree_root/.pas/config.yaml" ] && { echo "$worktree_root"; return 0; }
  fi

  return 1
}
```

**Why `git rev-parse --show-toplevel`, not `--git-common-dir`:**
- `--git-common-dir` returns the **shared** `.git` directory (same across all worktrees) — it does NOT point at the worktree's working tree, so it can't host `.pas/`.
- `--show-toplevel` returns the worktree's working-tree root, which is where `.pas/` lives per worktree (each worktree gets its own `.pas/workspace/` for session isolation — that's the intended contract per #70 finding 3).
- I verified locally: `git rev-parse --show-toplevel` from this cwd returns `/home/zoran/projects/github.com/ZoranSpirkovski/PAS`. From `/tmp` it fatals out — handled by the `2>/dev/null || return 1`.

**Where to set `PAS_PROJECT_ROOT`:** export it once in `guard_parse_input` after `resolve_pas_project_root`, then every downstream guard reads `$PAS_PROJECT_ROOT` instead of `$CWD`. This eliminates the cwd-vs-project-root confusion #70 documents.

## 4. Skill portability for #69 — what the ecosystem offers

Per the plugins doc, two distribution paths exist:

1. **Standalone `.claude/` directory** — short skill names like `/hello`, project-only, can't be shared without manual copy
2. **Plugins** — namespaced names like `/plugin-name:hello`, distributed via plugin marketplaces (the `--plugin-dir` flag also supports loading direct from a path during dev)

**Implication for #69:** A PAS-authored skill that's "portable" should be packaged as a standalone plugin with its own `.claude-plugin/plugin.json`. PAS could ship a `pas-create-portable-skill` variant that scaffolds the plugin manifest alongside the SKILL.md, ready to be `cp`'d into a target repo or pushed to a git URL and installed via `/plugin install`. The plugin marketplace mechanic (a `marketplace.json` catalog) is exactly the pattern PAS itself already uses (`.claude-plugin/marketplace.json`) — so PAS knows the shape.

**Out-of-scope for M3** but the platform clearly supports the use case; M7 should reference this rather than invent a new portability format.

## Risks

- `agent_type` field availability: confirmed in current docs but not version-tagged. Add a fallback to "unknown" handling so old CC versions don't break.
- `${CLAUDE_PLUGIN_ROOT}` empty in standalone-config invocations: docs are explicit it's "plugin hooks" scope. Default-guard universally.
- Worktrees with `.pas/` only at the main worktree (not per-worktree) is a valid alternate design — confirm with team-lead before assuming per-worktree `.pas/` is the intended contract.
