# Generation Scripts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace manual PAS artifact creation with three deterministic bash scripts that generate complete processes, agents, and skills from CLI arguments.

**Architecture:** Three standalone bash scripts (`pas-create-skill`, `pas-create-agent`, `pas-create-process`), each co-located with its parent skill under `scripts/`. Scripts use heredocs for file generation, named flags for input, and validate all args before writing. The existing SKILL.md files get simplified to guide the orchestrator through creative decisions, then call the script for mechanical generation.

**Tech Stack:** Bash (heredocs, getopts-style arg parsing), no external dependencies.

---

### Task 1: Create `pas-create-skill` Script

Build the leaf-node script first since it has no dependencies on other scripts.

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill`

**Step 1: Create the script directory**

```bash
mkdir -p plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts
```

**Step 2: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# pas-create-skill — Generate a complete PAS skill directory from CLI arguments
# Usage: pas-create-skill --process NAME --agent NAME --name NAME --description "..." --overview "..." --step "..." [options]

PROCESS=""
AGENT=""
NAME=""
DESCRIPTION=""
OVERVIEW=""
WHEN_TO_USE=""
WHEN_NOT_TO_USE=""
OUTPUT_FORMAT=""
FORCE=false
declare -a STEPS=()
declare -a QUALITY_CHECKS=()
declare -a COMMON_MISTAKES=()

usage() {
  cat <<'USAGE'
Usage: pas-create-skill [options]

Required:
  --process NAME        Parent process name
  --agent NAME          Parent agent name
  --name NAME           Skill slug (kebab-case)
  --description TEXT    "Use when..." trigger description
  --overview TEXT       Core principle in 1-2 sentences
  --step TEXT           Process step (repeatable, in order)

Optional:
  --when-to-use TEXT    Specific trigger conditions
  --when-not-to-use TEXT  When NOT to use
  --output-format TEXT  What the skill produces
  --quality-check TEXT  Self-check criterion (repeatable)
  --common-mistake TEXT Known pitfall (repeatable)
  --force               Overwrite existing directory
USAGE
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --process) PROCESS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --overview) OVERVIEW="$2"; shift 2 ;;
    --when-to-use) WHEN_TO_USE="$2"; shift 2 ;;
    --when-not-to-use) WHEN_NOT_TO_USE="$2"; shift 2 ;;
    --step) STEPS+=("$2"); shift 2 ;;
    --output-format) OUTPUT_FORMAT="$2"; shift 2 ;;
    --quality-check) QUALITY_CHECKS+=("$2"); shift 2 ;;
    --common-mistake) COMMON_MISTAKES+=("$2"); shift 2 ;;
    --force) FORCE=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: Unknown flag '$1'"; usage ;;
  esac
done

# Validate required flags
MISSING=()
[[ -z "$PROCESS" ]] && MISSING+=("--process")
[[ -z "$AGENT" ]] && MISSING+=("--agent")
[[ -z "$NAME" ]] && MISSING+=("--name")
[[ -z "$DESCRIPTION" ]] && MISSING+=("--description")
[[ -z "$OVERVIEW" ]] && MISSING+=("--overview")
[[ ${#STEPS[@]} -eq 0 ]] && MISSING+=("--step (at least one)")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: Missing required flags: ${MISSING[*]}"
  exit 1
fi

# Validate kebab-case
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: --name must be kebab-case (lowercase letters, numbers, hyphens). Got: '$NAME'"
  exit 1
fi

# Build target path
TARGET="processes/${PROCESS}/agents/${AGENT}/skills/${NAME}"

# Check directory conflict
if [[ -d "$TARGET" && "$FORCE" != true ]]; then
  echo "Error: ${TARGET}/ already exists. Use --force to overwrite."
  exit 1
fi

if [[ -d "$TARGET" && "$FORCE" == true ]]; then
  rm -rf "$TARGET"
fi

# Convert skill name to title case for heading
TITLE=$(echo "$NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

# Count files created
FILE_COUNT=0

# Create directory structure
mkdir -p "${TARGET}/references"
mkdir -p "${TARGET}/feedback/backlog"

# Generate SKILL.md
{
  cat <<EOF
---
name: ${NAME}
description: ${DESCRIPTION}
---

# ${TITLE}

## Overview

${OVERVIEW}
EOF

  # When to Use section
  if [[ -n "$WHEN_TO_USE" || -n "$WHEN_NOT_TO_USE" ]]; then
    echo ""
    echo "## When to Use"
    echo ""
    [[ -n "$WHEN_TO_USE" ]] && echo "${WHEN_TO_USE}"
    if [[ -n "$WHEN_NOT_TO_USE" ]]; then
      echo ""
      echo "**When NOT to use:** ${WHEN_NOT_TO_USE}"
    fi
  fi

  # Process section
  echo ""
  echo "## Process"
  echo ""
  for i in "${!STEPS[@]}"; do
    echo "$((i + 1)). ${STEPS[$i]}"
  done

  # Output Format section
  if [[ -n "$OUTPUT_FORMAT" ]]; then
    echo ""
    echo "## Output Format"
    echo ""
    echo "${OUTPUT_FORMAT}"
  fi

  # Quality Checks section
  if [[ ${#QUALITY_CHECKS[@]} -gt 0 ]]; then
    echo ""
    echo "## Quality Checks"
    echo ""
    for check in "${QUALITY_CHECKS[@]}"; do
      echo "- ${check}"
    done
  fi

  # Common Mistakes section
  echo ""
  echo "## Common Mistakes"
  echo ""
  if [[ ${#COMMON_MISTAKES[@]} -gt 0 ]]; then
    for mistake in "${COMMON_MISTAKES[@]}"; do
      echo "- ${mistake}"
    done
  else
    echo "(Populated by feedback over time)"
  fi
} > "${TARGET}/SKILL.md"
echo "  Created ${TARGET}/SKILL.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Generate changelog.md
cat > "${TARGET}/changelog.md" <<EOF
# ${TITLE} Changelog
EOF
echo "  Created ${TARGET}/changelog.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Create .gitkeep
touch "${TARGET}/feedback/backlog/.gitkeep"
echo "  Created ${TARGET}/feedback/backlog/.gitkeep"
FILE_COUNT=$((FILE_COUNT + 1))

echo ""
echo "Created skill '${NAME}' with ${FILE_COUNT} files in ${TARGET}/"
```

