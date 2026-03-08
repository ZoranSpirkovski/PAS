---
name: visualize-process
description: Use when visualizing a process structure as HTML. Reads process.md, agents, skills, and modes to generate a self-contained overview page.
---

# Process Visualization

Generate a self-contained HTML file that provides a high-level visual overview of a PAS process. The output is a single file with embedded CSS — no build step, no external JS, opens in any browser.

## When to Use

- User asks to visualize, view, or generate an overview of a process
- User wants to understand a process structure before running it
- User is onboarding to an existing process and wants a map

## Process

1. **Identify the target process directory**. It must contain `process.md` at its root.

2. **Read the process definition**: parse `process.md` YAML frontmatter for:
   - `name`, `goal`, `version`, `orchestration`, `sequential`, `modes`
   - `phases` — each phase's `agent`, `pattern`, `input`, `output`, `gate`
   - `input` — process-level inputs

3. **Read all agents**: for each agent directory in `{process-dir}/agents/`:
   - Parse `agent.md` YAML frontmatter: `name`, `description`, `model`, `tools`, `skills`
   - Note which skills reference `library/` (library skills) vs local paths

4. **Read all skills**: for each skill listed in each agent's frontmatter:
   - Parse SKILL.md YAML: `name`, `description`
   - Classify as "library" (path contains `library/`) or "local"

5. **Read modes**: for each file in `{process-dir}/modes/`:
   - Parse YAML: `name`, `description`, `gates`

6. **Generate the HTML file** at `{process-dir}/overview.html` using the template below.

## HTML Template

Generate the HTML following this structure exactly. Replace all `{{placeholders}}` with actual data.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{process-name}} — Process Overview</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&family=Lora:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #faf9f5;
      --surface: #ffffff;
      --border: #e8e6dc;
      --text: #141413;
      --text-muted: #7a7870;
      --text-light: #b0aea5;
      --accent: #d97757;
      --accent-hover: #c4613f;
      --green: #788c5d;
      --green-bg: #eef2e8;
      --blue: #5b7fa6;
      --blue-bg: #eaf0f6;
      --purple: #8b6fa6;
      --purple-bg: #f0eaf6;
      --header-bg: #141413;
      --header-text: #faf9f5;
      --radius: 6px;
      --radius-lg: 10px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: 'Lora', Georgia, serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.6;
    }

    .header {
      background: var(--header-bg);
      color: var(--header-text);
      padding: 2rem 2.5rem;
    }
    .header h1 {
      font-family: 'Poppins', sans-serif;
      font-size: 1.75rem;
      font-weight: 600;
      margin-bottom: 0.5rem;
    }
    .header .goal {
      font-size: 1rem;
      opacity: 0.8;
      max-width: 700px;
    }
    .header .meta {
      display: flex;
      gap: 1.5rem;
      margin-top: 1rem;
      font-family: 'Poppins', sans-serif;
      font-size: 0.8rem;
      opacity: 0.6;
    }

    .container {
      max-width: 1100px;
      margin: 0 auto;
      padding: 2rem 2.5rem;
    }

    .section {
      margin-bottom: 2.5rem;
    }
    .section-title {
      font-family: 'Poppins', sans-serif;
      font-size: 1.1rem;
      font-weight: 600;
      color: var(--text);
      margin-bottom: 1rem;
      padding-bottom: 0.5rem;
      border-bottom: 2px solid var(--border);
    }

    /* Phase Flow */
    .phase-flow {
      display: flex;
      align-items: stretch;
      gap: 0;
      overflow-x: auto;
      padding: 1rem 0;
    }
    .phase-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      padding: 1.25rem;
      min-width: 200px;
      flex: 1;
      position: relative;
    }
    .phase-card h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.95rem;
      font-weight: 600;
      margin-bottom: 0.5rem;
      text-transform: capitalize;
    }
    .phase-card .phase-detail {
      font-size: 0.8rem;
      color: var(--text-muted);
      margin-bottom: 0.25rem;
    }
    .phase-card .phase-gate {
      font-size: 0.75rem;
      color: var(--accent);
      margin-top: 0.75rem;
      padding-top: 0.5rem;
      border-top: 1px solid var(--border);
      font-family: 'Poppins', sans-serif;
    }
    .phase-arrow {
      display: flex;
      align-items: center;
      padding: 0 0.5rem;
      color: var(--text-light);
      font-size: 1.5rem;
      flex-shrink: 0;
    }

    /* Agent Cards */
    .agent-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 1rem;
    }
    .agent-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      padding: 1.25rem;
    }
    .agent-card h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.95rem;
      font-weight: 600;
      margin-bottom: 0.25rem;
      text-transform: capitalize;
    }
    .agent-card .agent-desc {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin-bottom: 0.75rem;
    }
    .badge {
      display: inline-block;
      font-family: 'Poppins', sans-serif;
      font-size: 0.7rem;
      font-weight: 500;
      padding: 0.15rem 0.5rem;
      border-radius: 3px;
      margin-right: 0.35rem;
      margin-bottom: 0.25rem;
    }
    .badge-model {
      background: var(--blue-bg);
      color: var(--blue);
    }
    .badge-tool {
      background: var(--bg);
      color: var(--text-muted);
      border: 1px solid var(--border);
    }

    /* Skill List */
    .skill-list {
      margin-top: 0.75rem;
      padding-top: 0.5rem;
      border-top: 1px solid var(--border);
    }
    .skill-list-title {
      font-family: 'Poppins', sans-serif;
      font-size: 0.75rem;
      font-weight: 500;
      color: var(--text-light);
      margin-bottom: 0.35rem;
    }
    .skill-item {
      font-size: 0.8rem;
      padding: 0.2rem 0;
    }
    .skill-item .skill-name {
      font-weight: 500;
    }
    .skill-item.library .skill-name {
      color: var(--purple);
    }
    .skill-item .skill-desc {
      color: var(--text-muted);
      font-size: 0.75rem;
    }

    /* Modes */
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
    }
    .mode-card h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.95rem;
      font-weight: 600;
      margin-bottom: 0.25rem;
      text-transform: capitalize;
    }
    .mode-card .mode-desc {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin-bottom: 0.5rem;
    }
    .mode-card .mode-gates {
      font-family: 'Poppins', sans-serif;
      font-size: 0.75rem;
    }
    .gates-enforced { color: var(--accent); }
    .gates-advisory { color: var(--green); }

    /* Orchestration */
    .orchestration-box {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      padding: 1.5rem;
    }
    .orchestration-box h3 {
      font-family: 'Poppins', sans-serif;
      font-size: 0.95rem;
      font-weight: 600;
      margin-bottom: 0.5rem;
      text-transform: capitalize;
    }
    .orchestration-box p {
      font-size: 0.85rem;
      color: var(--text-muted);
    }

    /* Footer */
    .footer {
      text-align: center;
      padding: 2rem;
      font-size: 0.75rem;
      color: var(--text-light);
      font-family: 'Poppins', sans-serif;
    }
  </style>
