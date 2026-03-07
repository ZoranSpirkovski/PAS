# PAS Testing Framework Design

## Problem

PAS creates processes, agents, and skills — but there's no way to know if it's actually producing better results than Claude without PAS. We need two things:

1. A cheap validation that runs by default after process creation (sanity check)
2. An expensive, opt-in evaluation framework for PAS framework development (testing)

## Context

PAS is a meta-framework. Testing it is unusual because:
- The "code" is mostly markdown instruction files executed by an LLM
- Without the `/pas` skill loaded, Claude doesn't know what a PAS process is
- Test prompts must be goal-oriented, not PAS-specific
- The real question isn't just "did it work" but "was PAS necessary, and was the complexity justified?"

### References

Three reference frameworks inform this design:
- `creating-skills/references/skill-creator/` — quantitative eval loop (test prompts, assertions, grading, benchmarks, viewer)
- `creating-skills/references/superpowers/` — TDD for documentation (RED baseline, GREEN compliance, REFACTOR loopholes)
- `creating-skills/references/skill-creation/` — Anthropic's skill authoring best practices

## Design

### Component 1: Sanity Check Skill

**Location:** `plugins/pas/processes/pas/agents/orchestrator/skills/sanity-check/`

**Purpose:** Cheap, runs by default as the final step of `creating-processes`. Validates the finished product before presenting to the user.

**Structure:**
```
sanity-check/
  SKILL.md
  feedback/
    backlog/
  changelog.md
```

**Checks:**

Structural validity:
- `process.md` has valid YAML frontmatter (name, goal, version, orchestration, phases)
- All referenced agents have `agent.md` files
- All referenced skills have `SKILL.md` files
- `feedback/backlog/` and `changelog.md` exist at every level
- Mode files exist and have correct frontmatter

Coherence:
- Phase I/O dependencies form a valid DAG (no cycles, no dangling references)
- Orchestration pattern matches agent count (solo = 1 agent, hub-and-spoke = 2+)
- Every phase has a gate defined

Right-sizing:
- If only 1 agent, pattern should be solo
- If all phases are sequential with no parallelism opportunity, flag hub-and-spoke as potential over-engineering
- If process has more phases than distinct outputs, flag potential phase bloat
- If agents have overlapping skills, flag potential agent consolidation

Completeness:
- Thin launcher exists at `.claude/skills/{name}/SKILL.md`
- Thin launcher points to correct `process.md`
- At least one mode file exists

**Output:** Pass/fail report with specific issues. Blocks user presentation if critical issues found (missing files, invalid YAML). Warns but doesn't block for right-sizing concerns.

### Component 2: Testing Skill

**Location:** `plugins/pas/processes/pas/agents/orchestrator/skills/testing/`

**Purpose:** Expensive, opt-in evaluation for PAS framework development. Answers: "Does PAS produce better results than no PAS? Is the complexity justified?"

**Structure:**
```
testing/
  SKILL.md
  references/
    eval-schema.md
    test-patterns.md
  scripts/
    grade.py
    aggregate.py
  feedback/
    backlog/
  changelog.md
```

**Workflow (with tracked tasks at each stage):**

Stage 1 — Setup:
- Define or select test case (goal prompt + assertions)
- Decision: which approaches to run (A, B, C, or all)
- Decision: which repo/context to test against
- Create workspace at `workspace/testing/{slug}/`

Stage 2 — Approach A (Skill-Creator Direct):
- Spawn subagent WITHOUT `/pas` — execute goal prompt, save output
- Spawn subagent WITH `/pas` — execute same goal prompt, save output
- Grade both outputs against assertions
- Decision: does PAS output meaningfully differ from baseline?

Stage 3 — Approach B (Two-Stage):
- Grade process artifacts from Stage 2's PAS run (structural validity, coherence, right-sizing — reuses sanity-check)
- Run the created process against the test input
- Grade process execution output against assertions
- Decision: did the process structure contribute to better output?

