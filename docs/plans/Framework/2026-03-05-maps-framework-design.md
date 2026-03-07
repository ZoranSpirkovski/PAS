# MAPS Framework — Design (Future Evolution of PAS)

> Status: Idea stage. Not for implementation until PAS is proven in production.

## Summary

MAPS (Mission, Agents, Processes, Skills) is the planned evolution of the PAS framework into an open-source, domain-agnostic system for building agentic workplaces. Any business, any skill level.

## The Acronym

| Letter | Concept | Role | One-liner |
|---|---|---|---|
| **M** | Mission | WHY | The destination — what you're trying to achieve |
| **A** | Agents | WHO | The specialists — identities with skills who do the work |
| **P** | Processes | WHAT + WHEN | The route — phases in order, producing deliverables |
| **S** | Skills | HOW | The capabilities — composable techniques agents use |

**One sentence:** A Mission defines the goal, Agents are assigned work through Processes, and Agents use Skills to do it.

**Restaurant analogy:** Your *mission* is lunch service. Your *agents* are the chef, server, and host. Your *process* is: seat guests, take orders, cook, serve, clear. Their *skills* are cooking, order-taking, and table management.

## What MAPS Adds Over PAS

### Mission as a First-Class Concept

PAS has three layers: Process > Agent > Skill. MAPS adds a fourth layer above Process.

A **Mission** is a named goal that may require one or more Processes to achieve. It provides:

- **Goal statement**: What success looks like
- **Processes**: Which processes serve this mission
- **Shared config**: Settings that apply across all processes in the mission (e.g., publication config, brand guidelines)
- **Strategy**: High-level constraints or priorities that inform how processes execute

```yaml
# missions/crypto-news-net/mission.md

name: crypto-news-net
goal: Operate a professional crypto newsroom producing Reuters-level journalism
strategy: |
  Prioritize accuracy over speed. Build trust through sourcing transparency.
  Every article must pass fact-checking before publication.

processes:
  - article          # Produce news articles from source material
  - market-analysis  # Produce weekly market reports
  - social-calendar  # Plan and schedule social media content

shared_config:
  publication: crypto-news-net
  style: reuters-wire
```

### Why Mission Matters

Without Mission, processes are isolated. Each one has its own goal, but there's no place to express:

- Cross-process priorities ("articles take precedence over market reports when breaking news hits")
- Shared identity ("all content follows the same editorial standards")
- Strategic direction ("we're expanding into DeFi coverage this quarter")

Mission is where organizational intelligence lives.

### The Hierarchy

```
Mission (WHY)
  Process (WHAT + WHEN)
    Agent (WHO)
      Skill (HOW)
```

A user starts with their mission. MAPS helps them build processes, create agents, and compose skills to achieve it. The entry point `/maps` is a conversation:

```
User: /maps I want to run a crypto newsroom
MAPS: Let's define your mission. What does success look like?
      ...
MAPS: Based on your mission, I'd recommend starting with an article process.
      Let's create the agents and skills you'll need.
```

### Directory Structure (Projected)

```
missions/
  crypto-news-net/
    mission.md           # Mission definition
    config/              # Shared config across processes
processes/
  article/
    process.md           # References mission: crypto-news-net
  market-analysis/
    process.md
agents/                  # Agents are mission-independent (reusable)
library/                 # Skills are mission-independent (reusable)
```

Agents and Skills remain independent of missions — a researcher can serve multiple missions. Only Processes are scoped to a Mission.

## Open-Source Vision

### Target Users

1. **Non-technical operators**: Know their business, can describe what they want, need MAPS to build the system
2. **Technical builders**: Understand agents/skills, want a framework to organize their work
3. **Teams**: Multiple people using MAPS for different missions within one organization

### Design Principles for Open Source

- **Convention over configuration**: Sensible defaults for everything
- **Progressive complexity**: Start with one process, one agent, one skill. Add layers as needed.
- **Self-documenting**: The framework explains itself. `/maps` is the teacher.
- **Domain-agnostic**: Nothing in the framework assumes crypto, journalism, or any specific domain
- **Portable**: Skills and agents can be shared across projects and published as packages

### Onboarding Path

```
1. Install MAPS (Claude Code plugin)
2. /maps "I want to [describe goal]"
3. MAPS guides you through mission → process → agents → skills
4. First process runs in supervised mode
5. Feedback loop improves everything automatically
```

## Migration Path from PAS

PAS is MAPS without the Mission layer. Migration is additive:

1. Build and stabilize PAS (Process, Agent, Skill)
2. Add Mission as a concept when multi-process orchestration is needed
3. Rename entry points from `/pas` to `/maps`
4. Existing processes gain a `mission:` field pointing to their parent mission

No breaking changes. PAS processes without a mission continue to work — they're just standalone.

## When to Build MAPS

Prerequisites before evolving PAS to MAPS:

- [ ] PAS is stable and tested with the article pipeline
- [ ] At least one additional process exists (proves the framework is domain-flexible)
- [ ] Feedback loop is generating real improvements
- [ ] A second user has successfully used PAS (proves it's teachable)
- [ ] Cross-process coordination is actually needed (don't build Mission until it's felt)

## Key Decisions Deferred

- Mission file format (how much YAML vs prose)
- Cross-process agent feedback merging
- Mission-level dashboards or status tracking
- Package/plugin format for sharing skills and agents
- Multi-user / multi-mission coordination
