# PAS Framework

> **This is the official source repository for PAS.** All development happens here, and this is where users get the latest version.

**Process, Agent, Skill** - a modular framework for building agentic workflows with AI coding assistants.

PAS gives you composable primitives that can be created, tested, improved, and combined into any automated pipeline. Define a goal, and PAS creates the process, agents, and skills needed to achieve it. Feedback from each run improves the system over time.

## The Problem

Building complex AI workflows today means writing monolithic prompts that handle everything. When something breaks, you can't fix one thing without touching everything. There's no way to give feedback to a specific part of the pipeline, and nothing is reusable across projects.

## How PAS Solves It

Clean separation of responsibilities:

| Concept | Role | One-liner |
|---------|------|-----------|
| **Process** | WHY + WHAT + WHEN | The goal and the plan to achieve it |
| **Agent** | WHO | The specialist who does the work |
| **Skill** | HOW | The technique they use |

A Process assigns Agents work toward a goal, and Agents use Skills to do it. Each piece has its own feedback backlog and changelog, so improvements target exactly where the issue lives.

## Install

PAS is distributed as a [Claude Code plugin](https://code.claude.com/docs/en/plugins). Install it from the marketplace:

```
/plugin marketplace add ZoranSpirkovski/PAS
/plugin install pas@pas-framework
```

Once installed, use `/pas:pas` to create and manage processes, agents, and skills.

### Alternative: Local Development

Clone the repo and load the plugin directly:

```bash
git clone https://github.com/ZoranSpirkovski/PAS.git
claude --plugin-dir ./PAS/plugins/pas
```

## Quick Start

After installing, start a conversation with PAS:

```
/pas:pas I want to build a code review pipeline
```

PAS will ask clarifying questions (one at a time, brainstorming-style), then create:
- A process definition with phases, gates, and agent assignments
- Agents with identities, tools, and skills
- A thin launcher so you can run it with a slash command
- Library skills (orchestration patterns, self-evaluation, feedback routing)

On first use, PAS creates `.pas/config.yaml` and `.pas/workspace/` in your project root.

## Walkthrough

A full lifecycle example using the code review pipeline from Quick Start.

### 1. Create a Process

```
/pas:pas I want to build a code review pipeline
```

PAS asks clarifying questions — how many reviewers, what languages, which quality gates — then generates everything:

```
.pas/
  config.yaml
  workspace/
  processes/code-review/
    process.md              # Phases, agents, gates
    agents/
      orchestrator/         # Coordinates the pipeline
      reviewer/             # Reviews code changes
    modes/
      supervised.md
      autonomous.md
    feedback/backlog/
.claude/skills/code-review/
    SKILL.md                # Thin launcher — invoke with /code-review
```

`process.md` defines the phases (e.g., diff analysis, review, summary), the gates between them, and which agent handles each phase. Agents get identities, tools, and skills. The thin launcher in `.claude/skills/` lets you run the whole pipeline with a single slash command.

### 2. Run the Process

```
/code-review
```

The orchestrator reads `process.md`, creates a workspace instance at `.pas/workspace/code-review/{slug}/`, and executes each phase in order. Gates between phases enforce quality checks — a phase only advances when its gate criteria are met. The workspace tracks pipeline state in `status.yaml` so runs are resumable.

### 3. Feedback Loop

At shutdown, every agent writes self-evaluation signals:

- **PPU** — a workflow improvement (e.g., "check test coverage before style review")
- **OQI** — a quality issue in output (e.g., "missed edge case in error handling review")
- **GATE** — a change that should not be made (stability guard)
- **STA** — a behavior that must not regress (stability anchor)

Signals route automatically to the relevant artifact's `feedback/backlog/`. To review and apply them:

```
/pas:pas what feedback exists?
```

PAS shows accumulated signals grouped by artifact, then applies improvements directly — updating process definitions, agent instructions, or skill logic. Each run makes the pipeline better.

## Core Concepts

### Recursive Composition

PAS is a tree structure. Each layer can contain any other:

- **Process** can contain processes, agents, skills
- **Agent** can contain processes, skills
- **Skill** is the leaf node (instructions)

Feedback attaches to the exact level where an issue lives.

### Start Lean, Grow Through Feedback

PAS creates the minimum viable set. A simple task might need just an orchestrator with one skill. A complex pipeline gets specialist agents. More structure is added only when usage establishes the need.

### Orchestration Patterns

Four built-in patterns for coordinating agents:

| Pattern | When to Use |
|---------|-------------|
| **Solo** | Single agent, no delegation |
| **Hub-and-Spoke** | Central orchestrator delegates to specialists in parallel |
| **Sequential Agents** | One agent at a time, handoff between phases |
| **Discussion** | Multi-agent deliberation for decisions requiring consensus |

### Feedback System

Every agent writes self-evaluation signals at shutdown. Four signal types:

- **PPU** (Persistent Preference Update) - workflow improvements
- **OQI** (Output Quality Issue) - quality problems in deliverables
- **GATE** (Gate Evaluation) - review point observations
- **STA** (Stability Anchor) - behaviors that must not regress

Signals route automatically to artifact backlogs. Apply them with `/pas:pas what feedback exists?`

### Two-Tier Agent Lifecycle

- **Process agents** (TeamCreate): persistent for the full pipeline run, retain context for rich self-evaluation
- **Task helpers** (Agent tool): ephemeral fire-and-forget for subtasks

## What's in the Plugin

```
plugins/pas/
  skills/pas/SKILL.md              # /pas entry point with intelligent routing
  hooks/
    hooks.json                     # Hook configuration
    check-self-eval.sh             # Ensures agents write self-evaluation
    route-feedback.sh              # Routes feedback signals to artifact backlogs
  library/
    orchestration/                 # 4 patterns: solo, hub-and-spoke, sequential, discussion
    self-evaluation/               # Always-on feedback collection skill
    message-routing/               # Gate message classification skill
  processes/pas/                   # PAS self-management process
    agents/orchestrator/
      skills/
        creating-processes/        # Create new processes from goals
        creating-agents/           # Create agents within processes
        creating-skills/           # Create composable skills
        applying-feedback/         # Review and apply accumulated feedback
  pas-config.yaml                  # Framework configuration
```

## Conventions

- Every artifact (process, agent, skill) has `feedback/backlog/` and `changelog.md`
- Skills follow the [Agent Skills](https://agentskills.io) open standard (SKILL.md format)
- Workspace instances live at `workspace/{process}/{slug}/`
- Pipeline state tracked in `workspace/{process}/{slug}/status.yaml`
- Agents are always process-local (no shared agents across processes)
- Skills are local-first; only graduate to `library/` when reused in 2+ places

## Compatibility

PAS works with any AI coding assistant that supports the [Agent Skills](https://agentskills.io) standard. The plugin format and hooks are specific to Claude Code.

## License

MIT
