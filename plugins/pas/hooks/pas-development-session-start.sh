#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: outputs development routing context for PAS development projects.
# Fires on every session but only produces output when the project has the
# pas-development skill registered (i.e., this IS the PAS repository).

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only relevant for projects that have the pas-development skill
if [ -z "$CWD" ] || [ ! -f "$CWD/.claude/skills/pas-development/SKILL.md" ]; then
  exit 0
fi

cat <<'EOF'
DEVELOPMENT ROUTING: When changes are being made to the PAS plugin (plugins/pas/), invoke /pas-development instead of editing files directly. It provides structured discovery, planning, execution, validation, and release with feedback collection. The pas-development process can use /pas to create any hooks, processes, agents, or skills it needs.
EOF

exit 0
