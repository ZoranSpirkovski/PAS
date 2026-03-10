# DX Assessment — Cycle 8: 12-Month Roadmap Perspective

## The Core DX Question

What would make someone *choose* PAS over just writing Claude Code instructions manually?

Right now, the honest answer is: PAS is impressive infrastructure that only its creator can use. Not because it is bad, but because the path from "I installed the plugin" to "I created my first useful process" does not exist as a guided experience. Everything between those two points requires reading source code, inferring conventions, and hoping you guess correctly.

A 12-month roadmap must close this gap. Everything below is framed through that lens.

---

## 1. The Onboarding Path Today

### What happens when someone installs PAS

1. They install the Claude Code plugin (marketplace or manual)
2. They type `/pas` for the first time
3. The SKILL.md router activates, detects no `pas-config.yaml`, runs first-run setup
4. Three directories appear: `library/`, `workspace/`, and `pas-config.yaml`
5. The system says "PAS initialized" and enters brainstorming mode

**Time to first process: unknown, because step 6 does not exist.**

After initialization, the user faces a blank canvas with zero guidance. The brainstorming conversation is well-designed (one question at a time, crystal clarity principle), but the user has to know what they want. There is no "try this example first" moment. No tutorial. No `/pas quickstart`. No sample process they can run and then study.

### What the user needs to know (that nobody tells them)

- What a "process" is in PAS terms (phases, gates, inputs/outputs)
- That agents are process-local, not shared
- That skills follow a specific SKILL.md format
- That orchestration patterns exist and affect how their process runs
- That feedback/self-evaluation is a core mechanism, not optional decoration
- Where output goes (workspace directories)
- How to run a process they created (thin launchers, slash commands)

All of this information exists. It lives in SKILL.md files, orchestration patterns, and agent definitions. But it is organized for the *framework developer*, not the *framework user*. The information architecture is inside-out: implementation details are easy to find, conceptual overview is not.

### Estimated time to first useful process (today)

For a developer familiar with Claude Code but new to PAS: 30-60 minutes of reading before they could even describe what they want to build. Another 30-60 minutes of back-and-forth with `/pas` to create it. Total: 1-2 hours, with significant risk of confusion.

For comparison, the target should be: 5 minutes to run an example, 15 minutes to create a simple custom process.

---

## 2. Documentation Gaps

### Well-documented (framework-developer perspective)
- Orchestration patterns: the decision matrix is clear, each pattern has detailed rules
- Skill creation: the creating-skills workflow is thorough with the Agent Skills spec
- Feedback system: self-evaluation signal types, routing, the full lifecycle
- Hook creation: event catalog, schema, script patterns — comprehensive reference material
- Status tracking: YAML format, valid states, session tracking

### Poorly documented (user perspective)
- **No conceptual overview**: What is PAS? What problems does it solve? When should you use it vs. not? There is no document that answers these questions.
- **No "getting started" guide**: The path from installation to first process is undocumented.
- **No examples**: Zero example processes ship with the plugin. The user cannot study a working process to understand the pattern.
- **No API-level docs for /pas**: What can you say to `/pas`? The routing table exists in the SKILL.md but is phrased as implementation routing, not user-facing capability documentation.
- **No glossary**: Terms like "gate," "phase," "slug," "thin launcher," "library graduation" are used without introduction.
- **No troubleshooting guide**: What if a hook fails? What if feedback routing goes wrong? What if a process gets stuck mid-session?
- **No "process patterns" cookbook**: Real-world examples of when to use solo vs. hub-and-spoke vs. discussion. The decision matrix exists but is abstract.

### The information architecture problem

PAS documentation is *reference material without tutorial material*. The SKILL.md files are well-written reference docs that tell you exactly what to do *once you already understand the system*. But there is nothing that teaches you the system. This is like shipping a programming language with a spec but no tutorial.

---

## 3. DX Friction Points

### Things that are hard today that should be easy

| Task | Current experience | Target experience |
|------|-------------------|-------------------|
| Create first process | Read 5+ skill files, understand patterns, brainstorm from scratch | `/pas quickstart` or `/pas create --template simple-pipeline` |
| Understand a process | Read process.md + agent files + skill files manually | `/pas visualize my-process` (exists!) but not discoverable |
| See what is happening mid-process | Read status.yaml manually | `/pas status` with human-readable output |
| Debug a failed process | Read workspace files, hook logs, feedback directories | `/pas debug` with guided investigation |
| Modify an existing process | Know which files to edit and what format they need | `/pas modify my-process "add a review step"` |
| Share a process | Copy directories and hope | `/pas export` / `/pas import` |
| See all my processes | `ls processes/` | `/pas list` with descriptions |
| Run a process | Remember the slash command name | `/pas run my-process` as a universal runner |

### The "too many steps" problem

Creating a process today requires:
1. Understand the process concept
2. Understand orchestration patterns
3. Design phases with I/O
4. Determine agents
5. Select orchestration pattern
6. Run `pas-create-process` script
7. Create each agent with `pas-create-agent` script
8. Create each skill with `pas-create-skill` script
9. Optionally create hooks

Steps 1-5 happen in conversation (good). Steps 6-8 are sequential bash scripts that must be run in the right order (friction). The scripts exist and work, but the multi-step creation process feels like assembly, not creation.

### Process observability

Once a process is running, the user's only window into what is happening is:
- Watching agent messages flow through the conversation
- Reading status.yaml (if they know to look for it)
- Checking workspace directories after the fact