**Step 3: Make the script executable**

```bash
chmod +x plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill
```

**Step 4: Test the script**

Run from project root:

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill \
  --process test-process \
  --agent test-agent \
  --name test-skill \
  --description "Use when testing the generation script." \
  --overview "A test skill for verifying pas-create-skill works correctly." \
  --when-to-use "When running generation script tests" \
  --when-not-to-use "In production" \
  --step "Do the first thing" \
  --step "Do the second thing" \
  --output-format "A test output file" \
  --quality-check "File exists" \
  --quality-check "Content is correct" \
  --common-mistake "Forgetting to clean up test artifacts"
```

Expected: Script creates `processes/test-process/agents/test-agent/skills/test-skill/` with SKILL.md, changelog.md, feedback/backlog/.gitkeep, and references/.

Verify:
```bash
# Check files exist
ls -la processes/test-process/agents/test-agent/skills/test-skill/
ls -la processes/test-process/agents/test-agent/skills/test-skill/feedback/backlog/
ls -la processes/test-process/agents/test-agent/skills/test-skill/references/

# Check SKILL.md content has frontmatter and all sections
grep -q "name: test-skill" processes/test-process/agents/test-agent/skills/test-skill/SKILL.md
grep -q "## Process" processes/test-process/agents/test-agent/skills/test-skill/SKILL.md
grep -q "1\. Do the first thing" processes/test-process/agents/test-agent/skills/test-skill/SKILL.md
grep -q "## Quality Checks" processes/test-process/agents/test-agent/skills/test-skill/SKILL.md
grep -q "## Common Mistakes" processes/test-process/agents/test-agent/skills/test-skill/SKILL.md
```

**Step 5: Test validation — missing required flag**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill \
  --process test-process \
  --agent test-agent \
  --name test-skill
```

Expected: Exit code 1, error message listing missing flags.

**Step 6: Test validation — bad name format**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill \
  --process test-process \
  --agent test-agent \
  --name "Bad Name" \
  --description "test" \
  --overview "test" \
  --step "test"
```

Expected: Exit code 1, error about kebab-case.

**Step 7: Test validation — directory conflict**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill \
  --process test-process \
  --agent test-agent \
  --name test-skill \
  --description "test" \
  --overview "test" \
  --step "test"
```

Expected: Exit code 1, error about directory existing. Then test with `--force`:

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill \
  --process test-process \
  --agent test-agent \
  --name test-skill \
  --description "test" \
  --overview "test" \
  --step "test" \
  --force
```

Expected: Succeeds, overwrites.

**Step 8: Clean up test artifacts**

```bash
rm -rf processes/test-process
```

**Step 9: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill
git commit -m "Add pas-create-skill generation script"
```

---

