# DX Specialist Assessment -- Cycle 4 Discovery

## 1. First-Run Experience

**Rating: Functional but confusing for newcomers**

The install path in the README is clear -- two commands, marketplace add then plugin install. But what happens next is where friction begins.

The `/pas:pas` entry point has a "First-Run Detection" mechanism that creates `pas-config.yaml`, `library/`, and `workspace/` automatically. This is good -- the user does not have to set anything up manually. But the user has no idea this will happen, and it is not explained in the README. The Quick Start section says "start a conversation with `/pas:pas`" but does not mention the initialization step or what files it creates.

**Key gap**: There is no "what just happened?" explanation after first-run setup. The user sees "PAS initialized -- library, workspace, and config are ready" but does not know what those things are or why they matter. A new user seeing `library/orchestration/`, `library/self-evaluation/`, and `library/message-routing/` appear in their project has no context for what these directories contain or whether they should care.

**The install command itself is unintuitive**: `/plugin install pas@pas-framework` requires the user to know the plugin name (`pas`) and the marketplace package name (`pas-framework`). The `@` syntax is not self-explanatory. A user who just ran the marketplace add command has to somehow know this second invocation format.

## 2. Skill Discoverability

**Rating: Poor for new users, adequate for returning users**

The `/pas:pas` entry point is the single command users interact with. The Quick Routing section inside SKILL.md maps user intent to internal skills, which is a solid pattern -- users speak in goals ("I want to create a pipeline"), not PAS jargon ("invoke creating-processes").

However, there is **no way for a user to discover what PAS can do**. If I type `/pas:pas` without a clear goal, the SKILL.md does not define a "help" or "what can you do?" path. The "Information query" routing says to "survey processes/, library/, workspace/" -- but a first-time user has no processes, an auto-generated library, and an empty workspace. There is nothing to survey.

**The marketplace catalog** (`marketplace.json`) lists exactly one plugin with a generic description. It gives no indication of the specific capabilities (create processes, apply feedback, create hooks). A user browsing the marketplace sees "Framework for building agentic workflows" and has to guess whether this does what they need.

**Internal skills are invisible to users** by design -- `creating-processes`, `creating-agents`, `creating-skills`, `applying-feedback`, `creating-hooks` are all described as "not directly by users" in their descriptions. This is correct architecturally but means there is no skill catalog a user can browse. The routing in SKILL.md is the entire discoverability surface, and it only works if the user's phrasing happens to match one of six routing patterns.

## 3. Documentation Gaps

**Rating: Significant gaps for onboarding, good for internals**

What exists is well-written. The README covers concepts, install, quick start, plugin structure, conventions. The CHANGELOG is detailed and useful for tracking evolution. The internal skill files are thorough.

What is missing:

- **No tutorial or walkthrough**: The Quick Start shows one command and says "PAS will ask clarifying questions." There is no example of what that conversation looks like. A user does not know what kind of questions PAS asks, how long the process takes, or what the output looks like. A single end-to-end example (goal -> questions -> generated artifacts) would be transformative.
- **No concept glossary targeted at new users**: The README introduces Process, Agent, Skill, then immediately adds Orchestration Patterns, Feedback System, Two-Tier Agent Lifecycle, signal types (PPU, OQI, GATE, STA). That is 10+ concepts before the user has created anything. Progressive disclosure is violated.
- **No "what PAS created" guide**: After running `/pas:pas`, the user has a process directory full of files (process.md, modes/, agents/, skills/, feedback/, references/, changelog.md, a thin launcher). None of these files explain themselves to the user. There is no "anatomy of a process" doc.
- **No troubleshooting section**: What if hooks fail? What if self-evaluation blocks a session? What if feedback routing breaks? The CHANGELOG describes fixes for these exact issues (v1.3.0), confirming they happen in practice, but there is no user-facing troubleshooting guide.
- **Hooks are invisible**: The README says "Hooks auto-discovery" but never explains what hooks do to the user's workflow. A user who gets blocked by `check-self-eval.sh` or `verify-completion-gate.sh` has no context for why their session cannot end.

## 4. Generation Script UX

**Rating: Good for the orchestrator, irrelevant to end users**

The three scripts (`pas-create-process`, `pas-create-agent`, `pas-create-skill`) are well-built:
- Clear `usage()` output with required/optional flags documented
- Good validation: kebab-case enforcement, colon-separated field count checks, valid model/pattern validation
- Helpful error messages that name the specific missing or invalid flag
- `--force` flag for overwrite safety
- Consistent output showing each file created

