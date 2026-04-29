---
name: add-skill
description: Use when creating a local skill for a pas-clief workspace — a callable capability that agents and processes invoke by name. Walks the user through naming, when-to-use, how-to-use, inputs, and outputs. The skill lands in `library/skills/<name>/`.
---

# pas-clief:add-skill

Goal: a new local skill in `<user-project>/library/skills/<name>/` that agents and processes can reference by name.

## Flow

### 1. Name and capability

Ask:
- "What is the skill's name? (Short, lowercase, hyphenated. Example: `web-research`, `polish-prose`, `summarize-thread`.)"
- "In one line, what capability does this skill provide?"

If the name collides with an existing skill, ask: replace / extend / rename?

### 2. Substance

Ask:
- "When should this skill be used? Describe the trigger condition."
- "How is it used? Walk me through the procedure step-by-step."
- "What inputs does it need?"
- "What outputs does it produce?"
- "Do you have an example invocation we can write down?"

### 3. Write the files

Create directory: `library/skills/<name>/`
Read template `plugins/pas-clief/templates/skill-md.md` and substitute placeholders. Write to `library/skills/<name>/SKILL.md`.
Read template `plugins/pas-clief/templates/changelog-md.md` and write to `library/skills/<name>/changelog.md` with an initial entry.
Create directory: `library/skills/<name>/feedback/` (empty).

### 4. Close

Tell the user:

> "Skill `<name>` is ready at `library/skills/<name>/`. Reference it from agents (in their `skills:` frontmatter) or processes (in their `skills:` frontmatter) by name. Search-order resolves to your local version automatically."

## Anti-patterns

- Don't write the skill without specific when-to-use criteria. Vague triggers cause Claude's skill router to misfire.
- Don't make a skill where a step in a phase file would do. Skills are reusable across many tasks; if it's only used in one process, it's a phase, not a skill.