### Task 2: Create `pas-create-agent` Script

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent`

**Step 1: Create the script directory**

```bash
mkdir -p plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts
```

**Step 2: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# pas-create-agent — Generate a complete PAS agent directory from CLI arguments
# Usage: pas-create-agent --process NAME --name NAME --description "..." --model ID --tools "..." --identity "..." --behavior "..." --deliverable "..." [options]

PROCESS=""
NAME=""
DESCRIPTION=""
MODEL=""
TOOLS=""
IDENTITY=""
ROLE="specialist"
FORCE=false
declare -a BEHAVIORS=()
declare -a DELIVERABLES=()

VALID_MODELS=("claude-opus-4-6" "claude-sonnet-4-6" "claude-haiku-4-5")
ORCHESTRATOR_TOOLS="Read,Write,Edit,Bash,Grep,Glob,WebSearch,WebFetch,Agent,SendMessage,TeamCreate"

usage() {
  cat <<'USAGE'
Usage: pas-create-agent [options]

Required:
  --process NAME        Parent process name
  --name NAME           Agent slug (kebab-case)
  --description TEXT    One-sentence role description
  --model ID            Model ID (claude-opus-4-6, claude-sonnet-4-6, claude-haiku-4-5)
  --tools LIST          Comma-separated tool list
  --identity TEXT       2-3 sentences defining who the agent is
  --behavior TEXT       Behavioral rule (repeatable)
  --deliverable TEXT    What the agent produces (repeatable)

Optional:
  --role TYPE           orchestrator or specialist (default: specialist)
  --force               Overwrite existing directory
USAGE
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --process) PROCESS="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --tools) TOOLS="$2"; shift 2 ;;
    --identity) IDENTITY="$2"; shift 2 ;;
    --behavior) BEHAVIORS+=("$2"); shift 2 ;;
    --deliverable) DELIVERABLES+=("$2"); shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: Unknown flag '$1'"; usage ;;
  esac
done

# Validate required flags
MISSING=()
[[ -z "$PROCESS" ]] && MISSING+=("--process")
[[ -z "$NAME" ]] && MISSING+=("--name")
[[ -z "$DESCRIPTION" ]] && MISSING+=("--description")
[[ -z "$MODEL" ]] && MISSING+=("--model")
[[ -z "$TOOLS" ]] && MISSING+=("--tools")
[[ -z "$IDENTITY" ]] && MISSING+=("--identity")
[[ ${#BEHAVIORS[@]} -eq 0 ]] && MISSING+=("--behavior (at least one)")
[[ ${#DELIVERABLES[@]} -eq 0 ]] && MISSING+=("--deliverable (at least one)")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: Missing required flags: ${MISSING[*]}"
  exit 1
fi

# Validate kebab-case
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: --name must be kebab-case (lowercase letters, numbers, hyphens). Got: '$NAME'"
  exit 1
fi

# Validate model
VALID_MODEL=false
for m in "${VALID_MODELS[@]}"; do
  [[ "$MODEL" == "$m" ]] && VALID_MODEL=true
done
if [[ "$VALID_MODEL" != true ]]; then
  echo "Error: --model must be one of: ${VALID_MODELS[*]}. Got: '$MODEL'"
  exit 1
fi

# Validate role
if [[ "$ROLE" != "orchestrator" && "$ROLE" != "specialist" ]]; then
  echo "Error: --role must be 'orchestrator' or 'specialist'. Got: '$ROLE'"
  exit 1
fi

# If orchestrator, merge required tools
if [[ "$ROLE" == "orchestrator" ]]; then
  # Build a set of all tools (user-provided + required orchestrator tools)
  IFS=',' read -ra USER_TOOLS <<< "$TOOLS"
  IFS=',' read -ra ORCH_TOOLS <<< "$ORCHESTRATOR_TOOLS"
  declare -A TOOL_SET=()
  declare -a TOOL_ORDER=()
  for t in "${ORCH_TOOLS[@]}"; do
    t=$(echo "$t" | xargs)  # trim whitespace
    if [[ -z "${TOOL_SET[$t]+_}" ]]; then
      TOOL_SET[$t]=1
      TOOL_ORDER+=("$t")
    fi
  done
  for t in "${USER_TOOLS[@]}"; do
    t=$(echo "$t" | xargs)
    if [[ -z "${TOOL_SET[$t]+_}" ]]; then
      TOOL_SET[$t]=1
      TOOL_ORDER+=("$t")
    fi
  done
  TOOLS=$(IFS=','; echo "${TOOL_ORDER[*]}" | sed 's/,/, /g')
fi

# Build target path
TARGET="processes/${PROCESS}/agents/${NAME}"

# Check directory conflict
if [[ -d "$TARGET" && "$FORCE" != true ]]; then
  echo "Error: ${TARGET}/ already exists. Use --force to overwrite."
  exit 1
fi

if [[ -d "$TARGET" && "$FORCE" == true ]]; then
  rm -rf "$TARGET"
fi

# Convert name to title case for heading
TITLE=$(echo "$NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

# Format tools as YAML list
TOOLS_YAML="[$(echo "$TOOLS" | sed 's/,\s*/, /g')]"

FILE_COUNT=0

# Create directory structure
mkdir -p "${TARGET}/skills"
mkdir -p "${TARGET}/references"
mkdir -p "${TARGET}/feedback/backlog"

# Generate agent.md
{
  # Frontmatter
  cat <<EOF
---
name: ${NAME}
description: ${DESCRIPTION}
model: ${MODEL}
tools: ${TOOLS_YAML}
skills:
  - library/self-evaluation/SKILL.md
---

# ${TITLE}

## Identity

${IDENTITY}

## Behavior

EOF

  # Behavior rules
  for behavior in "${BEHAVIORS[@]}"; do
    echo "- ${behavior}"
  done

  # Orchestrator-specific behavior
  if [[ "$ROLE" == "orchestrator" ]]; then
    cat <<'EOF'
- Read processes/{process}/process.md on startup
- Read the orchestration pattern from library/orchestration/ as declared in process.md
- Read workspace status to determine where to resume
- Delegate phases to specialist agents via TeamCreate
- Interface with the user at gates (supervised mode)
- Update workspace status.yaml continuously
- Manage the shutdown sequence (downstream feedback, self-eval, finalize status)
EOF
  fi

  # Deliverables
  echo ""
  echo "## Deliverables"
  echo ""
  for deliverable in "${DELIVERABLES[@]}"; do
    echo "- ${deliverable}"
  done

  # Known Pitfalls
  echo ""
  echo "## Known Pitfalls"
  echo ""
  echo "(Populated by feedback over time)"
} > "${TARGET}/agent.md"

# Fix the orchestrator behavior to use actual process name
if [[ "$ROLE" == "orchestrator" ]]; then
  sed -i "s|processes/{process}|processes/${PROCESS}|g" "${TARGET}/agent.md"
fi

echo "  Created ${TARGET}/agent.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Generate changelog.md
cat > "${TARGET}/changelog.md" <<EOF
# ${TITLE} Changelog
EOF
echo "  Created ${TARGET}/changelog.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Create .gitkeep
touch "${TARGET}/feedback/backlog/.gitkeep"
echo "  Created ${TARGET}/feedback/backlog/.gitkeep"
FILE_COUNT=$((FILE_COUNT + 1))

echo ""
echo "Created agent '${NAME}' with ${FILE_COUNT} files in ${TARGET}/"
```

**Step 3: Make the script executable**

```bash
chmod +x plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent
```

**Step 4: Test the script — specialist agent**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent \
  --process test-process \
  --name researcher \
  --description "Researches topics using web search" \
  --model claude-sonnet-4-6 \
  --tools "Read,Write,WebSearch,WebFetch" \
  --identity "A meticulous researcher who values accuracy over speed." \
  --behavior "Always cite sources with URLs" \
  --behavior "Flag low-confidence claims explicitly" \
  --deliverable "workspace/{slug}/research.md"
