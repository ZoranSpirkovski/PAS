---
name: creating-agents
description: Use when creating or editing an agent within a PAS process. Usually invoked by creating-processes, not directly by users.
---

# Creating Agents

Create an agent definition within a process. Agents are specialists with identities, tools, and skills. They are always process-local. Every process has an orchestrator agent responsible for its success.

## Workflow

### 1. Determine Role

Define the agent's purpose within the process:

- **Name**: short, descriptive (e.g., `researcher`, `fact-checker`, `orchestrator`)
- **Description**: one sentence explaining what this agent does
- **Role type**: orchestrator (manages process) or specialist (handles specific phases)
- **Tools needed**: select from available Claude Code tools based on what the agent needs to do

### 2. Check for Overlap

Before creating a new agent, check existing agents in `processes/{process}/agents/`:

- Would an existing agent's skills cover this role?
- Could an existing agent be extended instead of creating a new one?
- Is there an agent in another process that could serve as inspiration? (Copy, don't share. Agents are always process-local.)

### 3. Determine Skills

For each skill the agent needs:

- Read `creating-skills/SKILL.md` from the same skills directory as this skill
- Follow its workflow to create each skill
- Skills live inside the agent's directory at `skills/{skill-name}/SKILL.md`
- Check `library/` for global skills the agent should carry (e.g., `library/self-evaluation/SKILL.md`)

### 4. Select Model Tier

Match model capability to role complexity:

| Tier | Model | Use When |
|------|-------|----------|
| Opus | claude-opus-4-6 | Orchestration, complex writing, editorial judgment, multi-step reasoning |
| Sonnet | claude-sonnet-4-6 | Research, fact-checking, structured analysis, code generation |
| Haiku | claude-haiku-4-5 | Simple extraction, formatting, classification, single-skill tasks |

Default to Sonnet for specialists, Opus for orchestrators. Downgrade when feedback shows a simpler model performs equally well.

### 5. Write agent.md

Use this exact format:

```yaml
---
name: {agent-name}
description: {one-sentence role description}
model: {model-id}
tools: [{tool-list}]
skills:
  - skills/{skill-name}/SKILL.md
  - library/self-evaluation/SKILL.md  # When feedback is enabled
---

# {Agent Name}

## Identity

{2-3 sentences defining who this agent is. Personality, expertise, working style.}

## Behavior

- {Behavioral rule 1}
- {Behavioral rule 2}
- {Rule N}

## Deliverables

- {What this agent produces, with file paths relative to workspace}

## Known Pitfalls

(Populated by feedback over time)
- {Known issue 1, if any from legacy experience}
```

### 6. Scaffold Agent Directory

Create the directory structure:

```
processes/{process}/agents/{name}/
  agent.md
  skills/
    {skill-1}/
      SKILL.md
      feedback/backlog/
      changelog.md
    {skill-N}/
  feedback/
    backlog/
  changelog.md
```

### 7. Create Agent Eval

Create a representative test scenario that verifies:

- Agent can read its own agent.md and skills
- Agent produces expected deliverables given sample input
- Agent follows behavioral rules from its definition
- Output quality meets baseline expectations

## Orchestrator-Specific Requirements

When the agent role is **orchestrator**, apply these additional rules:

**Required tools:** Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Agent, SendMessage, TeamCreate

**Required behavior:**
- Reads `processes/{process}/process.md` on startup
- Reads the orchestration pattern from `library/orchestration/` as declared in process.md
- Reads workspace status to determine where to resume
- Handles phases directly using its own skills (e.g., sourcing, editorial-review)
- Delegates phases to specialist agents via TeamCreate
- Interfaces with the user at gates (supervised mode)
- Updates workspace status.yaml continuously
- Carries `library/self-evaluation/SKILL.md` when feedback is enabled
- Carries `library/message-routing/SKILL.md` for classifying user messages at gates
- Monitors agents for hangs using historical duration data
- Manages the shutdown sequence (downstream feedback, self-eval, finalize status)
