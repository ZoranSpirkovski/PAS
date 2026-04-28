# Discovery Priorities — Cycle 6

## Directive

Product owner: "Create a method by which processes are visualized for users via HTML. Each process should get its own HTML that provides a high level overview of everything in a process in a visual way."

## Signal Analysis

- **Internal signals**: No feedback signals related to visualization. Clean slate.
- **GitHub issues**: No open issues. 0 external demand signals.
- **Conclusion**: This is purely directive-driven. No conflicting signals.

## Team Discussion Synthesis

### Framework Architect Assessment

- The PAS data model (process.md, agent.md, SKILL.md, modes, status.yaml) is structured YAML/markdown — straightforward to parse and render.
- Existing HTML infrastructure: `eval-viewer/viewer.html` provides a proven design aesthetic (Poppins/Lora fonts, warm color palette, card-based layout). We should reuse this design system.
- Implementation: A new skill that reads process definitions and generates a self-contained HTML file. No external dependencies.
- Location: `plugins/pas/library/visualize-process/SKILL.md` — library skill since any process can use it.
- The `/pas` entry point routes "visualize" requests to this skill.

### DX Specialist Assessment

- High onboarding value — new users see the full process structure before running it.
- Must show: phases (flow), agents (roster + capabilities), skills (per agent), modes, orchestration pattern.
- Progressive disclosure: overview at top, details below.
- Single self-contained HTML file — open in any browser, no server needed.
- Should generate to a predictable location: `{process-dir}/overview.html`

### Ecosystem Analyst Assessment

- No competing visualization tools in the Claude Code ecosystem.
- Self-contained HTML is the most portable format — works everywhere.
- Could reference Mermaid for diagrams but embedding SVG directly keeps it dependency-free.

### Feedback Analyst Assessment

- No existing signals to address. All priority budget goes to the directive.

### Community Manager Assessment

- No issues to link. PR will be a clean new feature addition.

## Approved Priorities

### P1: Create `visualize-process` library skill (HIGH)

A new library skill at `plugins/pas/library/visualize-process/SKILL.md` that:
1. Reads a process definition (process.md) and all its agents, skills, and modes
2. Generates a single self-contained HTML file with:
   - Process header (name, goal, version, orchestration pattern)
   - Phase flow visualization (sequential boxes with agents, I/O, gates)
   - Agent roster (cards with model, tools, skills)
   - Skill inventory (grouped by agent, with library skills highlighted)
   - Mode descriptions
   - Orchestration pattern summary
3. Uses the existing eval-viewer design aesthetic (Poppins/Lora, warm palette)
4. Outputs to `{process-dir}/overview.html`

### P2: Add `/pas` routing for visualization (LOW)

Update the `/pas` entry point SKILL.md to route visualization requests to the new skill.

## Scope

- P1 is the full deliverable for this cycle
- P2 is minimal routing update
- No status.yaml live dashboard (future cycle if needed)
- No workspace visualization (runtime data is cycle-specific, not process-structural)