These scripts are called by the orchestrator during process creation, not by users directly. This is appropriate -- the scripts are mechanical plumbing. But there are friction points even for the orchestrator:

- **The `--phase` format is opaque**: `"name:agent:input:output:gate"` with exactly 5 colon-separated fields. If any field contains a colon (common in descriptions like "user-approved output: final draft"), parsing breaks silently or with a confusing field count error.
- **No `--base-dir` in usage output**: The CHANGELOG (v1.3.0) mentions all three scripts support `--base-dir` for test isolation, but the `usage()` functions in the actual scripts do not list it. (I did not see `--base-dir` handling in the scripts I read -- it may have been lost or is undocumented.)
- **No dry-run mode**: There is no `--dry-run` flag to preview what would be created. For the orchestrator this is fine, but if users ever invoke scripts directly (for debugging or customization), this would help.

## 5. Configuration Clarity

**Rating: Minimal but functional**

`pas-config.yaml` contains exactly two fields:

```yaml
feedback: enabled
feedback_disabled_at: ~
```

This is extremely simple -- which is both a strength (nothing to misconfigure) and a weakness (what else can I configure?). There is no comment in the file explaining what these fields do. There is no documentation for what happens when feedback is disabled. The SKILL.md mentions "Frustration Detection" -- if feedback is disabled and the user seems frustrated, offer to re-enable -- but this behavior is not documented anywhere the user would find it.

**Missing configuration options that users might expect:**
- Default orchestration pattern
- Default model tier
- Workspace location override
- Hook verbosity / debug mode
- Whether to auto-commit after process creation

The extreme simplicity is appropriate for v1.x, but the file should at minimum have comments explaining its fields.

## 6. Ergonomic Friction

**Friction point 1: The namespace prefix**. Users must type `/pas:pas` -- the plugin name repeated as the skill name. This reads oddly and does not communicate what it does. If a user has multiple plugins, they see `/pas:pas` in their skill list alongside presumably more descriptive names.

**Friction point 2: Invisible feedback system**. The feedback system (self-evaluation, signal routing, completion gates) is the most complex part of PAS, and it runs entirely behind the scenes via hooks. Users will encounter blocking behavior (cannot stop a session, cannot complete a task) without understanding why. The `pas-session-start.sh` hook injects lifecycle context at session start, but this context is injected into the agent's prompt -- the user never sees it.

**Friction point 3: Terminology overload**. The framework uses PPU, OQI, GATE, STA signal types. These abbreviations are never defined in user-facing documentation (only in internal skill files). A user seeing these in feedback files has no reference for what they mean. The README mentions them once in a bullet list but the full names are only there -- nowhere else explains them.

**Friction point 4: No escape hatch**. If a user creates a process with PAS and something is wrong, the path to fix it is either "apply feedback" (a multi-step workflow) or manually edit files. There is no quick "edit this process" or "delete this process" command. The SKILL.md routing says "Modifying existing: read the target artifact, then use creation skills" -- which means re-running the creation workflow for a minor change.

**Friction point 5: Library bootstrap is silent and magical**. When PAS copies skills from the plugin's `library/` to the user's project `library/`, the user did not ask for this and may not understand why files appeared in their project. If they delete them (thinking they are generated artifacts they do not need), things break.

## 7. Priority Recommendation

**Highest impact DX improvement: Create a guided first-run walkthrough with a concrete end-to-end example.**

Specifically:

1. After first-run initialization, instead of just "PAS initialized", show a brief orientation: what was created, what each directory is for, and what to do next.

2. Add a "Tutorial" section to the README (or a linked doc) that walks through creating a simple 1-agent process end-to-end: the user's goal, each question PAS asks, the generated files, and how to run the result. Include the actual terminal output. This single addition would make the difference between "I installed this and don't know what to do" and "I see how this works."

3. As a secondary priority: add inline comments to `pas-config.yaml` and a brief "What PAS Does to Your Project" section in the README explaining the library/, workspace/, and hooks behavior so users are not surprised by files appearing or sessions being blocked.

The core framework is well-designed. The problem is not capability -- it is legibility. A new user cannot see what PAS can do, cannot predict what PAS will do, and cannot understand what PAS did. Fixing the onboarding narrative fixes most of the friction.