```

Verify:
```bash
ls -la processes/test-process/agents/researcher/
ls -la processes/test-process/agents/researcher/skills/
ls -la processes/test-process/agents/researcher/references/
ls -la processes/test-process/agents/researcher/feedback/backlog/
grep -q "name: researcher" processes/test-process/agents/researcher/agent.md
grep -q "model: claude-sonnet-4-6" processes/test-process/agents/researcher/agent.md
grep -q "Always cite sources" processes/test-process/agents/researcher/agent.md
```

**Step 5: Test the script — orchestrator agent**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent \
  --process test-process \
  --name orchestrator \
  --description "Manages the test process" \
  --model claude-opus-4-6 \
  --tools "Read,Write" \
  --identity "A capable orchestrator." \
  --behavior "Coordinate all phases" \
  --deliverable "Completed process output" \
  --role orchestrator
```

Verify:
```bash
# Should have all orchestrator tools merged in
grep -q "TeamCreate" processes/test-process/agents/orchestrator/agent.md
grep -q "SendMessage" processes/test-process/agents/orchestrator/agent.md
# Should have orchestrator-specific behavior
grep -q "Read processes/test-process/process.md on startup" processes/test-process/agents/orchestrator/agent.md
grep -q "shutdown sequence" processes/test-process/agents/orchestrator/agent.md
```

**Step 6: Test validation — invalid model**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent \
  --process test-process \
  --name bad-agent \
  --description "test" \
  --model gpt-4 \
  --tools "Read" \
  --identity "test" \
  --behavior "test" \
  --deliverable "test"
```

Expected: Exit code 1, error about invalid model.

**Step 7: Clean up and commit**

```bash
rm -rf processes/test-process
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent
git commit -m "Add pas-create-agent generation script"
```

---

### Task 3: Create `pas-create-process` Script

**Files:**
- Create: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process`

**Step 1: Create the script directory**

```bash
mkdir -p plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts
```

**Step 2: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# pas-create-process — Generate a complete PAS process directory from CLI arguments
# Usage: pas-create-process --name NAME --goal "..." --orchestration PATTERN --phase "name:agent:input:output:gate" --input "name:description" [options]

NAME=""
GOAL=""
ORCHESTRATION=""
DESCRIPTION=""
SEQUENTIAL="false"
FORCE=false
declare -a PHASES=()
declare -a INPUTS=()

VALID_PATTERNS=("solo" "hub-and-spoke" "sequential-agents" "discussion")

usage() {
  cat <<'USAGE'
Usage: pas-create-process [options]

Required:
  --name NAME           Process slug (kebab-case)
  --goal TEXT           One-sentence goal
  --orchestration PAT   Pattern: solo, hub-and-spoke, sequential-agents, discussion
  --phase SPEC          Phase spec as "name:agent:input:output:gate" (repeatable)
  --input SPEC          Input spec as "name:description" (repeatable)

Optional:
  --description TEXT    Prose description for process.md body
  --sequential BOOL     Force linear execution (default: false)
  --force               Overwrite existing directory
USAGE
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --goal) GOAL="$2"; shift 2 ;;
    --orchestration) ORCHESTRATION="$2"; shift 2 ;;
    --phase) PHASES+=("$2"); shift 2 ;;
    --input) INPUTS+=("$2"); shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --sequential) SEQUENTIAL="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: Unknown flag '$1'"; usage ;;
  esac
done