Stage 4 — Approach C (TDD Overlay):
- Review baseline output from Stage 2 — document specific failures/weaknesses
- Verify PAS output addresses those specific failures
- Document any new issues PAS introduced
- Decision: are the improvements worth the added complexity?

Stage 5 — Report:
- Aggregate grades across all approaches
- Produce benchmark comparison (pass rates, quality scores, token usage)
- Recommendation: PAS helped / didn't help / over-engineered
- Save report to `workspace/testing/{slug}/report.md`

### Eval Schema

**Test case format** (adapted from skill-creator's `evals.json`):

```json
{
  "test_name": "changelog-generation",
  "goal_prompt": "Generate a structured changelog for this repository grouped by category, referencing commit hashes",
  "context": {
    "repo": ".",
    "commit_range": "all"
  },
  "assertions": [
    {
      "id": "categories-present",
      "text": "Output groups changes by category (features, fixes, docs, etc.)",
      "type": "structural",
      "priority": "high"
    },
    {
      "id": "commits-referenced",
      "text": "Each entry references a commit hash",
      "type": "completeness",
      "priority": "high"
    },
    {
      "id": "no-missing-commits",
      "text": "All commits in range are accounted for",
      "type": "completeness",
      "priority": "high"
    },
    {
      "id": "chronological",
      "text": "Entries within categories follow chronological order",
      "type": "structural",
      "priority": "medium"
    },
    {
      "id": "descriptions-clear",
      "text": "Each entry has a human-readable description beyond the raw commit message",
      "type": "quality",
      "priority": "medium"
    }
  ]
}
```

**Grading output** (per run, follows skill-creator's `grading.json`):

```json
{
  "run_id": "with-pas",
  "expectations": [
    {
      "text": "Output groups changes by category",
      "passed": true,
      "evidence": "Found sections: Features, Fixes, Documentation, Infrastructure"
    }
  ],
  "timing": {
    "total_tokens": 0,
    "duration_ms": 0
  }
}
```

**Benchmark output** (aggregated comparison):

```json
{
  "test_name": "changelog-generation",
  "results": {
    "without-pas": { "pass_rate": 0.6, "total_tokens": 5000, "duration_ms": 15000 },
    "with-pas": { "pass_rate": 1.0, "total_tokens": 25000, "duration_ms": 60000 }
  },
  "recommendation": "PAS improved pass rate from 60% to 100% but used 5x more tokens. Justified for complex outputs, over-engineered for simple ones."
}
```

### Integration

**Sanity check integration with `creating-processes`:**
- After step 11 (Create Thin Launcher), invoke `sanity-check/SKILL.md`
- If critical issues: fix them before presenting to user
- If warnings: present alongside the result
- Log results in `workspace/{name}/{slug}/sanity-check.md`

**Testing skill invocation:**
- New routing entry in `/pas` router: "Testing / evaluating" (test, eval, compare, benchmark, does PAS help) -> read `testing/SKILL.md`
- Manual invocation only — never runs by default

**`creating-processes/SKILL.md` modification:**
- Replace step 12 (Create Integration Test) with sanity-check invocation

### Files to Create

```
plugins/pas/processes/pas/agents/orchestrator/skills/
  testing/
    SKILL.md
    references/
      eval-schema.md
      test-patterns.md
    scripts/
      grade.py
      aggregate.py
    feedback/
      backlog/
    changelog.md
  sanity-check/
    SKILL.md
    feedback/
      backlog/
    changelog.md
```

### Files to Modify

1. `plugins/pas/skills/pas/SKILL.md` — add routing entry for testing
2. `plugins/pas/processes/pas/agents/orchestrator/skills/creating-processes/SKILL.md` — replace step 12 with sanity-check invocation

### First Test Case

Changelog generation against this repo. Created at runtime in `workspace/testing/changelog-generation/` when someone first runs the testing skill. Not hardcoded into the skill.

## Future Considerations

- Testing is primarily useful during PAS framework development and will likely fade or take a well-defined form as the framework matures
- The sanity check is the long-term value — it stays as a default quality gate
- Additional test cases can be added following the same eval schema
- If testing complexity grows, the skill can graduate to a dedicated tester agent
