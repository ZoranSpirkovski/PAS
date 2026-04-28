# Cycle 18 — Implementation Plan

Target: PAS plugin **1.4.3**.
Branch: `feature/cycle-18-quiet-stop-hook`.

## Commit sequence

### C01 — `lib/guards.sh`: add `pas_version_footer()` helper

Append a new function after `resolve_claude_plugin_root()`:

```bash
# Emit a one-line attribution footer for use inside demand/block messages.
# Echoes a string like "(PAS plugin 1.4.3, install: /home/.../pas/1.4.3)".
# Reads version from the resolved $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json.
# Safe to call after resolve_claude_plugin_root() succeeds; no-op (empty echo)
# otherwise.
pas_version_footer() {
  local plugin_json version
  plugin_json="${CLAUDE_PLUGIN_ROOT:-}/.claude-plugin/plugin.json"
  if [ ! -f "$plugin_json" ]; then
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    version=$(jq -r '.version // empty' "$plugin_json" 2>/dev/null)
  else
    version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_json" | head -1)
  fi
  if [ -n "$version" ]; then
    echo "(PAS plugin ${version}, install: ${CLAUDE_PLUGIN_ROOT})"
  fi
}
```

### C02 — `verify-completion-gate.sh`: silent skips + version footer on demand

Two changes:

**1. Silent skips at L44 and L61.** Replace the `echo "[PAS] Stop hook: ..." >&2` lines with `:` (a no-op). Comments above each skip already document the rationale; the user-facing text is removed.

**2. Version footer at L163 (demand block).** Add `echo "$(pas_version_footer)"` as the last line inside the `} >&2` heredoc-like block, just before `exit 2`.

### C03 — `check-self-eval.sh`: silent INFO bypass + version footer on demand

Two changes:

**1. Silent INFO at L71.** Remove the `echo "PAS feedback hook INFO: ..." >&2` line entirely; keep `exit 0`.

**2. Version footer at L77 demand block.** After the `EOF` of the heredoc, before `exit 2`, append `echo "$(pas_version_footer)" >&2`.

### C04 — `verify-task-completion.sh`: version footer on each demand block

For each of the four `cat >&2 <<EOF` demand blocks (L43, L58, L71, L117), add a `echo "$(pas_version_footer)" >&2` after the closing `EOF`, before the `exit 2`. No silencing changes — every demand here is a real block.

### C05 — Test harness: assert silent skips + version footer presence

In `plugins/pas/hooks/tests/test-hooks.sh`:

**1. Update C16-5b** (cross-session misroute test, ~L1957) — currently asserts the skip message contains "does not bind session mineabc1". Change the assertion to: stdout/stderr should be empty AND exit 0.

**2. Update C17-1** (no-advanced-phases test, ~L1745) — currently asserts the skip message contains "no advanced phases". Change to: empty stderr + exit 0.

**3. Add new C18 section** — three tests:

- `C18-1`: gate demand block contains `(PAS plugin <version>` footer.
- `C18-2`: check-self-eval demand block contains the footer.
- `C18-3`: verify-task-completion demand block contains the footer.

Test count: 148 → 151 (+3 new C18; the two existing tests get re-pointed but count stays same).

### C06 — `hooks/changelog.md` entry

Document 1.4.3 — silent skips, version footer on demands, no behavior change to demand timing.

### C07 — Version bump

`bash plugins/pas/hooks/lib/bump-version.sh` → 1.4.2 → 1.4.3.

## Validation plan

1. `bash plugins/pas/hooks/tests/test-hooks.sh` — must pass with 151 tests.
2. Trace the offending consumer scenario (`pas-misrouted-and-migration-ts` workspace) against the new gate:
   - Pipe Stop event with matching session_id → assert exit 0, **no stderr at all**.
3. Trace a productive scenario (all phases completed, no feedback file) → assert exit 2, demand block contains version footer.

## Risk

- **Test re-pointing risk (C05 step 1+2):** changing existing assertions from "contains message" to "empty + exit 0" — easy to mess up. Validate by running the harness after each individual test edit.
- **Version footer noise on demands:** the demand block becomes one line longer. Acceptable trade-off — demands are rare and the footer is useful.
- **No runtime behavior change:** silent skips have identical exit codes to noisy skips. Demands are unchanged in timing or exit code. Only stderr content changes.

## Estimated effort

~20 minutes total. Solo edits, single quick cycle.
