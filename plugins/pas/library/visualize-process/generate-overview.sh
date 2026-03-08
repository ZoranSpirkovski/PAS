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

  if [[ $i -gt 0 ]]; then
    PHASES_HTML+='      <div class="phase-arrow"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7"/></svg></div>
'
  fi

  PHASES_HTML+="      <div class=\"phase-card\">
        <div class=\"phase-number\">${i+1}</div>
        <h3>$(esc "$(titlecase "$phase")")</h3>
        <div class=\"phase-detail\"><span class=\"phase-label\">Agents</span> $(esc "$agents_clean")</div>
        <div class=\"phase-detail\"><span class=\"phase-label\">Pattern</span> $(esc "$pattern")</div>
        <div class=\"phase-detail\"><span class=\"phase-label\">Output</span> $(esc "$output")</div>
        <div class=\"phase-gate\">$(esc "$gate")</div>
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

  # Model tier class
  model_class="model-default"
  case "$amodel" in
    *opus*) model_class="model-opus" ;;
    *sonnet*) model_class="model-sonnet" ;;
    *haiku*) model_class="model-haiku" ;;
  esac

  tools_raw=$(parse_yaml_value "$afile" "tools")
  TOOLS_HTML=""
  while IFS= read -r tool; do
    tool=$(echo "$tool" | xargs)
    [[ -n "$tool" ]] && TOOLS_HTML+="<span class=\"badge badge-tool\">$(esc "$tool")</span>"
  done < <(echo "$tools_raw" | tr -d '[]' | tr ',' '\n')

  SKILLS_HTML=""
  skill_count=0
  while IFS= read -r skill_path; do
    skill_path=$(echo "$skill_path" | sed 's/^[[:space:]-]*//' | sed 's/[[:space:]]*$//')
    [[ -z "$skill_path" ]] && continue

    lib_class=""
    [[ "$skill_path" == *library/* ]] && lib_class=" library"

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

    # Clean description: remove "Use when" prefix for brevity
    sdesc=$(echo "$sdesc" | sed 's/^Use when //' | sed 's/^Use at /At /')

    SKILLS_HTML+="          <div class=\"skill-item${lib_class}\">
            <span class=\"skill-name\">$(esc "$sname")</span>
            <span class=\"skill-desc\">$(esc "$sdesc")</span>
          </div>
"
    skill_count=$((skill_count + 1))
  done < <(sed -n '/^---$/,/^---$/p' "$afile" | sed -n '/^skills:/,/^[a-z]/p' | { grep '^\s*-' || true; } | sed 's/^[[:space:]-]*//')

  AGENTS_HTML+="      <div class=\"agent-card\">
        <div class=\"agent-header\">
          <h3>$(esc "$(titlecase "$aname")")</h3>
          <span class=\"badge ${model_class}\">$(esc "$amodel")</span>
        </div>
        <p class=\"agent-desc\">$(esc "$adesc")</p>
        <div class=\"agent-tools\">${TOOLS_HTML}</div>
        <div class=\"skill-list\">
          <div class=\"skill-list-title\">${skill_count} skills</div>
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
        <p class=\"mode-desc\">$(esc "$mdesc")</p>
        <div class=\"mode-gates ${gates_class}\">$(esc "$mgates")</div>
      </div>
"
done

ORCH_DESC=$(orch_description "$PROC_ORCH")

# --- Section nav items ---
SECTION_IDS=("phases" "agents" "modes" "orchestration")
SECTION_LABELS=("Phases" "Agents" "Modes" "Orchestration")

NAV_HTML=""
for i in "${!SECTION_IDS[@]}"; do
  NAV_HTML+="<a href=\"#${SECTION_IDS[$i]}\" class=\"nav-link\" data-section=\"${SECTION_IDS[$i]}\">${SECTION_LABELS[$i]}</a>"
done

# --- Write HTML ---
OUT="$PROCESS_DIR/overview.html"

cat > "$OUT" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
HTMLEOF

cat >> "$OUT" << HTMLEOF
  <title>$(esc "$PROC_NAME") — Process Overview</title>
HTMLEOF

cat >> "$OUT" << 'HTMLEOF'
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&family=Lora:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #f7f6f2;
      --surface: #ffffff;
      --surface-hover: #fdfcfa;
      --border: #e8e6dc;
      --border-light: #f0eee8;
      --text: #1a1a18;
      --text-secondary: #5c5b56;
      --text-muted: #8a887f;
      --accent: #d97757;
      --accent-soft: rgba(217,119,87,0.08);
      --green: #6b8a50;
      --green-soft: rgba(107,138,80,0.08);
      --blue: #4a7196;
      --blue-soft: rgba(74,113,150,0.1);
      --purple: #7e6a9b;
      --purple-soft: rgba(126,106,155,0.08);
      --header-bg: #1a1a18;
      --header-text: #f7f6f2;
      --shadow-sm: 0 1px 2px rgba(0,0,0,0.04);
      --shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
      --shadow-md: 0 4px 12px rgba(0,0,0,0.06), 0 1px 3px rgba(0,0,0,0.04);
      --radius: 8px;
      --radius-lg: 12px;
      --nav-height: 48px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }

    html { scroll-behavior: smooth; scroll-padding-top: calc(var(--nav-height) + 1.5rem); }

    body {
      font-family: 'Lora', Georgia, serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.6;
      -webkit-font-smoothing: antialiased;
    }

    /* --- Header --- */
    .header {
      background: var(--header-bg);
      color: var(--header-text);
      padding: 3rem 2rem 2.5rem;
    }
    .header-inner {
      max-width: 1060px;
      margin: 0 auto;
    }
    .header h1 {
      font-family: 'Poppins', sans-serif;
      font-size: 1.6rem;
      font-weight: 700;
      letter-spacing: -0.01em;
      margin-bottom: 0.4rem;
    }
    .header .goal {
      font-size: 0.95rem;
      opacity: 0.75;
      max-width: 600px;
      line-height: 1.5;
    }
    .header .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
      margin-top: 1.25rem;
    }
    .meta-tag {
      font-family: 'Poppins', sans-serif;
      font-size: 0.7rem;
      font-weight: 500;
      padding: 0.25rem 0.65rem;
      border-radius: 100px;
      background: rgba(255,255,255,0.08);
      color: rgba(247,246,242,0.7);
      letter-spacing: 0.01em;
    }

    /* --- Sticky nav --- */
    .section-nav {
      position: sticky;
      top: 0;
      z-index: 100;
      background: var(--surface);
      border-bottom: 1px solid var(--border);
      box-shadow: var(--shadow-sm);
      height: var(--nav-height);
      display: flex;
      align-items: center;
      padding: 0 2rem;
      gap: 0.25rem;
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
    }
    .section-nav::-webkit-scrollbar { display: none; }
    .nav-link {
      font-family: 'Poppins', sans-serif;
      font-size: 0.78rem;
      font-weight: 500;
      color: var(--text-muted);
      text-decoration: none;
      padding: 0.4rem 0.75rem;
      border-radius: 6px;
      white-space: nowrap;
      transition: color 0.15s, background 0.15s;
    }
    .nav-link:hover { color: var(--text); background: var(--border-light); }
    .nav-link.active {
      color: var(--accent);
      background: var(--accent-soft);
    }

    /* --- Container --- */
    .container {
      max-width: 1060px;
      margin: 0 auto;
      padding: 2rem 2rem 4rem;
    }

    /* --- Sections --- */
    .section {
      margin-bottom: 3rem;
    }
    .section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      cursor: pointer;
      padding-bottom: 0.75rem;
      border-bottom: 1px solid var(--border);
      margin-bottom: 1.25rem;
      user-select: none;
      -webkit-user-select: none;
    }
    .section-title {
      font-family: 'Poppins', sans-serif;
      font-size: 1rem;
      font-weight: 600;
      color: var(--text);
      letter-spacing: -0.005em;
    }
    .section-toggle {
      width: 28px;
      height: 28px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 6px;
      color: var(--text-muted);
      transition: transform 0.2s, background 0.15s;
    }
    .section-toggle:hover { background: var(--border-light); }
    .section.collapsed .section-toggle { transform: rotate(-90deg); }
    .section-body {
      overflow: hidden;
      transition: max-height 0.3s ease, opacity 0.2s ease;
      max-height: 5000px;
      opacity: 1;
    }
    .section.collapsed .section-body {
      max-height: 0;
      opacity: 0;
    }

    /* --- Phase Flow --- */
    .phase-flow {
      display: flex;
      align-items: stretch;
      gap: 0;
      padding: 0.25rem 0;
    }
    .phase-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      padding: 1.25rem 1.15rem;
      flex: 1;
      box-shadow: var(--shadow);
      position: relative;
      word-break: break-word;
    }
    .phase-number {
      font-family: 'Poppins', sans-serif;
      font-size: 0.65rem;
      font-weight: 600;
      width: 22px;
      height: 22px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: var(--accent-soft);
      color: var(--accent);
      margin-bottom: 0.6rem;
    }
    .phase-card h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.88rem;
      font-weight: 600;
      margin-bottom: 0.6rem;
      text-transform: capitalize;
    }
    .phase-detail {
      font-size: 0.78rem;
      color: var(--text-secondary);
      margin-bottom: 0.3rem;
      line-height: 1.45;
    }
    .phase-label {
      font-family: 'Poppins', sans-serif;
      font-size: 0.68rem;
      font-weight: 500;
      color: var(--text-muted);
      display: block;
      margin-bottom: 0.1rem;
    }
    .phase-gate {
      font-size: 0.72rem;
      color: var(--accent);
      margin-top: 0.75rem;
      padding-top: 0.6rem;
      border-top: 1px solid var(--border-light);
      font-family: 'Poppins', sans-serif;
      font-weight: 500;
    }
    .phase-arrow {
      display: flex;
      align-items: center;
      padding: 0 0.4rem;
      color: var(--text-muted);
      flex-shrink: 0;
    }
    .phase-arrow svg { width: 20px; height: 20px; }

    /* --- Agent Cards --- */
    .agent-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 1rem;
    }
    .agent-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      padding: 1.25rem;
      box-shadow: var(--shadow);
      display: flex;
      flex-direction: column;
      word-break: break-word;
    }
    .agent-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 0.5rem;
      margin-bottom: 0.35rem;
    }
    .agent-card h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.9rem;
      font-weight: 600;
      text-transform: capitalize;
    }
    .agent-desc {
      font-size: 0.82rem;
      color: var(--text-secondary);
      line-height: 1.45;
      margin-bottom: 0.85rem;
    }
    .agent-tools {
      display: flex;
      flex-wrap: wrap;
      gap: 0.3rem;
      margin-bottom: 0.85rem;
    }

    /* --- Badges --- */
    .badge {
      display: inline-flex;
      align-items: center;
      font-family: 'Poppins', sans-serif;
      font-size: 0.65rem;
      font-weight: 500;
      padding: 0.2rem 0.55rem;
      border-radius: 100px;
      white-space: nowrap;
    }
    .badge-tool {
      background: var(--bg);
      color: var(--text-muted);
      border: 1px solid var(--border);
    }
    .model-opus { background: var(--blue-soft); color: var(--blue); }
    .model-sonnet { background: var(--green-soft); color: var(--green); }
    .model-haiku { background: var(--purple-soft); color: var(--purple); }
    .model-default { background: var(--bg); color: var(--text-muted); border: 1px solid var(--border); }

    /* --- Skills --- */
    .skill-list {
      margin-top: auto;
      padding-top: 0.75rem;
      border-top: 1px solid var(--border-light);
    }
    .skill-list-title {
      font-family: 'Poppins', sans-serif;
      font-size: 0.68rem;
      font-weight: 500;
      color: var(--text-muted);
      margin-bottom: 0.4rem;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }
    .skill-item {
      font-size: 0.78rem;
      padding: 0.3rem 0;
      line-height: 1.4;
      display: flex;
      gap: 0.35rem;
    }
    .skill-name {
      font-family: 'Poppins', sans-serif;
      font-weight: 500;
      font-size: 0.75rem;
      flex-shrink: 0;
    }
    .skill-item.library .skill-name { color: var(--purple); }
    .skill-desc {
      color: var(--text-muted);
      font-size: 0.73rem;
    }

    /* --- Modes --- */
    .mode-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 1rem;
    }
    .mode-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      padding: 1.25rem;
      box-shadow: var(--shadow);
      word-break: break-word;
    }
    .mode-card h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.9rem;
      font-weight: 600;
      margin-bottom: 0.35rem;
      text-transform: capitalize;
    }
    .mode-desc {
      font-size: 0.82rem;
      color: var(--text-secondary);
      line-height: 1.45;
      margin-bottom: 0.6rem;
    }
    .mode-gates {
      font-family: 'Poppins', sans-serif;
      font-size: 0.7rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      padding: 0.3rem 0.65rem;
      border-radius: 100px;
      display: inline-block;
    }
    .gates-enforced { background: var(--accent-soft); color: var(--accent); }
    .gates-advisory { background: var(--green-soft); color: var(--green); }

    /* --- Orchestration --- */
    .orchestration-box {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      padding: 1.5rem;
      box-shadow: var(--shadow);
    }
    .orchestration-box h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.9rem;
      font-weight: 600;
      margin-bottom: 0.4rem;
      text-transform: capitalize;
    }
    .orchestration-box p {
      font-size: 0.85rem;
      color: var(--text-secondary);
      line-height: 1.55;
    }

    /* --- Footer --- */
    .footer {
      text-align: center;
      padding: 2rem 2rem 3rem;
      font-size: 0.7rem;
      color: var(--text-muted);
      font-family: 'Poppins', sans-serif;
    }

    /* --- Mobile --- */
    @media (max-width: 768px) {
      .header { padding: 2rem 1.25rem 2rem; }
      .header h1 { font-size: 1.35rem; }
      .header .goal { font-size: 0.88rem; }
      .section-nav { padding: 0 1rem; }
      .container { padding: 1.5rem 1.25rem 3rem; }
      .section { margin-bottom: 2.25rem; }

      .phase-flow {
        flex-direction: column;
        gap: 0;
      }
      .phase-arrow {
        justify-content: center;
        padding: 0.35rem 0;
        transform: rotate(90deg);
      }
      .phase-card { flex: none; }

      .agent-grid { grid-template-columns: 1fr; }
      .mode-grid { grid-template-columns: 1fr; }
    }

    @media (max-width: 480px) {
      .header { padding: 1.5rem 1rem 1.5rem; }
      .header h1 { font-size: 1.2rem; }
      .container { padding: 1.25rem 1rem 2.5rem; }
      .nav-link { font-size: 0.72rem; padding: 0.35rem 0.6rem; }
    }
  </style>
