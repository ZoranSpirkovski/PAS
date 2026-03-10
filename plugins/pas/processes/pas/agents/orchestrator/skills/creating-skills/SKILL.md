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

- Check existing skills within the owning agent (`.pas/processes/{process}/agents/{agent}/skills/`)
- Check existing skills within the process (`.pas/processes/{process}/`)
- Check `.pas/library/` for global skills that already do this
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
  --common-mistake "{Known pitfall}" \
  --base-dir {directory}
```

Repeatable flags: `--step` (required, at least one), `--quality-check`, `--common-mistake`.

Optional: `--base-dir` sets the root directory for output (default: current directory).

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

If yes to either: move to `.pas/library/{skill-name}/` and reference from both locations. If no: keep it local. Skills start local and graduate to the library only when reuse is proven (used in 2+ places).
