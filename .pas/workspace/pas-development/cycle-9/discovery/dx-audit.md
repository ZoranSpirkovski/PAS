# DX Audit — Cycle 9

**Auditor:** dx-specialist
**Date:** 2026-03-08
**Method:** Full first-time user walkthrough of every file in `plugins/pas/`

---

## Onboarding Assessment

**Time to first process:** 30-60 minutes (if the user reads everything carefully and nothing goes wrong). More realistically: most users will stall before getting there.

**Overall verdict:** PAS has strong internal architecture but presents itself as if the reader already understands it. The gap between "install the plugin" and "create my first process" is vast and undocumented. A motivated developer can figure it out, but most will bounce.

---

## Critical Friction Points (Severity: HIGH)

### F1. No quickstart that actually quick-starts

**File:** `README.md` (lines 46-57)

The Quick Start section says:

```
/pas:pas I want to build a code review pipeline
```

This is the ONLY example. It does not explain:
- What happens next (PAS asks clarifying questions — how many? what kind?)
- What the output looks like (directory structure? a working process?)
- How long it takes
- What "brainstorming-style" means in practice
- What to do if it goes wrong

A user reading this has no mental model of the flow. They type the command and are in the dark about what to expect. Compare to any well-adopted CLI tool: they show the full input-output cycle, not just the first command.

**Suggestion:** Add a concrete end-to-end example showing the conversation flow (2-3 user turns, the generated output, and how to run the result). This is the single highest-impact DX improvement possible.

### F2. `/pas:pas` command syntax is unintuitive

**File:** `README.md` (line 34, 50)

The install says to use `/pas:pas`. Two problems:
1. The `plugin:skill` colon syntax is a Claude Code convention, not something users will know intuitively
2. The doubled name (`pas:pas`) reads like a stutter — it feels like a mistake

Users who don't already know Claude Code plugin conventions will not understand why they need to type `pas` twice. The README doesn't explain this at all.

**Suggestion:** Explain the `plugin:skill` format in one sentence near the install instructions. Consider whether the plugin could provide an alias so users can just type `/pas` instead of `/pas:pas`.

### F3. Install instructions reference marketplace that may not exist yet

**File:** `README.md` (lines 27-33)

```
/plugin marketplace add ZoranSpirkovski/PAS
/plugin install pas@pas-framework
```

These are two separate commands with no explanation of the difference. What does `marketplace add` do vs `plugin install`? Is the `@pas-framework` a version, a variant, a package name? A first-time user cannot tell.

The local development alternative (`claude --plugin-dir`) is clearer, but it's presented as secondary.

**Suggestion:** Lead with whichever install path actually works today. Add a one-line explanation of each command. If marketplace isn't live yet, don't present it as the primary path.

### F4. First-run detection is invisible to the user

**File:** `plugins/pas/skills/pas/SKILL.md` (lines 30-36)

First-Run Detection creates `pas-config.yaml`, `library/`, and `workspace/`. But the user never sees this described anywhere before it happens. The README doesn't mention it. When a user types `/pas:pas` for the first time, files appear in their project with no advance warning.

This is disorienting. Users like to know what a tool will do to their filesystem before it does it.

**Suggestion:** The README Quick Start should mention: "On first use, PAS creates a `pas-config.yaml`, `library/`, and `workspace/` directory in your project." One sentence, huge anxiety reduction.

---

## Significant Friction Points (Severity: MEDIUM)

### F5. Signal types are jargon-heavy and the acronyms don't match their meanings

**File:** `README.md` (lines 88-94), `plugins/pas/library/self-evaluation/SKILL.md`

The README expands the acronyms as:
- **PPU** = "Process/Pipeline Upgrade"
- **OQI** = "Output Quality Issue"
- **GATE** = "Gate Evaluation"
- **STA** = "Stability Anchor"

But in the actual self-evaluation skill, PPU is defined as "Persistent Preference Update" — a different expansion than what the README says. This is a factual inconsistency.

More broadly: four custom acronyms is a lot to absorb for a first-time user. These are internal feedback categories — users who are just trying to create their first process don't need to know about PPU vs OQI vs GATE vs STA. But they're presented prominently in the README as if they're core concepts.

**Suggestion:** Fix the inconsistency (PPU means different things in README vs SKILL.md). Move signal type details out of the README into a "Feedback System" reference doc. The README should say "agents write structured feedback at shutdown" and leave it at that.

### F6. "Crystal clarity principle" is undefined PAS jargon

**Files:** `plugins/pas/skills/pas/SKILL.md` (line 25), `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md` (line 22), `plugins/pas/processes/pas/process.md` (line 28)

