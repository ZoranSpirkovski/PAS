#!/usr/bin/env bash
# Shared guard functions for PAS hooks.
# Eliminates duplicated jq/config/feedback checks across hook scripts.

# All PAS project-level artifacts live under this directory.
PAS_ROOT=".pas"

# Resolve CLAUDE_PLUGIN_ROOT via validated strategies, fail loudly on miss.
# Strategies, in order:
#   1. Env var set by harness — accepted only if path contains .claude-plugin/plugin.json
#      AND a hooks/ directory (rejects arbitrary directories that happen to be exported).
#   2. Walk up from this script's own BASH_SOURCE looking for the same markers.
#   3. Scan ~/.claude/plugins/cache/*/pas/*/ for an install matching the markers.
#   4. Fail — emit actionable diagnosis to stderr, return 2.
#
# Every hook sources this file and calls `resolve_claude_plugin_root || exit 1`
# at startup, except SessionStart which uses `|| exit 0` to avoid panicking the host.
resolve_claude_plugin_root() {
  local candidate

  # Strategy 1: harness-exported env var, validated
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] \
     && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ] \
     && [ -d "${CLAUDE_PLUGIN_ROOT}/hooks" ]; then
    export CLAUDE_PLUGIN_ROOT
    return 0
  fi

  # Strategy 2: walk up from this file (lib/guards.sh) looking for plugin markers
  candidate="$(cd "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd)" || candidate=""
  local depth=0
  while [ -n "$candidate" ] && [ "$candidate" != "/" ] && [ "$depth" -lt 6 ]; do
    if [ -f "$candidate/.claude-plugin/plugin.json" ] && [ -d "$candidate/hooks" ]; then
      CLAUDE_PLUGIN_ROOT="$candidate"
      export CLAUDE_PLUGIN_ROOT
      return 0
    fi
    candidate="$(dirname "$candidate")"
    depth=$((depth + 1))
  done

  # Strategy 3: scan install cache for the pas plugin
  if [ -d "${HOME:-/nonexistent}/.claude/plugins/cache" ]; then
    local cached
    for cached in "$HOME/.claude/plugins/cache"/*/pas/*/; do
      if [ -f "$cached/.claude-plugin/plugin.json" ] && [ -d "$cached/hooks" ]; then
        CLAUDE_PLUGIN_ROOT="$(cd "$cached" && pwd)"
        export CLAUDE_PLUGIN_ROOT
        return 0
      fi
    done
  fi

  # Strategy 4: fail loudly
  echo "PAS hook: unable to resolve CLAUDE_PLUGIN_ROOT (env unset or invalid; walk-up from ${BASH_SOURCE[0]} found no plugin markers; no install cache match)" >&2
  return 2
}

# Resolve the PAS project root by walking up from a candidate cwd until
# .pas/config.yaml is found, then falling back to git's worktree root.
# Echoes the resolved root on stdout; returns non-zero if nothing matches.
resolve_pas_project_root() {
  local candidate="${1:-${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}}"

  # Walk up from candidate
  local dir="$candidate"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/$PAS_ROOT/config.yaml" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  # Worktree fallback: when running inside a worktree, .pas/ may live at the
  # main worktree root. --show-toplevel returns the worktree's working tree,
  # not the shared .git dir (which would be wrong for hosting .pas/).
  if command -v git >/dev/null 2>&1; then
    local worktree_root
    worktree_root=$(cd "$candidate" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || return 1
    if [ -n "$worktree_root" ] && [ -f "$worktree_root/$PAS_ROOT/config.yaml" ]; then
      echo "$worktree_root"
      return 0
    fi
  fi

  return 1
}

# Crash-resistant `grep | head | awk` field extractor for status.yaml.
# Returns empty string on missing field instead of failing under set -e/pipefail.
safe_grep_field() {
  local file="$1"
  local key="$2"
  grep "^${key}:" "$file" 2>/dev/null | head -1 | awk '{print $2}' || true
}

# Parse JSON input from stdin. Sets CWD and exposes raw INPUT.
# Returns 1 if jq is missing or JSON is invalid.
guard_parse_input() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "PAS hook: jq not found, skipping" >&2
    return 1
  fi

  INPUT=$(cat)

  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  if [ -z "$CWD" ]; then
    return 1
  fi
}

# Migrate old-style root-level PAS artifacts into .pas/ directory.
# Idempotent: skips each item if target already exists.
migrate_to_pas_dir() {
  local pas_dir="$CWD/$PAS_ROOT"
  mkdir -p "$pas_dir"

  # Move config (rename)
  if [ -f "$CWD/pas-config.yaml" ] && [ ! -f "$pas_dir/config.yaml" ]; then
    mv "$CWD/pas-config.yaml" "$pas_dir/config.yaml"
  fi

  # Move directories
  for dir in workspace library processes feedback; do
    if [ -d "$CWD/$dir" ] && [ ! -d "$pas_dir/$dir" ]; then
      mv "$CWD/$dir" "$pas_dir/$dir"
    fi
  done
}

