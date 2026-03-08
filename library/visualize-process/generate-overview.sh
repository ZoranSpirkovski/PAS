#!/usr/bin/env bash
set -euo pipefail

# Generate a self-contained HTML overview of a PAS process.
# Usage: ./generate-overview.sh <process-dir>
# Output: <process-dir>/overview.html

PROCESS_DIR="${1:?Usage: generate-overview.sh <process-dir>}"
PROCESS_DIR="${PROCESS_DIR%/}"

if [[ ! -f "$PROCESS_DIR/process.md" ]]; then
  echo "Error: $PROCESS_DIR/process.md not found" >&2
  exit 1
fi

# --- YAML frontmatter parser ---
parse_yaml_value() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | { grep "^${key}:" || true; } | head -1 | sed "s/^${key}:[[:space:]]*//"
}

parse_phase_names() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" | \
    sed -n '/^phases:/,/^[a-z]/p' | \
    { grep '^  [a-z]' || true; } | { grep -v '^    ' || true; } | sed 's/:[[:space:]]*//' | sed 's/^[[:space:]]*//'
}

parse_phase_field() {
  local file="$1" phase="$2" field="$3"
  sed -n '/^---$/,/^---$/p' "$file" | \
    sed -n "/^  ${phase}:/,/^  [a-z]/p" | \
    { grep "^    ${field}:" || true; } | head -1 | sed "s/^    ${field}:[[:space:]]*//"
}

esc() {
  echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

titlecase() {
  echo "$1" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

orch_description() {
  case "$1" in
    solo) echo "Single-agent operation where the orchestrator handles everything directly. No delegation, no team members." ;;
    hub-and-spoke) echo "Central orchestrator coordinates all agents through a hub. Agents communicate via the orchestrator, enabling parallel dispatch within phases." ;;
    discussion) echo "Multi-agent discussion where the orchestrator moderates. Agents debate and synthesize toward shared conclusions." ;;
    sequential-agents) echo "Strict handoff between agents in sequence. Each agent completes before the next begins." ;;
    *) echo "$1 orchestration pattern." ;;
  esac
}

# --- Read process.md ---
PROC_NAME=$(parse_yaml_value "$PROCESS_DIR/process.md" "name")
PROC_GOAL=$(parse_yaml_value "$PROCESS_DIR/process.md" "goal")
PROC_VERSION=$(parse_yaml_value "$PROCESS_DIR/process.md" "version")
PROC_ORCH=$(parse_yaml_value "$PROCESS_DIR/process.md" "orchestration")