This phrase is used in at least 3 files but never defined. A developer reading the skill files will encounter "Apply the crystal clarity principle" with no context. It seems to mean "ask questions until you're sure you understand" — but that should be stated explicitly rather than wrapped in framework terminology.

**Suggestion:** Replace "crystal clarity principle" with the actual instruction: "Never assume you understand — ask until the user confirms." The concept is fine; the branding adds nothing.

### F7. Workspace lifecycle is overwhelming for a first process

**Files:** All orchestration patterns (`hub-and-spoke.md`, `solo.md`, `discussion.md`, `sequential-agents.md`)

Every orchestration pattern mandates creating a deep workspace directory structure:
```
workspace/{process}/{slug}/discovery
workspace/{process}/{slug}/planning
workspace/{process}/{slug}/execution/changes
workspace/{process}/{slug}/validation
workspace/{process}/{slug}/feedback
```

Plus a `status.yaml` with specific format, lifecycle tasks, completion gates, session tracking, feedback enforcement hooks that block shutdown...

For someone creating their first process (e.g., "I want to summarize my meeting notes"), this is like being handed the cockpit controls of a 747 when you asked for a bicycle. The overhead-to-value ratio for simple processes is extremely high.

**Suggestion:** Solo pattern should have a lightweight mode for simple processes. Not every process needs session tracking, completion gates, and 5-directory workspace structures. Consider a "simple mode" where workspace tracking is optional and hooks don't block shutdown.

### F8. No error recovery documentation

**Files:** All hook scripts, all orchestration patterns

When things go wrong, users encounter:
- `SELF-EVALUATION MISSING` (from `check-self-eval.sh`)
- `COMPLETION GATE FAILED` (from `verify-completion-gate.sh`)
- `Cannot complete "Self-evaluation" task` (from `verify-task-completion.sh`)

These error messages are clear about what's wrong but give no context about WHY or what the user should do in plain terms. They reference paths like `library/self-evaluation/SKILL.md` and expect the user to know what self-evaluation means and how to write one.

For a first-time user who just wanted to create a code review pipeline, hitting "COMPLETION GATE FAILED" and being told to write self-evaluation is bewildering.

**Suggestion:** Add a "Troubleshooting" section to the README with common error messages and what to do. For first-time users, consider whether the self-evaluation hooks should be softer (warn instead of block) until the user opts into strict enforcement.

### F9. Two-tier agent lifecycle is mentioned in README but never explained

**File:** `README.md` (lines 98-101)

The README has a section "Two-Tier Agent Lifecycle" that mentions TeamCreate vs Agent tool. This is an implementation detail that a first-time user has zero use for. It's framework internals presented as a core concept.