# Validate required flags
MISSING=()
[[ -z "$NAME" ]] && MISSING+=("--name")
[[ -z "$GOAL" ]] && MISSING+=("--goal")
[[ -z "$ORCHESTRATION" ]] && MISSING+=("--orchestration")
[[ ${#PHASES[@]} -eq 0 ]] && MISSING+=("--phase (at least one)")
[[ ${#INPUTS[@]} -eq 0 ]] && MISSING+=("--input (at least one)")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: Missing required flags: ${MISSING[*]}"
  exit 1
fi

# Validate kebab-case
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: --name must be kebab-case (lowercase letters, numbers, hyphens). Got: '$NAME'"
  exit 1
fi

# Validate orchestration pattern
VALID_PATTERN=false
for p in "${VALID_PATTERNS[@]}"; do
  [[ "$ORCHESTRATION" == "$p" ]] && VALID_PATTERN=true
done
if [[ "$VALID_PATTERN" != true ]]; then
  echo "Error: --orchestration must be one of: ${VALID_PATTERNS[*]}. Got: '$ORCHESTRATION'"
  exit 1
fi

# Validate phase format (5 colon-separated fields)
for phase in "${PHASES[@]}"; do
  FIELD_COUNT=$(echo "$phase" | awk -F: '{print NF}')
  if [[ "$FIELD_COUNT" -ne 5 ]]; then
    echo "Error: --phase must have 5 colon-separated fields (name:agent:input:output:gate). Got ${FIELD_COUNT} fields in: '$phase'"
    exit 1
  fi
done

# Validate input format (2 colon-separated fields)
for input in "${INPUTS[@]}"; do
  FIELD_COUNT=$(echo "$input" | awk -F: '{print NF}')
  if [[ "$FIELD_COUNT" -ne 2 ]]; then
    echo "Error: --input must have 2 colon-separated fields (name:description). Got ${FIELD_COUNT} fields in: '$input'"
    exit 1
  fi
done

# Build target path
TARGET="processes/${NAME}"

# Check directory conflict
if [[ -d "$TARGET" && "$FORCE" != true ]]; then
  echo "Error: ${TARGET}/ already exists. Use --force to overwrite."
  exit 1
fi

if [[ -d "$TARGET" && "$FORCE" == true ]]; then
  rm -rf "$TARGET"
fi

# Convert name to title case for heading
TITLE=$(echo "$NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

FILE_COUNT=0

# Create directory structure
mkdir -p "${TARGET}/agents"
mkdir -p "${TARGET}/modes"
mkdir -p "${TARGET}/references"
mkdir -p "${TARGET}/feedback/backlog"

# Generate process.md
{
  # YAML frontmatter
  cat <<EOF
---
name: ${NAME}
goal: ${GOAL}
version: 1.0
orchestration: ${ORCHESTRATION}
sequential: ${SEQUENTIAL}
modes: [supervised, autonomous]

input:
EOF

  # Input entries
  for input in "${INPUTS[@]}"; do
    INPUT_NAME=$(echo "$input" | cut -d: -f1)
    INPUT_DESC=$(echo "$input" | cut -d: -f2-)
    echo "  - ${INPUT_NAME}: ${INPUT_DESC}"
  done

  echo ""
  echo "phases:"

  # Phase entries
  for phase in "${PHASES[@]}"; do
    PHASE_NAME=$(echo "$phase" | cut -d: -f1)
    PHASE_AGENT=$(echo "$phase" | cut -d: -f2)
    PHASE_INPUT=$(echo "$phase" | cut -d: -f3)
    PHASE_OUTPUT=$(echo "$phase" | cut -d: -f4)
    PHASE_GATE=$(echo "$phase" | cut -d: -f5)
    cat <<EOF
  ${PHASE_NAME}:
    agent: ${PHASE_AGENT}
    input: ${PHASE_INPUT}
    output: ${PHASE_OUTPUT}
    gate: ${PHASE_GATE}
EOF
  done

  cat <<EOF

status_file: workspace/${NAME}/{slug}/status.yaml
---

# ${TITLE}

EOF

  # Description
  if [[ -n "$DESCRIPTION" ]]; then
    echo "${DESCRIPTION}"
  else
    echo "${GOAL}"
  fi

  echo ""
  echo "## Phases"
  echo ""

  # Phase descriptions
  for phase in "${PHASES[@]}"; do
    PHASE_NAME=$(echo "$phase" | cut -d: -f1)
    PHASE_TITLE=$(echo "$PHASE_NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
    PHASE_AGENT=$(echo "$phase" | cut -d: -f2)
    PHASE_INPUT=$(echo "$phase" | cut -d: -f3)
    PHASE_OUTPUT=$(echo "$phase" | cut -d: -f4)
    PHASE_GATE=$(echo "$phase" | cut -d: -f5)
    echo "**${PHASE_TITLE}**: Agent \`${PHASE_AGENT}\` takes \`${PHASE_INPUT}\` and produces \`${PHASE_OUTPUT}\`. Gate: ${PHASE_GATE}."
    echo ""
  done
} > "${TARGET}/process.md"
echo "  Created ${TARGET}/process.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Generate modes/supervised.md
cat > "${TARGET}/modes/supervised.md" <<'EOF'
---
name: supervised
description: User reviews and approves at every phase gate
gates: enforced
---

## Behavior

- After each phase completes, STOP and present the output to the user
- Do NOT launch the next phase until the user approves
- Present a summary of what was produced, key findings, and any concerns
- If the user requests changes, route them to the appropriate agent

## Gate Protocol

At each gate:
1. Show phase output summary (not raw files unless asked)
2. Flag any quality concerns or red flags
3. Ask: "Approve and continue, or request changes?"
EOF
echo "  Created ${TARGET}/modes/supervised.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Generate modes/autonomous.md
cat > "${TARGET}/modes/autonomous.md" <<'EOF'
---
name: autonomous
description: Execute all phases without pausing at gates
gates: advisory
---

## Behavior

- Execute phases sequentially without pausing for user approval
- Log gate results but do not stop
- Self-review at each gate point
- Flag critical issues even in autonomous mode

## Gate Protocol

At each gate:
1. Self-evaluate phase output against gate criteria
2. Log result to status.yaml
3. Continue to next phase unless critical issue detected
4. If critical issue: pause and alert the user
EOF
echo "  Created ${TARGET}/modes/autonomous.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Generate changelog.md
cat > "${TARGET}/changelog.md" <<EOF
# ${TITLE} Changelog
EOF
echo "  Created ${TARGET}/changelog.md"
FILE_COUNT=$((FILE_COUNT + 1))

# Create .gitkeep
touch "${TARGET}/feedback/backlog/.gitkeep"
echo "  Created ${TARGET}/feedback/backlog/.gitkeep"
FILE_COUNT=$((FILE_COUNT + 1))

# Generate thin launcher
LAUNCHER_DIR=".claude/skills/${NAME}"
mkdir -p "${LAUNCHER_DIR}"
cat > "${LAUNCHER_DIR}/SKILL.md" <<EOF
---
name: ${NAME}
description: ${GOAL}
---

Read \`processes/${NAME}/process.md\` for the process definition.
Read the orchestration pattern from \`library/orchestration/\` as specified in the process.
Execute.
EOF
echo "  Created ${LAUNCHER_DIR}/SKILL.md"
FILE_COUNT=$((FILE_COUNT + 1))

echo ""
echo "Created process '${NAME}' with ${FILE_COUNT} files in ${TARGET}/"
```

**Step 3: Make the script executable**

```bash
chmod +x plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process
```

**Step 4: Test the script**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process \
  --name test-pipeline \
  --goal "Test the process generation script" \
  --orchestration hub-and-spoke \
  --phase "research:researcher:topic.md:research.md:Orchestrator reviews quality" \
  --phase "writing:writer:research.md:draft.md:User approves draft" \
  --input "topic:A markdown file describing the topic" \
  --description "A test pipeline for verifying pas-create-process works correctly."
```

Verify:
```bash
# Check files exist
ls -la processes/test-pipeline/
ls -la processes/test-pipeline/modes/
ls -la processes/test-pipeline/references/
ls -la processes/test-pipeline/agents/
ls -la .claude/skills/test-pipeline/

# Check process.md content
grep -q "name: test-pipeline" processes/test-pipeline/process.md
grep -q "orchestration: hub-and-spoke" processes/test-pipeline/process.md
grep -q "agent: researcher" processes/test-pipeline/process.md
grep -q "agent: writer" processes/test-pipeline/process.md

# Check mode files
grep -q "gates: enforced" processes/test-pipeline/modes/supervised.md
grep -q "gates: advisory" processes/test-pipeline/modes/autonomous.md

# Check thin launcher
grep -q "processes/test-pipeline/process.md" .claude/skills/test-pipeline/SKILL.md
```

**Step 5: Test validation — bad orchestration pattern**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process \
  --name test \
  --goal "test" \
  --orchestration waterfall \
  --phase "a:b:c:d:e" \
  --input "x:y"
```

Expected: Exit code 1, error about invalid orchestration pattern.

**Step 6: Test validation — bad phase format**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process \
  --name test \
  --goal "test" \
  --orchestration solo \
  --phase "only-three:fields:here" \
  --input "x:y"
```

Expected: Exit code 1, error about phase field count.

**Step 7: Clean up and commit**

```bash
rm -rf processes/test-pipeline .claude/skills/test-pipeline
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process
git commit -m "Add pas-create-process generation script"
```

---

### Task 4: Update `creating-skills/SKILL.md` to Script Guide

Transform the skill from a manual creation guide to a script guide. Keep creative decision steps, replace file generation with script call.

**Files:**
- Modify: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/SKILL.md`

**Step 1: Rewrite the skill**

Replace the full contents with:

```markdown
---
name: creating-skills
description: Use when creating or editing a composable skill within a PAS agent or process. Usually invoked by creating-agents, not directly by users.
---

# Creating Skills

Create a composable skill following the Agent Skills open standard. Skills define HOW to do a specific thing. They are agent-facing instruction sets, never user-facing. Skills live inside their owning agent or process by default.

## Workflow

### 1. Determine Purpose

Define what the skill does:

- **Purpose**: what specific capability does this skill provide?
- **Consumers**: which agent(s) will use this skill?
- **Degrees of freedom**: where should the agent exercise judgment vs follow strict rules?
- **Input**: what does the agent need before using this skill?
- **Output**: what does the skill produce?

### 2. Check for Overlap

Before creating a new skill:

- Check existing skills within the owning agent (`processes/{process}/agents/{agent}/skills/`)
- Check existing skills within the process (`processes/{process}/`)
- Check `library/` for global skills that already do this
- If overlap exists: extend the existing skill or reference it instead of duplicating

### 3. Apply Granularity Heuristics

Default to one skill (simpler). Split when any heuristic triggers:

| Heuristic | Question | If Yes |
|-----------|----------|--------|
| **Feedback** | Can you improve one part without touching the other? | Split into separate skills |
| **Reuse** | Could another agent use one part but not the other? | Split into separate skills |
| **Size** | Does the skill exceed ~5000 tokens? | Flag for evaluation: split, restructure, or explicitly justify |

When in doubt, keep it as one skill. You can always split later when feedback indicates the need.

### 4. Generate the Skill

Run the generation script with all decisions from steps 1-3:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/pas-create-skill \
  --process {process-name} \
  --agent {agent-name} \
  --name {skill-name} \
  --description "Use when {triggering conditions}. {What capability this provides.}" \
  --overview "{Core principle in 1-2 sentences}" \
  --when-to-use "{Specific trigger conditions}" \
  --when-not-to-use "{When NOT to use}" \
  --step "{Step 1 instruction}" \
  --step "{Step 2 instruction}" \
  --output-format "{What the skill produces}" \
  --quality-check "{Self-check criterion}" \
  --common-mistake "{Known pitfall}"
```

Repeatable flags: `--step` (required, at least one), `--quality-check`, `--common-mistake`.

**Key rules from the Agent Skills spec:**
- Description = when to use, NOT what it does. Start with "Use when..."
- Progressive disclosure: SKILL.md is the overview. Add heavy material to `references/`.
- Concise: only add what Claude doesn't already know. Challenge each paragraph.
- Consistent terminology: pick one term, use it everywhere.
- SKILL.md must be under 500 lines.

### 5. Library Graduation Check

After creating the skill, check if it should be in `library/` instead:

- Is this exact skill already used by another agent in a different process?
- Would a second process/agent benefit from this skill without modification?

If yes to either: move to `library/{skill-name}/` and reference from both locations. If no: keep it local. Skills start local and graduate to the library only when reuse is proven (used in 2+ places).
```

**Step 2: Verify the skill reads correctly**

Read the updated file and confirm it flows naturally: determine purpose -> check overlap -> granularity -> generate -> graduation check.

**Step 3: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/SKILL.md
git commit -m "Simplify creating-skills to script guide"
```

---

### Task 5: Update `creating-agents/SKILL.md` to Script Guide

**Files:**
- Modify: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/SKILL.md`

**Step 1: Rewrite the skill**

Replace the full contents with:

```markdown
---
name: creating-agents
description: Use when creating or editing an agent within a PAS process. Usually invoked by creating-processes, not directly by users.
---

# Creating Agents

Create an agent definition within a process. Agents are specialists with identities, tools, and skills. They are always process-local. Every process has an orchestrator agent responsible for its success.

## Workflow

### 1. Determine Role

Define the agent's purpose within the process:

- **Name**: short, descriptive (e.g., `researcher`, `fact-checker`, `orchestrator`)
- **Description**: one sentence explaining what this agent does
- **Role type**: orchestrator (manages process) or specialist (handles specific phases)
- **Tools needed**: select from available Claude Code tools based on what the agent needs to do

### 2. Check for Overlap

Before creating a new agent, check existing agents in `processes/{process}/agents/`:

- Would an existing agent's skills cover this role?
- Could an existing agent be extended instead of creating a new one?
- Is there an agent in another process that could serve as inspiration? (Copy, don't share. Agents are always process-local.)

### 3. Determine Skills

For each skill the agent needs:

- Read `creating-skills/SKILL.md` from the same skills directory as this skill
- Follow its workflow to create each skill
- Skills live inside the agent's directory at `skills/{skill-name}/SKILL.md`
- Check `library/` for global skills the agent should carry (e.g., `library/self-evaluation/SKILL.md`)

### 4. Select Model Tier

Match model capability to role complexity:

| Tier | Model | Use When |
|------|-------|----------|
| Opus | claude-opus-4-6 | Orchestration, complex writing, editorial judgment, multi-step reasoning |
| Sonnet | claude-sonnet-4-6 | Research, fact-checking, structured analysis, code generation |
| Haiku | claude-haiku-4-5 | Simple extraction, formatting, classification, single-skill tasks |

Default to Sonnet for specialists, Opus for orchestrators. Downgrade when feedback shows a simpler model performs equally well.

### 5. Generate the Agent

Run the generation script with all decisions from steps 1-4:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/pas-create-agent \
  --process {process-name} \
  --name {agent-name} \
  --description "{one-sentence role description}" \
  --model {model-id} \
  --tools "{comma-separated tool list}" \
  --identity "{2-3 sentences defining who this agent is}" \
  --behavior "{behavioral rule 1}" \
  --behavior "{behavioral rule 2}" \
  --deliverable "{what the agent produces}" \
  --role {orchestrator|specialist}
```

Repeatable flags: `--behavior` (required, at least one), `--deliverable` (required, at least one).

When `--role orchestrator`, the script automatically:
- Merges required orchestrator tools (Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Agent, SendMessage, TeamCreate)
- Adds orchestrator-specific behavior (startup reads, gate management, shutdown sequence)

### 6. Create Agent Skills

For each skill determined in step 3, use `creating-skills/SKILL.md` to generate it. The agent's `skills/` directory was created by the generation script.
```

**Step 2: Verify the skill reads correctly**

Read the updated file and confirm it flows: determine role -> overlap check -> determine skills -> model tier -> generate -> create skills.

**Step 3: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/SKILL.md
git commit -m "Simplify creating-agents to script guide"
```

---

### Task 6: Update `creating-processes/SKILL.md` to Script Guide

**Files:**
- Modify: `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md`

**Step 1: Rewrite the skill**

Replace the full contents with:

```markdown
---
name: creating-processes
description: Use when creating a new PAS process from a user's goal description. Invoked by the PAS router, not directly by users.
---

# Creating Processes

Create a complete process definition from a user's goal. A process defines WHAT needs to happen, in WHAT ORDER, to achieve a specific GOAL. It assigns work to agents, defines phase gates, and manages flow.

## Execution Framing

This skill IS the execution framework. When generating plans for process creation:

- Do NOT produce a standalone task list. Every step is a step within THIS skill's workflow.
- If you are in plan mode, exit plan mode first — this skill requires interactive brainstorming with the user via AskUserQuestion, which plan mode prevents.
- If a step requires work not covered by this skill, flag it as a PAS gap rather than a standalone manual step.

## Workflow

### 1. Clarify the Goal

Apply the crystal clarity principle. Never assume you understand what the user wants.

- Ask one question at a time, brainstorming-style
- Probe for: scope, quality expectations, input format, output format, audience
- Continue until you can state the goal back in a single sentence the user confirms
- If the goal maps to an existing process, suggest modifying it instead of creating new

### 2. Prepare Reference Material (if applicable)

If the process requires domain knowledge from raw source material (transcripts, documentation, course content):

1. Create `processes/{name}/reference/` directory
2. Store the original source material in `reference/source/` — this is the authoritative knowledge base
3. Analyze the source material to determine the best reference format:
   - If already well-structured: use directly, no distillation needed
   - If raw/unstructured (e.g., transcripts): distill into a structured methodology doc alongside the source
   - Match the format and depth to the material — do not impose arbitrary length limits
4. Any distilled reference supplements the source material — it does not replace it
5. Skills must trace techniques back to the source. When a reference doc is insufficient, agents consult the original source material directly.

Skip this step if the process is based on general knowledge or user-provided specifications.

### 3. Design Phases

Break the goal into sequential phases. For each phase define:

- **Input**: what files/data this phase needs (from user or previous phases)
- **Output**: what files/data this phase produces
- **Gate**: what review point exists (user approval, orchestrator check, or none)

**Parallelism**: infer from I/O dependencies. Phases sharing the same input but not depending on each other can run in parallel. Phases listing another phase's output as input must wait. No explicit `depends_on` needed. Optional `sequential: true` at process level to force linear.

### 4. Determine Agents

Start with the minimum viable set. Every process needs an orchestrator. Add specialist agents only when:

- A phase requires distinct expertise (research vs writing vs verification)
- Quality feedback suggests a specialist would outperform the orchestrator
- The phase is complex enough to warrant a dedicated agent

For simple processes (1-3 phases, similar skills), the orchestrator handles everything (solo pattern).

### 5. Select Orchestration Pattern

Read the orchestration decision matrix. If `library/orchestration/SKILL.md` doesn't exist in the user's project yet, bootstrap it by copying from the PAS plugin's library (the `library/` directory next to `processes/` in the plugin). Then apply the decision matrix:

| Agents | Discussion needed? | Parallel phases? | Pattern |
|--------|-------------------|-------------------|---------|
| 1 | N/A | N/A | solo |
| 2+ | Yes | N/A | discussion |
| 2+ | No | Yes | hub-and-spoke |
| 2+ | No | No | sequential-agents |

Default to hub-and-spoke when unsure.

### 6. Generate Process

Run the generation script with all decisions from steps 1-5:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/pas-create-process \
  --name {process-name} \
  --goal "{one-sentence goal}" \
  --orchestration {pattern} \
  --phase "{name}:{agent}:{input}:{output}:{gate}" \
  --input "{name}:{description}" \
  --description "{brief description}" \
  --sequential {true|false}
```

Repeatable flags: `--phase` (required, at least one), `--input` (required, at least one).

This creates the process directory (process.md, mode files, references/, feedback/), thin launcher, and changelog.

### 7. Create Agents

For each agent determined in step 4, use `creating-agents/SKILL.md`:

- Read `creating-agents/SKILL.md` from the same skills directory as this skill
- Follow its workflow for each agent
- The orchestrator agent is always created first

### 8. Verify Against Source Material

If Step 2 (Prepare Reference Material) was used, cross-check every created skill against the reference doc:

1. For each skill, list every technique, tactic, metric, and number it contains
2. Verify each one exists in the reference material — flag any that don't as potential fabrication
3. Check each section of the reference doc is covered by at least one skill — flag uncovered sections as omissions
4. Remove fabricated content. Add skills or skill sections for omissions.

This is a mandatory step when source material exists. Do not skip it.
```

**Step 2: Verify the skill reads correctly**

Read the updated file and confirm it flows: clarify goal -> reference material -> design phases -> determine agents -> select pattern -> generate -> create agents -> verify.

**Step 3: Commit**

```bash
git add plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md
git commit -m "Simplify creating-processes to script guide"
```

---

### Task 7: End-to-End Integration Test

Run all three scripts in sequence to verify they produce a complete, coherent process.

**Files:** None (testing only)

**Step 1: Create a test process**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process \
  --name integration-test \
  --goal "Verify PAS generation scripts work end to end" \
  --orchestration hub-and-spoke \
  --phase "research:researcher:topic.md:research.md:Orchestrator reviews quality" \
  --phase "writing:writer:research.md:draft.md:User approves draft" \
  --input "topic:A markdown file describing the topic"
```

**Step 2: Create agents**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent \
  --process integration-test \
  --name orchestrator \
  --description "Manages the integration test process" \
  --model claude-opus-4-6 \
  --tools "Read,Write" \
  --identity "A test orchestrator for verifying generation scripts." \
  --behavior "Coordinate all phases" \
  --deliverable "Completed process output" \
  --role orchestrator

bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent \
  --process integration-test \
  --name researcher \
  --description "Researches topics" \
  --model claude-sonnet-4-6 \
  --tools "Read,WebSearch,WebFetch" \
  --identity "A meticulous researcher." \
  --behavior "Always cite sources" \
  --deliverable "research.md"

bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-agents/scripts/pas-create-agent \
  --process integration-test \
  --name writer \
  --description "Writes drafts from research" \
  --model claude-sonnet-4-6 \
  --tools "Read,Write" \
  --identity "A skilled writer." \
  --behavior "Write clear prose" \
  --deliverable "draft.md"
```

**Step 3: Create skills for agents**

```bash
bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill \
  --process integration-test \
  --agent researcher \
  --name web-research \
  --description "Use when researching a topic using web search." \
  --overview "Systematic web research." \
  --step "Search for the topic" \
  --step "Cross-reference claims" \
  --step "Compile findings"

bash plugins/pas/processes/pas/agents/orchestrator/skills/creating-skills/scripts/pas-create-skill \
  --process integration-test \
  --agent writer \
  --name drafting \
  --description "Use when writing a draft from research." \
  --overview "Transform research into readable prose." \
  --step "Outline the structure" \
  --step "Write each section" \
  --step "Review for coherence"
```

**Step 4: Verify the complete structure**

```bash
# Verify full directory tree
find processes/integration-test -type f | sort

# Expected output (approximately):
# processes/integration-test/agents/orchestrator/agent.md
# processes/integration-test/agents/orchestrator/changelog.md
# processes/integration-test/agents/orchestrator/feedback/backlog/.gitkeep
# processes/integration-test/agents/researcher/agent.md
# processes/integration-test/agents/researcher/changelog.md
# processes/integration-test/agents/researcher/feedback/backlog/.gitkeep
# processes/integration-test/agents/researcher/skills/web-research/SKILL.md
# processes/integration-test/agents/researcher/skills/web-research/changelog.md
# processes/integration-test/agents/researcher/skills/web-research/feedback/backlog/.gitkeep
# processes/integration-test/agents/writer/agent.md
# processes/integration-test/agents/writer/changelog.md
# processes/integration-test/agents/writer/feedback/backlog/.gitkeep
# processes/integration-test/agents/writer/skills/drafting/SKILL.md
# processes/integration-test/agents/writer/skills/drafting/changelog.md
# processes/integration-test/agents/writer/skills/drafting/feedback/backlog/.gitkeep
# processes/integration-test/changelog.md
# processes/integration-test/feedback/backlog/.gitkeep
# processes/integration-test/modes/autonomous.md
# processes/integration-test/modes/supervised.md
# processes/integration-test/process.md

# Verify cross-references are valid
grep -q "agent: researcher" processes/integration-test/process.md
grep -q "agent: writer" processes/integration-test/process.md
grep -q "orchestration: hub-and-spoke" processes/integration-test/process.md

# Verify thin launcher exists
cat .claude/skills/integration-test/SKILL.md
```

**Step 5: Clean up test artifacts**

```bash
rm -rf processes/integration-test .claude/skills/integration-test
```

**Step 6: Commit version bump and changelog**

Update `CHANGELOG.md` with the generation scripts entry and bump version in `plugins/pas/.claude-plugin/plugin.json` from 1.1.0 to 1.2.0.

```bash
git add CHANGELOG.md plugins/pas/.claude-plugin/plugin.json
git commit -m "Bump version to 1.2.0, add generation scripts changelog"
```
