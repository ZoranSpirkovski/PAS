#!/usr/bin/env bash
set -euo pipefail

# Stop hook: routes feedback signals to artifact backlogs.
# Enhanced: also extracts signals from last_assistant_message,
# mkdir -p before all log writes, sort-by-mtime for workspace detection.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/guards.sh"
resolve_claude_plugin_root || exit 1

guard_parse_input || exit 0

LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

# --- Functions ---

resolve_target_path() {
  local target="$1"
  local type value
  type=$(echo "$target" | cut -d: -f1)
  value=$(echo "$target" | cut -d: -f2-)

  # Framework signals go to GitHub issues — caller handles via route_framework_signal
  if [ "$type" = "framework" ]; then
    echo "__framework__"
    return 0
  fi

  local found=""

  # Tier 1: marketplace clone (marketplace-authoritative model, PAS ≥ 1.4.0).
  # Search under the writable marketplace clone that Claude Code manages.
  local origin marketplace_root plugin_name
  origin=$(resolve_origin_marketplace 2>/dev/null || true)
  if [ -n "$origin" ]; then
    marketplace_root=$(echo "$origin" | cut -f1)
    plugin_name=$(echo "$origin" | cut -f2)
    local search_root="$marketplace_root/plugins/$plugin_name"
    case "$type" in
      process) found=$(ls -d "$search_root/processes/$value/feedback/backlog" 2>/dev/null | head -1) ;;
      agent)   found=$(find "$search_root/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1) ;;
      skill)
        found=$(find "$search_root/processes" -path "*/skills/$value/feedback/backlog" -type d 2>/dev/null | head -1)
        if [ -z "$found" ]; then
          found=$(find "$search_root/library" -path "*/$value/feedback/backlog" -type d 2>/dev/null | head -1)
        fi
        ;;
    esac
    if [ -n "$found" ]; then
      echo "$found"
      return 0
    fi
  fi

  # Tier 2: plugin install path (read-only, but targets may exist as backlog
  # directories shipped in the plugin even if we can't write there — the write
  # path will redirect to marketplace clone via origin lookup above when it
  # matters).
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    case "$type" in
      process) found=$(ls -d "$CLAUDE_PLUGIN_ROOT/processes/$value/feedback/backlog" 2>/dev/null | head -1) ;;
      agent)   found=$(find "$CLAUDE_PLUGIN_ROOT/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1) ;;
      skill)
        found=$(find "$CLAUDE_PLUGIN_ROOT/processes" -path "*/skills/$value/feedback/backlog" -type d 2>/dev/null | head -1)
        if [ -z "$found" ]; then
          found=$(find "$CLAUDE_PLUGIN_ROOT/library" -path "*/$value/feedback/backlog" -type d 2>/dev/null | head -1)
        fi
        ;;
    esac
    if [ -n "$found" ]; then
      echo "$found"
      return 0
    fi
  fi

  # Tier 3: consumer-local .pas/processes tree (legacy; transitional
  # backward-compat for consumers/cycles that still carry process copies).
  # Removed in a future cycle once downstream has migrated.
  # Anchor to PAS_PROJECT_ROOT (not CWD) so subagent CWDs under .pas/workspace/
  # don't silently drop signals to "Unknown target" (#156 issue 3).
  local tier3_root="${PAS_PROJECT_ROOT:-$CWD}"
  case "$type" in
    process)
      if [ -d "$tier3_root/$PAS_ROOT/processes/$value/feedback/backlog" ]; then
        found="$tier3_root/$PAS_ROOT/processes/$value/feedback/backlog"
      fi
      ;;
    agent)
      found=$(find "$tier3_root/$PAS_ROOT/processes" -path "*/agents/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      ;;
    skill)
      found=$(find "$tier3_root/$PAS_ROOT/processes" -path "*/skills/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      if [ -z "$found" ]; then
        found=$(find "$tier3_root/$PAS_ROOT/library" -path "*/$value/feedback/backlog" -type d 2>/dev/null | head -1)
      fi
      ;;
  esac

  echo "${found:-}"
}

