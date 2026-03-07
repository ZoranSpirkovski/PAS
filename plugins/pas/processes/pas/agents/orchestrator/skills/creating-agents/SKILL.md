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

### 5. Generate the Agent

Run the generation script with all decisions from steps 1-4:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/pas-create-agent \
  --process {process-name} \
  --name {agent-name} \
  --description "{one-sentence role description}" \
  --model {model-id} \
  --tools "{comma-separated tool list}" \
  --identity "{2-3 sentences defining who this agent is}" \
  --behavior "{behavioral rule 1}" \
  --behavior "{behavioral rule 2}" \
  --deliverable "{what the agent produces}" \
  --role {orchestrator|specialist} \
  --base-dir {directory}
```

Repeatable flags: `--behavior` (required, at least one), `--deliverable` (required, at least one).

Optional: `--base-dir` sets the root directory for output (default: current directory).

When `--role orchestrator`, the script automatically:
- Merges required orchestrator tools (Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Agent, SendMessage, TeamCreate)
- Adds orchestrator-specific behavior (startup reads, gate management, shutdown sequence)

### 6. Create Agent Skills

For each skill determined in step 3, use `creating-skills/SKILL.md` to generate it. The agent's `skills/` directory was created by the generation script.