</head>
<body>
HTMLEOF

# --- Header ---
cat >> "$OUT" << HTMLEOF

<div class="header">
  <div class="header-inner">
    <h1>$(esc "$PROC_NAME")</h1>
    <div class="goal">$(esc "$PROC_GOAL")</div>
    <div class="meta">
      <span class="meta-tag">v$(esc "$PROC_VERSION")</span>
      <span class="meta-tag">$(esc "$PROC_ORCH")</span>
      <span class="meta-tag">${AGENT_COUNT} agents</span>
      <span class="meta-tag">${PHASE_COUNT} phases</span>
    </div>
  </div>
</div>

<nav class="section-nav">
  ${NAV_HTML}
</nav>

<div class="container">

  <div class="section" id="phases">
    <div class="section-header" onclick="toggleSection(this)">
      <span class="section-title">Phase Flow</span>
      <span class="section-toggle"><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6l4 4 4-4"/></svg></span>
    </div>
    <div class="section-body">
      <div class="phase-flow">
${PHASES_HTML}      </div>
    </div>
  </div>

  <div class="section" id="agents">
    <div class="section-header" onclick="toggleSection(this)">
      <span class="section-title">Agents</span>
      <span class="section-toggle"><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6l4 4 4-4"/></svg></span>
    </div>
    <div class="section-body">
      <div class="agent-grid">