route_signal() {
  local signal_block="$1"
  local signal_id="$2"
  local source_basename="$3"
  local target_path="$4"

  local today host_id
  today=$(date +%Y-%m-%d)
  host_id=$(resolve_host_id "${CWD:-$(pwd)}" 2>/dev/null || echo "unknown-host")

  # Filename format: <date>-<host-id>-<source>-<signal-id>.md
  # host-id disambiguates multi-host writes to shared marketplace clones.
  local dest_file="$target_path/${today}-${host_id}-${source_basename}-${signal_id}.md"

  # Write the file.
  if ! mkdir -p "$target_path" 2>/dev/null; then
    _route_to_outbox "$signal_block" "$signal_id" "$source_basename" "$target_path" "mkdir-failed"
    return 0
  fi
  if ! echo "$signal_block" > "$dest_file" 2>/dev/null; then
    _route_to_outbox "$signal_block" "$signal_id" "$source_basename" "$target_path" "write-failed"
    return 0
  fi

  # If the destination is inside a marketplace clone, git-commit it locally.
  # Never push — the user pushes explicitly. This makes feedback survive any
  # `/plugin marketplace update` that Claude Code runs against the clone.
  case "$target_path" in
    "$HOME/.claude/plugins/marketplaces/"*)
      local marketplace_dir
      marketplace_dir=$(echo "$target_path" | sed -n 's|\(.*/\.claude/plugins/marketplaces/[^/]*\)/.*|\1|p')
      if [ -n "$marketplace_dir" ] && [ -d "$marketplace_dir/.git" ]; then
        (
          cd "$marketplace_dir" 2>/dev/null || exit 0
          git add "$dest_file" >/dev/null 2>&1 || exit 0
          git commit --no-verify -m "feedback: ${signal_id} (${host_id})" >/dev/null 2>&1 || true
        )
      fi
      ;;
  esac
}

# Private: write an undelivered signal to the plugin-data outbox so it
# isn't lost. A future 'propagate-feedback' op drains this outbox.
_route_to_outbox() {
  local signal_block="$1"
  local signal_id="$2"
  local source_basename="$3"
  local intended_target="$4"
  local reason="$5"

  local outbox_root="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugins/data/pas}"
  local outbox_dir="$outbox_root/feedback-outbox"
  mkdir -p "$outbox_dir" 2>/dev/null || return 0

  local today host_id
  today=$(date +%Y-%m-%d)
  host_id=$(resolve_host_id "${CWD:-$(pwd)}" 2>/dev/null || echo "unknown-host")
  local outbox_file="$outbox_dir/${today}-${host_id}-${source_basename}-${signal_id}.md"

  {
    echo "# PAS Outbox — undelivered feedback"
    echo "# Reason: $reason"
    echo "# Intended target path: $intended_target"
    echo "# Signal ID: $signal_id"
    echo "---"
    echo "$signal_block"
  } > "$outbox_file" 2>/dev/null || true

  local warn_log="${CWD:-$(pwd)}/$PAS_ROOT/feedback/warnings.log"
  mkdir -p "$(dirname "$warn_log")" 2>/dev/null || true
  echo "[$(date -Iseconds)] OUTBOX: $signal_id staged at $outbox_file (reason: $reason)" >> "$warn_log" 2>/dev/null || true
}

route_framework_signal() {
  local signal_block="$1"
  local signal_id="$2"
  local log_dir="${PAS_PROJECT_ROOT:-$CWD}/$PAS_ROOT/feedback"
  mkdir -p "$log_dir"

  # Guard: only route signals marked for GitHub issue creation
  if ! echo "$signal_block" | grep -q 'Route: github-issue'; then
    echo "[$(date -Iseconds)] INFO: Framework signal ${signal_id} not marked 'Route: github-issue', skipping" >> "$log_dir/framework-routing.log" 2>/dev/null || true
    return 0
  fi

  # Resolve target repo from config — must NEVER fall through to the host
  # project's repo. The plugin's pas-config.yaml ships with
  # framework_signal_repo set; an empty value is a hard refusal so we never
  # silently file framework signals on a downstream consumer's product repo.
  local target_repo=""
  if [ -n "${PAS_CONFIG:-}" ] && [ -f "$PAS_CONFIG" ]; then
    target_repo=$(grep '^framework_signal_repo:' "$PAS_CONFIG" 2>/dev/null | head -1 | awk '{print $2}')
  fi
  # Fall back to the framework default (read from the plugin install dir,
  # never from $CWD) when the project config doesn't carry the field.
  if [ -z "$target_repo" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/pas-config.yaml" ]; then
    target_repo=$(grep '^framework_signal_repo:' "$CLAUDE_PLUGIN_ROOT/pas-config.yaml" 2>/dev/null | head -1 | awk '{print $2}')
  fi

  if [ -z "$target_repo" ]; then
    echo "[$(date -Iseconds)] REFUSED: framework_signal_repo unresolved; will NOT file ${signal_id} (refusing to default to host project repo)" >> "$log_dir/framework-routing.log" 2>/dev/null || true
    return 0
  fi

  # Audit: record the resolved repo BEFORE the gh call so any future
  # mis-routing regression is visible in the log.
  echo "[$(date -Iseconds)] INFO: Filing ${signal_id} on repo ${target_repo}" >> "$log_dir/framework-routing.log" 2>/dev/null || true

  # Guard: check gh CLI is available and authenticated
  if ! command -v gh >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] WARNING: gh CLI not found, cannot route ${signal_id} to GitHub" >> "$log_dir/framework-routing.log" 2>/dev/null || true
    return 0
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] WARNING: gh not authenticated, cannot route ${signal_id} to GitHub" >> "$log_dir/framework-routing.log" 2>/dev/null || true
    return 0
  fi

  # Extract a one-line summary from the signal block
  local summary
  summary=$(echo "$signal_block" | grep -E '^(Degraded:|Preference:|Rejected Change:|Behavior:)' | head -1 | sed 's/^[^:]*:[[:space:]]*//')
  if [ -z "$summary" ]; then
    # Fallback: use the second line (first line after the signal ID header)
    summary=$(echo "$signal_block" | sed -n '2p' | sed 's/^[[:space:]]*//')
  fi
  # Truncate summary to 80 chars
  summary=$(echo "$summary" | cut -c1-80)

  # File as GitHub issue
  if gh issue create --repo "$target_repo" \
    --title "[Feedback] ${signal_id}: ${summary}" \
    --body "$signal_block" >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] OK: Filed ${signal_id} as GitHub issue on ${target_repo}" >> "$log_dir/framework-routing.log" 2>/dev/null || true
  else
    echo "[$(date -Iseconds)] ERROR: Failed to file ${signal_id} as GitHub issue on ${target_repo}" >> "$log_dir/framework-routing.log" 2>/dev/null || true
  fi
}

