# PAS Generation Scripts Design

**Date:** 2026-03-07
**Scope:** Replace manual artifact creation with deterministic bash scripts

## Problem

The PAS orchestrator currently reads SKILL.md instructions and manually creates every file — process.md, agent.md, SKILL.md, changelog.md, feedback directories, mode files, thin launchers. This is slow, error-prone, and the LLM can drift from the spec. The same boilerplate structure is recreated from scratch every time.

## Solution

Three bash scripts that generate complete PAS artifacts from CLI arguments. The orchestrator makes the creative decisions (what to build), the scripts handle the mechanical work (building it right). Zero post-generation editing required.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Script language | Bash with heredocs | Zero dependencies, matches PAS conventions |
| Interface | CLI arguments | No spec files to clean up |
| Content handling | Full generation via CLI args | Zero post-generation editing |
| Composition | Orchestrator calls each script separately | Simpler scripts, more control |
| Script location | Co-located with the skill that uses them | Each script lives in its skill's `scripts/` directory |
| Skill changes | Skills become script guides | Creative workflow stays, mechanical work moves to scripts |
| Script count | Separate scripts per artifact | `pas-create-process`, `pas-create-agent`, `pas-create-skill` |

## Script Locations

```
plugins/pas/processes/pas/agents/orchestrator/skills/
  creating-processes/scripts/pas-create-process
  creating-agents/scripts/pas-create-agent
  creating-skills/scripts/pas-create-skill
```

---

## pas-create-process

**Purpose:** Generate a complete process directory with process.md, mode files, thin launcher, changelog, and feedback backlog.

### CLI Interface

```bash
pas-create-process \
  --name seo \
  --goal "Create SEO-optimized articles from topic briefs" \
  --orchestration hub-and-spoke \
  --phase "research:researcher:topic.md:research.md:Orchestrator reviews research quality" \
  --phase "writing:writer:research.md:draft.md:User approves draft" \
  --input "topic:A markdown file describing the article topic" \
  --description "Multi-phase content pipeline that researches, writes, and optimizes articles." \
  --sequential false
```

### Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--name` | Yes | Process slug (kebab-case) |
| `--goal` | Yes | One-sentence goal |
| `--orchestration` | Yes | Pattern: solo, hub-and-spoke, sequential-agents, discussion |
| `--phase` | Yes (1+) | Repeatable. Format: `name:agent:input:output:gate` |
| `--input` | Yes (1+) | Repeatable. Format: `name:description` |
| `--description` | No | Prose description for process.md body |
| `--sequential` | No | Default: false. Force linear execution |
| `--force` | No | Overwrite existing directory |

### Generated Files

```
processes/{name}/
  process.md              # YAML frontmatter + description + phase prose
  modes/
    supervised.md         # Standard supervised mode template
    autonomous.md         # Standard autonomous mode template
  references/             # For domain knowledge and source material
  feedback/
    backlog/.gitkeep
  changelog.md            # Initialized with v1.0 entry

.claude/skills/{name}/
  SKILL.md                # Thin launcher pointing to process.md
```

### Validation

- `--name` must be kebab-case
- `--orchestration` must be one of: solo, hub-and-spoke, sequential-agents, discussion
- Each `--phase` must have exactly 5 colon-separated fields
- Each `--input` must have exactly 2 colon-separated fields
- Target directory must not exist (unless `--force`)

---

## pas-create-agent

**Purpose:** Generate a complete agent directory with agent.md, skills directory, changelog, and feedback backlog within an existing process.

### CLI Interface

```bash
pas-create-agent \
  --process seo \
  --name researcher \
  --description "Researches topics using web search and produces structured research briefs" \
  --model claude-sonnet-4-6 \
  --tools "Read,Write,Edit,Bash,Grep,Glob,WebSearch,WebFetch" \
  --identity "A meticulous researcher who values accuracy over speed. Cross-references multiple sources and flags conflicting information." \
  --behavior "Always cite sources with URLs" \
  --behavior "Flag low-confidence claims explicitly" \
  --behavior "Produce structured output with sections, not narrative prose" \
  --deliverable "workspace/{slug}/research.md — Structured research brief" \
  --role specialist
```

### Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--process` | Yes | Parent process name |
| `--name` | Yes | Agent slug (kebab-case) |
| `--description` | Yes | One-sentence role description |
| `--model` | Yes | Model ID |
| `--tools` | Yes | Comma-separated tool list |
| `--identity` | Yes | 2-3 sentences defining who the agent is |
| `--behavior` | Yes (1+) | Repeatable. Behavioral rules |
| `--deliverable` | Yes (1+) | Repeatable. What the agent produces |
| `--role` | No | `orchestrator` or `specialist` (default: specialist) |
| `--force` | No | Overwrite existing directory |

### Generated Files

```
processes/{process}/agents/{name}/
  agent.md               # Full YAML frontmatter + identity + behavior + deliverables
  skills/                # Empty, ready for pas-create-skill
  references/            # For agent-level reference material
  feedback/
    backlog/.gitkeep
  changelog.md           # Initialized with v1.0 entry
```

### Orchestrator Role

When `--role orchestrator`, the script:
- Auto-adds required orchestrator tools: Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Agent, SendMessage, TeamCreate
- Includes orchestrator-specific behavior: reads process.md on startup, manages gates, updates status.yaml, handles shutdown sequence

---

## pas-create-skill

**Purpose:** Generate a complete skill directory with SKILL.md, changelog, and feedback backlog within an existing agent.

### CLI Interface

```bash
pas-create-skill \
  --process seo \
  --agent researcher \
  --name web-research \
  --description "Use when the agent needs to research a topic using web search and produce a structured research brief." \
  --overview "Systematic web research that prioritizes authoritative sources and cross-references claims across multiple results." \
  --when-to-use "When a research.md deliverable is required for a phase" \
  --when-not-to-use "When the agent already has sufficient context from reference material" \
  --step "Search for the topic using 3-5 varied queries" \
  --step "Cross-reference key claims across at least 2 sources" \
  --step "Compile findings into structured research.md" \
  --output-format "Markdown with sections: Summary, Key Findings, Sources, Confidence Notes" \
  --quality-check "Every claim has at least one source URL" \
  --quality-check "Conflicting information is explicitly flagged" \
  --common-mistake "Relying on a single source without cross-referencing"
```

### Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--process` | Yes | Parent process name |
| `--agent` | Yes | Parent agent name |
| `--name` | Yes | Skill slug (kebab-case) |
| `--description` | Yes | "Use when..." trigger description |
| `--overview` | Yes | Core principle in 1-2 sentences |
| `--when-to-use` | No | Specific trigger conditions |
| `--when-not-to-use` | No | When NOT to use this skill |
| `--step` | Yes (1+) | Repeatable. Process steps in order |
| `--output-format` | No | What the skill produces |
| `--quality-check` | No (0+) | Repeatable. Self-check criteria |
| `--common-mistake` | No (0+) | Repeatable. Known pitfalls |
| `--force` | No | Overwrite existing directory |

### Generated Files

```
processes/{process}/agents/{agent}/skills/{name}/
  SKILL.md               # Full Agent Skills spec format
  references/            # For progressive disclosure material
  feedback/
    backlog/.gitkeep
  changelog.md           # Initialized with v1.0 entry
```

---

## SKILL.md Changes

The three existing skills (creating-processes, creating-agents, creating-skills) get simplified from manual creation guides to script guides.

**What stays in the skills:**
- Creative decision steps (clarify goal, design phases, determine agents, select orchestration, prepare reference material, verify against source material)

**What moves to scripts:**
- Directory scaffolding
- File generation (process.md, agent.md, SKILL.md, mode files, thin launcher, changelog, feedback directories)

**New skill structure:**
1. Creative decision steps (unchanged)
2. "Generate" step — call the script with the decided parameters
3. Verification steps (unchanged)

The skills reference their scripts via `${CLAUDE_SKILL_DIR}/scripts/pas-create-*`.

---

## Error Handling

**All scripts share these behaviors:**

- Required flags checked on startup — clear error message listing missing flags
- `--name` validated as kebab-case (lowercase letters and hyphens only)
- Format validation on colon-separated fields (correct field count)
- `--orchestration` validated against known patterns
- `--model` validated against known model IDs
- Directory conflict: exits with error unless `--force` is set
- Each created file path printed as it's generated
- Exit codes: `0` success, `1` validation error, `2` filesystem error
- Final summary: `"Created {type} '{name}' with {N} files"`

---

## Orchestrator Workflow (After)

1. Brainstorm with user (creative decisions — unchanged)
2. Run `pas-create-process` to scaffold the process
3. Run `pas-create-agent` for each agent
4. Run `pas-create-skill` for each skill
5. Verify against source material (if applicable — unchanged)

## Version

This ships as part of PAS v1.2.0.