PHASE_NAMES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && PHASE_NAMES+=("$line")
done < <(parse_phase_names "$PROCESS_DIR/process.md")
PHASE_COUNT=${#PHASE_NAMES[@]}

# --- Read agents ---
AGENT_DIRS=()
if [[ -d "$PROCESS_DIR/agents" ]]; then
  for d in "$PROCESS_DIR/agents"/*/; do
    [[ -f "${d}agent.md" ]] && AGENT_DIRS+=("$d")
  done
fi
AGENT_COUNT=${#AGENT_DIRS[@]}

# --- Read modes ---
MODE_FILES=()
if [[ -d "$PROCESS_DIR/modes" ]]; then
  for f in "$PROCESS_DIR/modes"/*.md; do
    [[ -f "$f" ]] && MODE_FILES+=("$f")
  done
fi

# --- Build phase flow HTML ---
PHASES_HTML=""
for i in "${!PHASE_NAMES[@]}"; do
  phase="${PHASE_NAMES[$i]}"
  agents_raw=$(parse_phase_field "$PROCESS_DIR/process.md" "$phase" "agent")
  agents_clean=$(echo "$agents_raw" | tr -d '[]' | sed 's/,/, /g')
  pattern=$(parse_phase_field "$PROCESS_DIR/process.md" "$phase" "pattern")
  [[ -z "$pattern" ]] && pattern="default"
  output=$(parse_phase_field "$PROCESS_DIR/process.md" "$phase" "output")
  gate=$(parse_phase_field "$PROCESS_DIR/process.md" "$phase" "gate")

  [[ $i -gt 0 ]] && PHASES_HTML+='      <div class="phase-arrow">&rarr;</div>
'

  PHASES_HTML+="      <div class=\"phase-card\">
        <h3>$(esc "$(titlecase "$phase")")</h3>
        <div class=\"phase-detail\"><strong>Agents:</strong> $(esc "$agents_clean")</div>
        <div class=\"phase-detail\"><strong>Pattern:</strong> $(esc "$pattern")</div>
        <div class=\"phase-detail\"><strong>Output:</strong> $(esc "$output")</div>
        <div class=\"phase-gate\">Gate: $(esc "$gate")</div>
      </div>
"
done

# --- Build agent cards HTML ---
AGENTS_HTML=""
for agent_dir in "${AGENT_DIRS[@]}"; do
  afile="${agent_dir}agent.md"
  aname=$(parse_yaml_value "$afile" "name")
  adesc=$(parse_yaml_value "$afile" "description")
  amodel=$(parse_yaml_value "$afile" "model")

  tools_raw=$(parse_yaml_value "$afile" "tools")
  TOOLS_HTML="<span class=\"badge badge-model\">$(esc "$amodel")</span>"
  while IFS= read -r tool; do
    tool=$(echo "$tool" | xargs)
    [[ -n "$tool" ]] && TOOLS_HTML+="
          <span class=\"badge badge-tool\">$(esc "$tool")</span>"
  done < <(echo "$tools_raw" | tr -d '[]' | tr ',' '\n')

  SKILLS_HTML=""
  while IFS= read -r skill_path; do
    skill_path=$(echo "$skill_path" | sed 's/^[[:space:]-]*//' | sed 's/[[:space:]]*$//')
    [[ -z "$skill_path" ]] && continue

    lib_class=""
    [[ "$skill_path" == *library/* ]] && lib_class=" library"

    # Resolve skill file
    skill_file=""
    if [[ "$skill_path" == library/* ]]; then
      candidate="${PROCESS_DIR}/../../${skill_path}"
      [[ -f "$candidate" ]] && skill_file="$candidate"
    else
      candidate="${agent_dir}${skill_path}"
      [[ -f "$candidate" ]] && skill_file="$candidate"
    fi

    sname="" sdesc=""
    if [[ -n "$skill_file" ]] && [[ -f "$skill_file" ]]; then
      sname=$(parse_yaml_value "$skill_file" "name")
      sdesc=$(parse_yaml_value "$skill_file" "description")
    else
      sname=$(basename "$(dirname "$skill_path")" 2>/dev/null || echo "$skill_path")
    fi

    [[ ${#sdesc} -gt 120 ]] && sdesc="${sdesc:0:117}..."

    SKILLS_HTML+="          <div class=\"skill-item${lib_class}\">
            <span class=\"skill-name\">$(esc "$sname")</span>
            <span class=\"skill-desc\">— $(esc "$sdesc")</span>
          </div>
"
  done < <(sed -n '/^---$/,/^---$/p' "$afile" | sed -n '/^skills:/,/^[a-z]/p' | { grep '^\s*-' || true; } | sed 's/^[[:space:]-]*//')

  AGENTS_HTML+="      <div class=\"agent-card\">
        <h3>$(esc "$(titlecase "$aname")")</h3>
        <div class=\"agent-desc\">$(esc "$adesc")</div>
        <div>
          ${TOOLS_HTML}
        </div>
        <div class=\"skill-list\">
          <div class=\"skill-list-title\">Skills</div>
${SKILLS_HTML}        </div>
      </div>
"
done

# --- Build modes HTML ---
MODES_HTML=""
for mfile in "${MODE_FILES[@]}"; do
  mname=$(parse_yaml_value "$mfile" "name")
  mdesc=$(parse_yaml_value "$mfile" "description")
  mgates=$(parse_yaml_value "$mfile" "gates")
  gates_class="gates-advisory"
  [[ "$mgates" == "enforced" ]] && gates_class="gates-enforced"

  MODES_HTML+="      <div class=\"mode-card\">
        <h3>$(esc "$(titlecase "$mname")")</h3>
        <div class=\"mode-desc\">$(esc "$mdesc")</div>
        <div class=\"mode-gates ${gates_class}\">Gates: $(esc "$mgates")</div>
      </div>
"
done

ORCH_DESC=$(orch_description "$PROC_ORCH")

# --- Write HTML ---
OUT="$PROCESS_DIR/overview.html"

cat > "$OUT" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$(esc "$PROC_NAME") — Process Overview</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&family=Lora:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #faf9f5; --surface: #ffffff; --border: #e8e6dc; --text: #141413;
      --text-muted: #7a7870; --text-light: #b0aea5; --accent: #d97757;
      --green: #788c5d; --blue: #5b7fa6; --blue-bg: #eaf0f6;
      --purple: #8b6fa6; --header-bg: #141413; --header-text: #faf9f5;
      --radius: 6px; --radius-lg: 10px;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Lora', Georgia, serif; background: var(--bg); color: var(--text); line-height: 1.6; }
    .header { background: var(--header-bg); color: var(--header-text); padding: 2rem 2.5rem; }
    .header h1 { font-family: 'Poppins', sans-serif; font-size: 1.75rem; font-weight: 600; margin-bottom: 0.5rem; }
    .header .goal { font-size: 1rem; opacity: 0.8; max-width: 700px; }
    .header .meta { display: flex; gap: 1.5rem; margin-top: 1rem; font-family: 'Poppins', sans-serif; font-size: 0.8rem; opacity: 0.6; }
    .container { max-width: 1100px; margin: 0 auto; padding: 2rem 2.5rem; }
    .section { margin-bottom: 2.5rem; }
    .section-title { font-family: 'Poppins', sans-serif; font-size: 1.1rem; font-weight: 600; margin-bottom: 1rem; padding-bottom: 0.5rem; border-bottom: 2px solid var(--border); }
    .phase-flow { display: flex; align-items: stretch; gap: 0; overflow-x: auto; padding: 1rem 0; }
    .phase-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 1.25rem; min-width: 200px; flex: 1; }
    .phase-card h3 { font-family: 'Poppins', sans-serif; font-size: 0.95rem; font-weight: 600; margin-bottom: 0.5rem; text-transform: capitalize; }
    .phase-card .phase-detail { font-size: 0.8rem; color: var(--text-muted); margin-bottom: 0.25rem; }
    .phase-card .phase-gate { font-size: 0.75rem; color: var(--accent); margin-top: 0.75rem; padding-top: 0.5rem; border-top: 1px solid var(--border); font-family: 'Poppins', sans-serif; }
    .phase-arrow { display: flex; align-items: center; padding: 0 0.5rem; color: var(--text-light); font-size: 1.5rem; flex-shrink: 0; }
    .agent-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; }
    .agent-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 1.25rem; }
    .agent-card h3 { font-family: 'Poppins', sans-serif; font-size: 0.95rem; font-weight: 600; margin-bottom: 0.25rem; text-transform: capitalize; }
    .agent-card .agent-desc { font-size: 0.85rem; color: var(--text-muted); margin-bottom: 0.75rem; }
    .badge { display: inline-block; font-family: 'Poppins', sans-serif; font-size: 0.7rem; font-weight: 500; padding: 0.15rem 0.5rem; border-radius: 3px; margin-right: 0.35rem; margin-bottom: 0.25rem; }
    .badge-model { background: var(--blue-bg); color: var(--blue); }
    .badge-tool { background: var(--bg); color: var(--text-muted); border: 1px solid var(--border); }
    .skill-list { margin-top: 0.75rem; padding-top: 0.5rem; border-top: 1px solid var(--border); }
    .skill-list-title { font-family: 'Poppins', sans-serif; font-size: 0.75rem; font-weight: 500; color: var(--text-light); margin-bottom: 0.35rem; }
    .skill-item { font-size: 0.8rem; padding: 0.2rem 0; }
    .skill-item .skill-name { font-weight: 500; }
    .skill-item.library .skill-name { color: var(--purple); }
    .skill-item .skill-desc { color: var(--text-muted); font-size: 0.75rem; }
    .mode-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }
    .mode-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 1.25rem; }
    .mode-card h3 { font-family: 'Poppins', sans-serif; font-size: 0.95rem; font-weight: 600; margin-bottom: 0.25rem; text-transform: capitalize; }
    .mode-card .mode-desc { font-size: 0.85rem; color: var(--text-muted); margin-bottom: 0.5rem; }
    .mode-card .mode-gates { font-family: 'Poppins', sans-serif; font-size: 0.75rem; }
    .gates-enforced { color: var(--accent); }
    .gates-advisory { color: var(--green); }
    .orchestration-box { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 1.5rem; }
    .orchestration-box h3 { font-family: 'Poppins', sans-serif; font-size: 0.95rem; font-weight: 600; margin-bottom: 0.5rem; text-transform: capitalize; }
    .orchestration-box p { font-size: 0.85rem; color: var(--text-muted); }
    .footer { text-align: center; padding: 2rem; font-size: 0.75rem; color: var(--text-light); font-family: 'Poppins', sans-serif; }
  </style>