parse_and_route_signals() {
  local text="$1"
  local source_name="$2"

  local current_signal=""
  local current_id=""
  local current_target=""

  while IFS= read -r line || [ -n "$line" ]; do
    if echo "$line" | grep -qE '^\[(PPU|OQI|GATE|STA)-[0-9]+\]'; then
      # Route previous signal
      if [ -n "$current_signal" ] && [ -n "$current_target" ]; then
        local target_path
        target_path=$(resolve_target_path "$current_target")
        if [ "$target_path" = "__framework__" ]; then
          route_framework_signal "$current_signal" "$current_id"
        elif [ -n "$target_path" ]; then
          route_signal "$current_signal" "$current_id" "$source_name" "$target_path"
        else
          # Anchor warnings.log to PAS_PROJECT_ROOT (not CWD) so subagent CWDs
          # under .pas/workspace/<X>/ don't create recursive .pas/.pas/ paths
          # (#156 issue 1).
          local warn_root="${PAS_PROJECT_ROOT:-$CWD}"
          mkdir -p "$warn_root/$PAS_ROOT/feedback"
          echo "[$(date -Iseconds)] WARNING: Unknown target '$current_target'" >> "$warn_root/$PAS_ROOT/feedback/warnings.log" 2>/dev/null || true
        fi
      fi

      current_id=$(echo "$line" | grep -oE '(PPU|OQI|GATE|STA)-[0-9]+')
      current_signal="$line"
      current_target=""
    else
      if [ -n "$current_id" ]; then
        current_signal="$current_signal
$line"
      fi
      if echo "$line" | grep -qE '^Target:'; then
        current_target=$(echo "$line" | sed 's/^Target:[[:space:]]*//')
      fi
    fi
  done <<< "$text"

  # Route last signal
  if [ -n "$current_signal" ] && [ -n "$current_target" ]; then
    local target_path
    target_path=$(resolve_target_path "$current_target")
    if [ "$target_path" = "__framework__" ]; then
      route_framework_signal "$current_signal" "$current_id"
    elif [ -n "$target_path" ]; then
      route_signal "$current_signal" "$current_id" "$source_name" "$target_path"
    else
      mkdir -p "$CWD/$PAS_ROOT/feedback"
      echo "[$(date -Iseconds)] WARNING: Unknown target '$current_target'" >> "$CWD/$PAS_ROOT/feedback/warnings.log" 2>/dev/null || true
    fi
  fi
}

# --- Main ---

guard_active_workspace "$SCRIPT_DIR" || exit 0

# Route from .md files (primary mechanism)
if [ -d "$FEEDBACK_DIR" ]; then
  FEEDBACK_FILES=$(find "$FEEDBACK_DIR" -maxdepth 1 -name "*.md" 2>/dev/null)

  if [ -n "$FEEDBACK_FILES" ]; then
    echo "$FEEDBACK_FILES" | while read -r feedback_file; do
      [ -f "$feedback_file" ] || continue
      # Skip already-routed files
      [ -f "${feedback_file}.routed" ] && continue
      source_basename=$(basename "$feedback_file" .md)
      parse_and_route_signals "$(cat "$feedback_file")" "$source_basename"
      touch "${feedback_file}.routed"
    done
  fi
fi

# Route from last_assistant_message (P1 — catches inline feedback)
if [ -n "$LAST_MESSAGE" ]; then
  if echo "$LAST_MESSAGE" | grep -qE '\[(PPU|OQI|GATE|STA)-[0-9]+\]'; then
    parse_and_route_signals "$LAST_MESSAGE" "inline-final-message"
  fi
fi

exit 0