</head>
<body>

<div class="header">
  <h1>{{process-name}}</h1>
  <div class="goal">{{goal}}</div>
  <div class="meta">
    <span>Version {{version}}</span>
    <span>{{orchestration}} orchestration</span>
    <span>{{agent-count}} agents</span>
    <span>{{phase-count}} phases</span>
  </div>
</div>

<div class="container">

  <!-- Phase Flow -->
  <div class="section">
    <div class="section-title">Phase Flow</div>
    <div class="phase-flow">
      <!-- Repeat for each phase, with arrows between them -->
      <div class="phase-card">
        <h3>{{phase-name}}</h3>
        <div class="phase-detail"><strong>Agents:</strong> {{agent-names}}</div>
        <div class="phase-detail"><strong>Pattern:</strong> {{pattern or "default"}}</div>
        <div class="phase-detail"><strong>Output:</strong> {{output-path}}</div>
        <div class="phase-gate">Gate: {{gate-description}}</div>
      </div>
      <div class="phase-arrow">→</div>
      <!-- ... next phase ... -->
    </div>
  </div>

  <!-- Agent Roster -->
  <div class="section">
    <div class="section-title">Agents</div>
    <div class="agent-grid">
      <!-- Repeat for each agent -->
      <div class="agent-card">
        <h3>{{agent-name}}</h3>
        <div class="agent-desc">{{agent-description}}</div>
        <div>
          <span class="badge badge-model">{{model}}</span>
          <!-- Repeat for each tool -->
          <span class="badge badge-tool">{{tool-name}}</span>
        </div>
        <div class="skill-list">
          <div class="skill-list-title">Skills</div>
          <!-- Repeat for each skill -->
          <div class="skill-item {{library-class}}">
            <span class="skill-name">{{skill-name}}</span>
            <span class="skill-desc">— {{skill-description}}</span>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Modes -->
  <div class="section">
    <div class="section-title">Modes</div>
    <div class="mode-grid">
      <!-- Repeat for each mode -->
      <div class="mode-card">
        <h3>{{mode-name}}</h3>
        <div class="mode-desc">{{mode-description}}</div>
        <div class="mode-gates {{gates-class}}">Gates: {{gates-value}}</div>
      </div>
    </div>
  </div>

  <!-- Orchestration -->
  <div class="section">
    <div class="section-title">Orchestration Pattern</div>
    <div class="orchestration-box">
      <h3>{{orchestration-pattern}}</h3>
      <p>{{orchestration-description}}</p>
    </div>
  </div>

</div>

<div class="footer">
  Generated from process definition
</div>

</body>
</html>
```

## Output

Write the generated HTML to `{process-dir}/overview.html`. Tell the user the file path so they can open it in a browser.

## Quality Checks

- HTML is valid and self-contained (no external JS)
- All process phases are represented in the phase flow
- All agents from the process are in the agent roster (including orchestrator if it has an agent.md)
- Each agent's skills are listed with library skills visually distinguished
- All modes are shown
- The phase flow order matches the order in process.md
- CSS uses the design tokens from `:root` — do not hardcode colors
