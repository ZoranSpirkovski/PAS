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

### 4. Write SKILL.md

Follow the Agent Skills spec format. SKILL.md must be under 500 lines.

```yaml
---
name: {skill-name-with-hyphens}
description: Use when {triggering conditions}. {What capability this provides.}
---

# {Skill Name}

## Overview

{Core principle in 1-2 sentences. What this skill does and why.}

## When to Use

{Specific triggering conditions. When NOT to use.}

## Process

{The actual instructions. Numbered steps for procedural skills, structured sections for reference skills.}

## Output Format

{What the skill produces. File format, structure, required sections.}

## Quality Checks

{How to verify the output is good. Specific criteria the agent should self-check.}

## Common Mistakes

{What goes wrong and how to fix it. Populated by feedback over time.}
```

**Key rules from the Agent Skills spec:**
- Description = when to use, NOT what it does. Start with "Use when..."
- Progressive disclosure: SKILL.md is the overview. Link to `references/` for heavy material.
- Concise: only add what Claude doesn't already know. Challenge each paragraph.
- Consistent terminology: pick one term, use it everywhere.

### 5. Scaffold Skill Directory

Create the minimal directory structure:

```
{skill-name}/
  SKILL.md
  feedback/
    backlog/
      .gitkeep
  changelog.md
```

Optional directories (create only when needed):
- `scripts/` — executable code the agent can run
- `references/` — docs the agent reads on demand (for progressive disclosure)
- `assets/` — templates, images, data files
- `evals/` — structured test cases

### 6. Create Skill Eval

Create `evals/evals.json` with test assertions:

```json
{
  "evals": [
    {
      "name": "{test-name}",
      "description": "{what this tests}",
      "input": "{sample input or reference to evals/files/}",
      "assertions": [
        "{expected behavior or output characteristic}"
      ]
    }
  ]
}
```

Evals verify the skill produces correct output given representative input. They are not unit tests. They describe expected behavior that can be checked by reading the output.

### 7. Library Graduation Check

After creating the skill, check if it should be in `library/` instead:

- Is this exact skill already used by another agent in a different process?
- Would a second process/agent benefit from this skill without modification?

If yes to either: move to `library/{skill-name}/` and reference from both locations. If no: keep it local. Skills start local and graduate to the library only when reuse is proven (used in 2+ places).
