# Implementation Plan — Cycle 6: Process Visualization

## Overview

Create a library skill that generates self-contained HTML visualizations from PAS process definitions. Each process gets a single HTML file showing its structure: phases, agents, skills, modes, and orchestration pattern.

## Tasks

### T1: Create `visualize-process` library skill (P1)

**Files:**
- NEW: `plugins/pas/library/visualize-process/SKILL.md`
- NEW: `plugins/pas/library/visualize-process/changelog.md`

**Scope:**
The skill instructs the agent to:
1. Read `process.md` and parse YAML frontmatter (name, goal, version, orchestration, phases, modes)
2. Read each `agents/{name}/agent.md` for agent metadata (name, description, model, tools, skills)
3. Read each skill's SKILL.md for name + description
4. Read each `modes/{name}.md` for mode metadata
5. Generate a self-contained HTML file at `{process-dir}/overview.html`

**HTML sections:**
- **Header**: Process name, goal, version, orchestration pattern
- **Phase Flow**: Visual pipeline of phases as connected cards (name, agents, pattern, gate)
- **Agent Roster**: Card grid with name, description, model badge, tool list, skill list
- **Skill Inventory**: Grouped by agent, library skills visually distinguished
- **Modes**: Side-by-side comparison of available modes
- **Orchestration**: Brief description of the active pattern

**Design system** (from eval-viewer):
- CSS custom properties: `--bg: #faf9f5`, `--surface: #fff`, `--border: #e8e6dc`, `--text: #141413`, `--accent: #d97757`
- Fonts: Poppins (headers), Lora (body)
- Cards with `border-radius: 6px`, subtle borders
- Dark header bar
- Responsive flexbox layout

### T2: Update `/pas` routing (P2)

**File:**
- EDIT: `plugins/pas/skills/pas/SKILL.md`

**Change:**
Add routing entry: "Visualizing a process" (visualize, overview, view, HTML) → read `library/visualize-process/SKILL.md`

### T3: Mirror to local library (dev-only, no PR)

**File:**
- COPY: `plugins/pas/library/visualize-process/` → `library/visualize-process/`

This is a dev-only artifact committed directly to dev, not included in the PR.

## Execution Order

- T1 and T2 are independent, can run in parallel
- T3 depends on T1 completion (needs the source to copy)

## Verification Checklist

- [ ] SKILL.md follows Agent Skills spec (YAML frontmatter + progressive disclosure)
- [ ] changelog.md exists with initial entry
- [ ] HTML template uses eval-viewer design tokens exactly
- [ ] Routing added to /pas SKILL.md
- [ ] Library mirror matches plugin source
- [ ] Generated HTML is self-contained (no external JS dependencies, only Google Fonts CSS)