# Check that this is a PAS project (.pas/config.yaml exists).
# Auto-migrates old-style layout if detected. Also handles worktrees and
# subdirectory invocations by walking up and falling back to git-worktree-root.
# Sets PAS_PROJECT_ROOT to the resolved project root (may differ from CWD).
# Returns 1 if not a PAS project.
guard_pas_project() {
  # Fast path: $CWD itself is a PAS root
  PAS_CONFIG="$CWD/$PAS_ROOT/config.yaml"
  if [ -f "$PAS_CONFIG" ]; then
    PAS_PROJECT_ROOT="$CWD"
    export PAS_PROJECT_ROOT
    return 0
  fi

  # Backward compatibility: migrate old-style root layout
  if [ -f "$CWD/pas-config.yaml" ]; then
    migrate_to_pas_dir
    PAS_CONFIG="$CWD/$PAS_ROOT/config.yaml"
    if [ -f "$PAS_CONFIG" ]; then
      PAS_PROJECT_ROOT="$CWD"
      export PAS_PROJECT_ROOT
      return 0
    fi
  fi

  # Worktree / subdirectory fallback: walk up and try git-worktree resolver.
  local resolved
  resolved=$(resolve_pas_project_root "$CWD") || return 1
  if [ -n "$resolved" ] && [ -f "$resolved/$PAS_ROOT/config.yaml" ]; then
    PAS_PROJECT_ROOT="$resolved"
    PAS_CONFIG="$resolved/$PAS_ROOT/config.yaml"
    export PAS_PROJECT_ROOT
    return 0
  fi

  return 1
}

# Check that feedback is enabled in config.yaml.
# Returns 1 if feedback is not enabled.
guard_feedback_enabled() {
  guard_pas_project || return 1

  FEEDBACK_STATUS=$(grep -o 'feedback:[[:space:]]*\w*' "$PAS_CONFIG" | head -1 | awk '{print $NF}')
  if [ "$FEEDBACK_STATUS" != "enabled" ]; then
    return 1
  fi
}

# Check that the given agent type is one declared in the active process's
# status.yaml (i.e. a PAS-spawned agent, not a generic Explore/Plan/etc).
# Args:
#   $1 — agent_type from the SubagentStop payload (jq '.agent_type // empty')
#   $2 — script_dir (passed through to guard_active_workspace)
# Returns 0 when the agent is in the active PAS process's allowlist,
# non-zero otherwise (caller should `exit 0` to silently skip).
#
# SAFE-FAIL: empty/unset agent_type → return 0 (treat as PAS agent). This
# preserves existing over-blocking behavior on CC versions that don't
# populate the field, instead of silently weakening the gate.
guard_agent_in_active_process() {
  local agent_type="$1"
  local script_dir="$2"

  # Empty/unknown → safe-fail to "treat as PAS agent" (over-block direction)
  if [ -z "$agent_type" ] || [ "$agent_type" = "unknown" ] || [ "$agent_type" = "null" ]; then
    return 0
  fi

  # If we can't resolve a workspace, can't check the allowlist — safe-fail
  # to over-block; caller's guard_active_workspace will exit 0 naturally
  # if there's truly no workspace.
  if ! guard_active_workspace "$script_dir" 2>/dev/null; then
    return 0
  fi

  local pas_agents
  # status.yaml shape: `agent: name` (scalar) OR `agent: [a, b, c]` (list).
  # Strip brackets/commas; emit every name on its own line.
  pas_agents=$(grep '^[[:space:]]*agent:' "$ACTIVE_STATUS" 2>/dev/null \
    | sed 's/^[[:space:]]*agent:[[:space:]]*//' \
    | tr -d '[]' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -v '^$' \
    | sort -u)

  # Empty allowlist → safe-fail (something's wrong with status.yaml)
  if [ -z "$pas_agents" ]; then
    return 0
  fi

  # Orchestrator is always a PAS agent even if not declared in any phase
  if [ "$agent_type" = "orchestrator" ]; then
    return 0
  fi

  if echo "$pas_agents" | grep -qx "$agent_type"; then
    return 0
  fi

  return 1
}

# Find active workspace using the shared workspace resolution function.
# Sets ACTIVE_STATUS, ACTIVE_WORKSPACE, FEEDBACK_DIR.
# Uses PAS_PROJECT_ROOT (set by guard_pas_project) so worktree-cwd sessions
# resolve to the main checkout's .pas/workspace/.
# When INPUT carries a session_id, the resolver prefers the workspace whose
# current_session: matches — this closes the multi-instance picking-the-
# wrong-workspace bug (#52).
# Returns 1 if no workspace found.
guard_active_workspace() {
  local script_dir="$1"
  source "$script_dir/lib/workspace.sh"

  # Ensure PAS_PROJECT_ROOT is resolved (may be unset if caller skipped guard_pas_project).
  if [ -z "${PAS_PROJECT_ROOT:-}" ]; then
    guard_pas_project || return 1
  fi

  WORKSPACE_DIR="$PAS_PROJECT_ROOT/$PAS_ROOT/workspace"
  if [ ! -d "$WORKSPACE_DIR" ]; then
    return 1
  fi

  # Derive short session id from INPUT (if present); pass to the resolver
  # so multi-instance resolution picks the workspace this session is
  # working on, not the most-recently-touched sibling.
  local session_short=""
  if [ -n "${INPUT:-}" ]; then
    local full_session
    full_session=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$full_session" ]; then
      session_short=$(echo "$full_session" | cut -c1-8)
    fi
  fi

  ACTIVE_STATUS=$(find_active_workspace_status "$WORKSPACE_DIR" "$session_short") || return 1
  ACTIVE_WORKSPACE=$(dirname "$ACTIVE_STATUS")
  FEEDBACK_DIR="$ACTIVE_WORKSPACE/feedback"
}