</head>
<body>

<div class="header">
  <h1>$(esc "$PROC_NAME")</h1>
  <div class="goal">$(esc "$PROC_GOAL")</div>
  <div class="meta">
    <span>Version $(esc "$PROC_VERSION")</span>
    <span>$(esc "$PROC_ORCH") orchestration</span>
    <span>${AGENT_COUNT} agents</span>
    <span>${PHASE_COUNT} phases</span>
  </div>
</div>

<div class="container">

  <div class="section">
    <div class="section-title">Phase Flow</div>
    <div class="phase-flow">
${PHASES_HTML}    </div>
  </div>

  <div class="section">
    <div class="section-title">Agents</div>
    <div class="agent-grid">
${AGENTS_HTML}    </div>
  </div>

  <div class="section">
    <div class="section-title">Modes</div>
    <div class="mode-grid">
${MODES_HTML}    </div>
  </div>

  <div class="section">
    <div class="section-title">Orchestration Pattern</div>
    <div class="orchestration-box">
      <h3>$(esc "$(titlecase "$PROC_ORCH")")</h3>
      <p>$(esc "$ORCH_DESC")</p>
    </div>
  </div>

</div>

<div class="footer">
  Generated from process definition
</div>

</body>
</html>
HTMLEOF

echo "Generated: $OUT"