There is no `/pas status` command. There is no summary view. There is no progress indicator. For long-running multi-agent processes, this is a significant DX gap. The user is in the dark until the process finishes or a gate pauses.

### Error experience

- Hook errors are reasonably clear (the self-eval check says exactly what is missing)
- But hook errors appear as stderr text, which can be confusing if you did not expect hooks to run
- No recovery guidance: if a process fails mid-way, the user has to understand resumability semantics from the orchestration pattern docs
- Signal routing failures go to log files that the user probably does not know to check

---

## 4. The Feedback System as a DX Feature

The feedback system (self-evaluation, signal routing, applying-feedback) is PAS's most distinctive feature. But from a user's perspective, it is invisible infrastructure. The user sees:
- Feedback files appearing in workspace directories
- The `applying-feedback` skill when they explicitly invoke it
- Hook blocks if agents forget self-evaluation

What the user does NOT see:
- What feedback has been collected
- What the feedback says (in human-readable terms)
- Whether feedback has been acted on
- The cumulative effect of feedback over time

This is a missed opportunity. The feedback loop is PAS's secret weapon — it makes processes improve over time. But the user cannot see this happening. A `/pas feedback summary` command that shows accumulated signals, their targets, and their status would make the invisible visible.

---

## 5. The Cycle-7 "Too Conservative" Signal

The orchestrator's self-evaluation from cycle-7 noted: "Discovery phase was too conservative — scoped a housekeeping cycle when the owner expected bolder structural action."

From a DX perspective, this reveals something important about the *process DX* (the DX of using the pas-development process itself, not the PAS framework). The feedback-driven cycle defaults to "fix what is broken" rather than "build what is missing." This is appropriate for maintenance but makes the process feel timid during strategic planning.

For the roadmap, this suggests:
- Discovery should distinguish between **maintenance cycles** (signal-driven, fix what is broken) and **strategic cycles** (directive-driven, build what is missing)
- The team should have a way to signal "this cycle is ambitious" vs "this cycle is careful"
- The orchestrator should not need owner pushback to shift from conservative to proactive

---

## 6. What Would Make PAS Recommendable

When someone recommends a tool, they tell a story: "I had this problem. I tried PAS. Within [time], I had [result]." For PAS to be recommendable, that story needs to be:

**"I needed my Claude Code agent to follow a consistent process for [task]. I typed `/pas`, described what I wanted, and 15 minutes later I had a working process with agents, skills, and automatic quality feedback. The next time I ran it, it was better because the feedback from the first run improved the instructions."**

To make that story true, PAS needs:

1. **A 5-minute "wow" moment**: The user runs a pre-built example process and sees multi-agent orchestration, self-evaluation, and feedback improvement in action. They understand what PAS does by watching it work, not by reading about it.

2. **A 15-minute creation path**: Templates for common patterns (content pipeline, code review, research synthesis) that the user customizes rather than builds from scratch.

3. **Visible improvement over time**: A dashboard or summary that shows "your process has improved N times based on feedback from M runs." The feedback loop is PAS's moat — it needs to be visible.

4. **Zero-jargon onboarding**: The first interaction should use words the user already knows (workflow, step, review point, automation) and introduce PAS terms only when the user needs them.

5. **Process-level observability**: While a process runs, the user should be able to see progress, quality scores, and any issues — not just raw agent output.

---

## 7. DX Roadmap Themes (12-month view)

### Months 1-3: Foundation (make it usable)
- **Quickstart experience**: `/pas quickstart` that creates and runs a sample process end-to-end
- **Process templates**: 3-5 starter templates for common patterns
- **Conceptual overview**: A document that explains PAS in user terms, not framework-developer terms
- **Glossary**: Define every PAS term where it is first used
- **`/pas help`**: A help command that shows available capabilities with descriptions

### Months 4-6: Workflow (make it productive)
- **`/pas status`**: Human-readable process status during and after runs
- **`/pas feedback summary`**: Show accumulated feedback, targets, and improvement history
- **`/pas list`**: Show all processes with descriptions and last-run info
- **Error recovery guide**: What to do when things go wrong, with step-by-step instructions
- **Interactive process builder**: Instead of sequential scripts, a guided conversation that produces the full process in one pass (the brainstorming already does this conceptually, but the creation scripts are separate steps)

### Months 7-9: Scale (make it shareable)
- **Process export/import**: Package a process for sharing with another project
- **Process versioning**: Track process evolution alongside feedback improvement
- **Cross-project library**: Share skills between projects without copying
- **Community process catalog**: A place to discover processes others have built
- **Visual process editor**: Extend the existing visualization to support editing

### Months 10-12: Polish (make it delightful)
- **Process analytics**: Run history, quality trends, feedback impact over time
- **Smart suggestions**: "Based on your feedback, your research phase could benefit from a fact-checker agent"
- **Progressive complexity**: Start with solo pattern, suggest upgrading when feedback indicates it
- **Onboarding for teams**: Multiple users working with shared processes
- **Performance baselines**: Process-level benchmarks so users can see objective improvement

---

## 8. The Single Most Important Thing

If PAS does one thing in the next 12 months, it should be: **create a 5-minute path from installation to running a working process**.

Everything else — templates, observability, sharing — builds on this foundation. If a user cannot experience PAS working within 5 minutes, they will never discover the feedback system, the orchestration patterns, or the multi-agent capabilities. The quickstart is the gateway to everything else.

Today, PAS is a powerful engine with no ignition switch. The roadmap should build the ignition switch first, then add the dashboard gauges, then add the cruise control.
