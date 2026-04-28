---
name: visualize-process
description: Use when visualizing a process structure as HTML. Runs generate-overview.sh to produce a self-contained overview page.
---

# Process Visualization

Generate a self-contained HTML overview of a PAS process. Zero AI tokens — runs a bash script that parses process.md, agents, skills, and modes, then outputs a single HTML file.

## When to Use

- User asks to visualize, view, or generate an overview of a process
- User wants to understand a process structure before running it
- User is onboarding to an existing process and wants a map

## Process

1. Identify the target process directory (must contain `process.md`)
2. Run the script:

```bash
bash {path-to-this-skill}/generate-overview.sh <process-dir>
```

The script reads all YAML frontmatter from `process.md`, `agents/*/agent.md`, agent skills, and `modes/*.md`, then writes `<process-dir>/overview.html`.

3. Tell the user the output path so they can open it in a browser.

## What the HTML Shows

- **Header**: process name, goal, version, orchestration pattern, agent/phase counts
- **Phase Flow**: sequential cards with agents, pattern, output, and gate for each phase
- **Agent Roster**: cards with description, model badge, tool badges, and skill list (library skills highlighted in purple)
- **Modes**: side-by-side comparison with gate enforcement status
- **Orchestration**: pattern name and description

## Design System

Uses the PAS design aesthetic: Poppins/Lora fonts, warm palette (#faf9f5 bg, #d97757 accent, #141413 header). Self-contained — no external JS, only Google Fonts CSS.