${AGENTS_HTML}      </div>
    </div>
  </div>

  <div class="section" id="modes">
    <div class="section-header" onclick="toggleSection(this)">
      <span class="section-title">Modes</span>
      <span class="section-toggle"><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6l4 4 4-4"/></svg></span>
    </div>
    <div class="section-body">
      <div class="mode-grid">
${MODES_HTML}      </div>
    </div>
  </div>

  <div class="section" id="orchestration">
    <div class="section-header" onclick="toggleSection(this)">
      <span class="section-title">Orchestration Pattern</span>
      <span class="section-toggle"><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6l4 4 4-4"/></svg></span>
    </div>
    <div class="section-body">
      <div class="orchestration-box">
        <h3>$(esc "$(titlecase "$PROC_ORCH")")</h3>
        <p>$(esc "$ORCH_DESC")</p>
      </div>
    </div>
  </div>

</div>

<div class="footer">Generated from process definition</div>
HTMLEOF

cat >> "$OUT" << 'HTMLEOF'

<script>
function toggleSection(header) {
  header.closest('.section').classList.toggle('collapsed');
}

// Sticky nav: highlight active section
const sections = document.querySelectorAll('.section[id]');
const navLinks = document.querySelectorAll('.nav-link');

const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    const link = document.querySelector(`.nav-link[data-section="${entry.target.id}"]`);
    if (link) {
      if (entry.isIntersecting) link.classList.add('active');
      else link.classList.remove('active');
    }
  });
}, { rootMargin: `-${getComputedStyle(document.documentElement).getPropertyValue('--nav-height').trim()} 0px -40% 0px`, threshold: 0 });

sections.forEach(s => observer.observe(s));
</script>
</body>
</html>
HTMLEOF

echo "Generated: $OUT"
