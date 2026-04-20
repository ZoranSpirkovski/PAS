#!/usr/bin/env bash
set -euo pipefail

# scaffold-marketplace.sh — Create a minimal Claude Code marketplace repo
# scaffold in the current working directory. Used by the bootstrap-marketplace
# skill when a user wants to start a new user-controlled marketplace.

MARKETPLACE_NAME=""
PLUGIN_NAME=""
DESCRIPTION=""
SKIP_GIT=false

usage() {
  cat <<'USAGE'
Usage: scaffold-marketplace.sh [options]

Required:
  --marketplace-name NAME  Marketplace slug (kebab-case recommended)
  --plugin-name NAME       First plugin's slug (kebab-case recommended)

Optional:
  --description TEXT       Description for both marketplace.json and plugin.json
  --skip-git               Don't run git init / initial commit

Scaffolds at $(pwd):
  .claude-plugin/marketplace.json
  plugins/<plugin-name>/.claude-plugin/plugin.json
  plugins/<plugin-name>/hooks/hooks.json
  plugins/<plugin-name>/skills/.gitkeep
  plugins/<plugin-name>/processes/.gitkeep
  plugins/<plugin-name>/library/.gitkeep

Preconditions:
  - cwd must be a directory.
  - cwd must NOT already contain .claude-plugin/marketplace.json.
USAGE
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --marketplace-name) MARKETPLACE_NAME="$2"; shift 2 ;;
    --plugin-name) PLUGIN_NAME="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --skip-git) SKIP_GIT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Unknown flag: $1"; usage ;;
  esac
done

[[ -z "$MARKETPLACE_NAME" ]] && { echo "Error: --marketplace-name required" >&2; exit 1; }
[[ -z "$PLUGIN_NAME" ]] && { echo "Error: --plugin-name required" >&2; exit 1; }
[[ -z "$DESCRIPTION" ]] && DESCRIPTION="A user-controlled PAS marketplace."

# Validate kebab-case
if [[ ! "$MARKETPLACE_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: marketplace-name must be kebab-case. Got: '$MARKETPLACE_NAME'" >&2
  exit 1
fi
if [[ ! "$PLUGIN_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: plugin-name must be kebab-case. Got: '$PLUGIN_NAME'" >&2
  exit 1
fi

# Preconditions
if [[ -f "$(pwd)/.claude-plugin/marketplace.json" ]]; then
  echo "Error: .claude-plugin/marketplace.json already exists in $(pwd)" >&2
  echo "  This directory is already a marketplace. Refusing to overwrite." >&2
  exit 1
fi

# git init if needed
if [[ "$SKIP_GIT" != true ]]; then
  if [[ ! -d .git ]]; then
    git init -q
    echo "  git init"
  fi
fi

# Create marketplace.json
mkdir -p .claude-plugin
cat > .claude-plugin/marketplace.json <<EOF
{
  "name": "${MARKETPLACE_NAME}",
  "owner": {
    "name": "${MARKETPLACE_NAME}"
  },
  "metadata": {
    "description": "${DESCRIPTION}",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "${PLUGIN_NAME}",
      "source": "./plugins/${PLUGIN_NAME}",
      "description": "${DESCRIPTION}",
      "version": "0.1.0"
    }
  ]
}
EOF
echo "  Created .claude-plugin/marketplace.json"

# Create plugin scaffold
PLUGIN_DIR="plugins/${PLUGIN_NAME}"
mkdir -p "${PLUGIN_DIR}/.claude-plugin" "${PLUGIN_DIR}/hooks" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/processes" "${PLUGIN_DIR}/library"

cat > "${PLUGIN_DIR}/.claude-plugin/plugin.json" <<EOF
{
  "name": "${PLUGIN_NAME}",
  "version": "0.1.0",
  "description": "${DESCRIPTION}"
}
EOF
echo "  Created ${PLUGIN_DIR}/.claude-plugin/plugin.json"

cat > "${PLUGIN_DIR}/hooks/hooks.json" <<'EOF'
{
  "hooks": {}
}
EOF
echo "  Created ${PLUGIN_DIR}/hooks/hooks.json"

for dir in skills processes library; do
  touch "${PLUGIN_DIR}/${dir}/.gitkeep"
done
echo "  Created ${PLUGIN_DIR}/{skills,processes,library}/.gitkeep"

# Seed a README
cat > README.md <<EOF
# ${MARKETPLACE_NAME}

${DESCRIPTION}

This is a Claude Code marketplace scaffolded by PAS. It contains:

- \`.claude-plugin/marketplace.json\` — the marketplace manifest.
- \`plugins/${PLUGIN_NAME}/\` — starter plugin with hooks/skills/processes/library layout.

## Using this marketplace

Register with Claude Code from a shell inside this directory:

\`\`\`
/plugin marketplace add .
/plugin install ${PLUGIN_NAME}@${MARKETPLACE_NAME}
\`\`\`

Or publish to GitHub and register by repo slug:

\`\`\`
gh repo create <org>/${MARKETPLACE_NAME} --public --source=. --push
/plugin marketplace add <org>/${MARKETPLACE_NAME}
\`\`\`

## Adding skills and processes

Run \`/pas:pas\` inside this directory. PAS will detect the marketplace and
create skills/processes under \`plugins/${PLUGIN_NAME}/\`.
EOF
echo "  Created README.md"

# Initial commit (best-effort)
if [[ "$SKIP_GIT" != true ]] && command -v git >/dev/null 2>&1; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git add .claude-plugin/ "${PLUGIN_DIR}/" README.md >/dev/null 2>&1 || true
    if ! git diff --cached --quiet 2>/dev/null; then
      git commit -q -m "Bootstrap ${MARKETPLACE_NAME} marketplace" 2>/dev/null || true
    fi
  fi
fi

echo ""
echo "Marketplace '${MARKETPLACE_NAME}' scaffolded at $(pwd)."
echo "Next: cd to plugin tree or run /pas:pas to add skills/processes."