**Suggestion:** Remove from README. This belongs in the orchestration pattern docs (where it's already documented).

### F10. "Recursive Composition" section is misleading

**File:** `README.md` (lines 60-69)

"Process can contain processes, agents, skills. Agent can contain processes, skills."

In practice, the plugin doesn't demonstrate or support nested processes beyond a theoretical mention. The creating-processes skill generates flat processes. No example shows a process containing another process. Presenting this as a core concept sets expectations the tool can't deliver.

**Suggestion:** Either demonstrate recursive composition with a real example, or remove this claim from the README. State what PAS actually does, not what it theoretically could do.

---

## Documentation Gaps (Severity: MEDIUM)

### G1. No concept of "what is a process" for non-PAS users

The README jumps straight to the Process/Agent/Skill table but never answers the foundational question: "What would I use this for?" Real examples are missing. The code review pipeline is mentioned once and never shown.

**Suggestion:** Add 3-4 concrete examples: "Use PAS to build a code review pipeline, a content publishing workflow, a research-and-summarize tool, or a multi-step deployment checker." Each with one sentence describing what it does.

### G2. No documentation on how to run a created process

After PAS creates a process, how does the user run it? The creating-processes skill mentions "thin launcher" (step 6) but doesn't explain what that is or how to use it. The SKILL.md routing table mentions "Running a process: point to thin launcher (e.g., `/article`)" — but what does that mean? How does a thin launcher work? Where is it?

**Suggestion:** Explain the thin launcher concept in the README or Quick Start. Show what `/article` looks like and how it maps to the process.

### G3. Mode selection (supervised vs autonomous) is undiscoverable

**Files:** `plugins/pas/processes/pas/modes/supervised.md`, `autonomous.md`

Two modes exist. Neither the README nor the SKILL.md explains how to choose between them or how to switch. A user creating a process won't know they can choose.

**Suggestion:** Mention modes in the Quick Start. "By default PAS asks for approval at each step (supervised). You can switch to autonomous mode to let it run without pauses."

### G4. `pas-config.yaml` is never explained

**File:** `plugins/pas/pas-config.yaml`

The config has exactly two fields (`feedback: enabled`, `feedback_disabled_at: ~`). The README mentions it once indirectly. What other config options might exist? Can the user customize behavior? What does disabling feedback do exactly?

**Suggestion:** Document config in the README or a reference doc. Even just "PAS has one config option: `feedback`. Set to `disabled` to skip self-evaluation and feedback collection."

---

## Naming Issues (Severity: LOW-MEDIUM)

### N1. "Slug" is used everywhere but never defined

**Files:** All orchestration patterns, status tracking, workspace paths

`workspace/{process}/{slug}/` — what is the slug? Where does it come from? Who creates it? The creating-processes skill doesn't mention slug. The orchestration patterns assume it exists. Is it a timestamp? A user-provided name? Auto-generated?

**Suggestion:** Define "slug" in one place and reference it. Something like: "The slug is a short identifier for this run, generated from the date and goal (e.g., `2026-03-08-code-review`)."

### N2. "Gate" means two different things

In process.md phases, a "gate" is a review checkpoint. In the feedback system, "GATE" is a signal type meaning "stability gate — change that should NOT be implemented." Using the same word for two different concepts is confusing.

**Suggestion:** Rename the GATE signal type to something like "REJECT" or "BLOCK" to distinguish it from phase gates.

### N3. "Library" vs "Skills" vs "Process Skills" — the namespace is unclear

Skills live in three places:
1. `library/` — global, reusable
2. `processes/{name}/agents/{agent}/skills/` — agent-local
3. `plugins/pas/skills/pas/` — the entry point skill

For a new user, "skill" means different things depending on context. The `library/` name doesn't communicate "shared skills."

**Suggestion:** This is architectural and hard to change, but documentation should have a clear diagram showing where skills live and why. A one-paragraph "Where Things Live" section in the README would help.

---

## Quick Wins (High Impact, Low Effort)

1. **Add an end-to-end example to README** showing 3-4 turns of conversation with PAS and the resulting directory structure. (~30 min effort, transforms the onboarding experience)

2. **Fix PPU acronym inconsistency** between README and self-evaluation SKILL.md. (~2 min effort, prevents trust erosion)

3. **Add filesystem warning to Quick Start**: "PAS will create `pas-config.yaml`, `library/`, and `workspace/` in your project on first use." (~1 min effort, prevents surprise)

4. **Replace "crystal clarity principle" with the actual instruction** in all 3 files. (~5 min effort, removes unnecessary jargon)

5. **Add a Troubleshooting section to README** with the 3 hook error messages and plain-language fixes. (~15 min effort, prevents user abandonment when things go wrong)

6. **Remove Two-Tier Agent Lifecycle section from README**. (~1 min effort, reduces cognitive load)

7. **Define "slug" once in the orchestration SKILL.md** and link to it. (~3 min effort, resolves a pervasive naming gap)

---

## Deeper Structural Improvements (High Impact, Higher Effort)

1. **Lightweight process mode**: A "simple" or "minimal" option for solo-pattern processes that skips workspace, status tracking, and completion gates. Users creating their first process should not need to understand the full lifecycle. The overhead should scale with the complexity of the process, not be a fixed cost.

2. **Interactive tutorial**: A `/pas:pas tutorial` command that walks through creating a tiny process (3 phases, solo pattern, ~5 min). Shows every step, explains every concept as it appears. This replaces documentation with experience.

3. **Process templates**: Pre-built processes for common use cases (code review, content pipeline, research summarizer). Users can `fork` a template and customize it instead of starting from scratch. Dramatically lowers the "blank page" barrier.

4. **Progressive disclosure of feedback system**: First-time users should not encounter feedback signals, self-evaluation, or completion gates. These should activate after the user has created and run at least one process successfully. The current design front-loads the full lifecycle machinery on every process regardless of complexity.

---

## Summary

PAS is architecturally sound and internally consistent. The feedback system, orchestration patterns, and skill composition model are well-designed. The problem is not what PAS does — it's how PAS presents itself.

The framework assumes its user already understands Process-Agent-Skill thinking, knows Claude Code plugin conventions, and is comfortable with a significant workspace lifecycle overhead. None of these assumptions hold for a first-time user.

The highest-leverage improvements are all in the first 5 minutes of user experience: a real end-to-end example, filesystem warnings, jargon removal, and a lightweight path for simple processes. These don't require architectural changes — just better framing of what already exists.
