#!/usr/bin/env bash
set -euo pipefail
# Bump the patch version across all PAS distribution files.
# Run from the repo root. Outputs the new version string to stdout.

PLUGIN_JSON="plugins/pas/.claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

# --- Read current version ---

read_version() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.version' "$PLUGIN_JSON"
  else
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1
  fi
}

CURRENT=$(read_version)
if [ -z "$CURRENT" ]; then
  echo "bump-version: could not read version from $PLUGIN_JSON" >&2
  exit 1
fi

# --- Increment patch ---

MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

# --- Write to all locations ---

write_with_jq() {
  local file="$1" filter="$2"
  local tmp="${file}.tmp"
  jq "$filter" "$file" > "$tmp" && mv "$tmp" "$file"
}

write_with_sed() {
  local file="$1" old="$2" new="$3"
  sed -i "s/\"$old\"/\"$new\"/" "$file"
}

if command -v jq >/dev/null 2>&1; then
  write_with_jq "$PLUGIN_JSON"      ".version = \"$NEW_VERSION\""
  write_with_jq "$MARKETPLACE_JSON"  ".metadata.version = \"$NEW_VERSION\" | .plugins[0].version = \"$NEW_VERSION\""
else
  write_with_sed "$PLUGIN_JSON"      "$CURRENT" "$NEW_VERSION"
  write_with_sed "$MARKETPLACE_JSON" "$CURRENT" "$NEW_VERSION"
fi

echo "$NEW_VERSION"
