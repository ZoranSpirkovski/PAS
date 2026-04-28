# Ecosystem Scan — Cycle 7

## New Claude Code Capabilities

### UserPromptSubmit Hook (Relevant to Signal 2)
Claude Code's `UserPromptSubmit` hook fires when a user submits a prompt, before Claude processes it. It can inject context via stdout and can block prompts via exit code 2. This is directly relevant to the plan-mode bypass problem (Signal 2): a `UserPromptSubmit` hook could detect when a prompt involves PAS plugin changes and inject a reminder or routing instruction to use `/pas-development`.

**How PAS could use it:** A project-level hook in `.claude/settings.json` or `.claude/settings.local.json` that pattern-matches prompts mentioning `plugins/pas/` and injects context like "PAS plugin changes should go through /pas-development." This is more reliable than CLAUDE.md text alone because it fires deterministically on every prompt, not just when the model happens to consult instructions.

**Limitation:** UserPromptSubmit receives the raw prompt text. It cannot inspect the model's plan or tool calls — only the user's input. If a user says "fix the feedback routing" without mentioning `plugins/pas/`, the hook would miss it. So this is a complement to CLAUDE.md, not a replacement.

Source: [Hooks reference](https://code.claude.com/docs/en/hooks), [Claude blog on hooks](https://claude.com/blog/how-to-configure-hooks)

### PreToolUse Hook with Deny Capability (Relevant to Signal 2)
`PreToolUse` hooks fire before any tool execution and can return `permissionDecision: "deny"` with a reason. This is more powerful than UserPromptSubmit for Signal 2 because it can intercept actual file writes to `plugins/pas/` and block them with a message directing the agent to use `/pas-development`.

**How PAS could use it:** A `PreToolUse` hook matching `Write|Edit` that checks if the target path is under `plugins/pas/` and the current process is not `pas-development`. If so, deny with reason: "Direct edits to plugins/pas/ must go through the pas-development process."

**Assessment:** This is the strongest enforcement mechanism available. It operates at the tool level, not the prompt level. However, it would need careful implementation to avoid blocking legitimate pas-development execution phase edits.

Source: [Hooks guide](https://code.claude.com/docs/en/hooks-guide)

### InstructionsLoaded Hook Event
New hook event that fires when CLAUDE.md or `.claude/rules/*.md` files are loaded. Does not support matchers. Could be used to set up environment state when a session begins loading instructions, but has limited direct applicability to the current signals.

Source: [Claude Code CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

### ${CLAUDE_SKILL_DIR} Variable
Skills can now reference their own directory via `${CLAUDE_SKILL_DIR}`. This could simplify skill scripts that need to reference sibling files or data within their skill directory, but does not directly affect the current signals.

### Built-in Git Worktree Support (Relevant to Signal 1)
Claude Code v2.1.49+ added native `--worktree` support with `WorktreeCreate` and `WorktreeRemove` hook events. Agents can now work in isolated git worktrees natively.

**Relevance to Signal 1 (branch switching bug):** The release phase currently has a process.md/pr-management inconsistency around branch operations. Native worktree support means the release phase could use `--worktree` to create an isolated workspace for the PR branch instead of switching branches in the main working tree. This would eliminate the class of bugs where branch switching corrupts state or loses dev-only files.

**Assessment:** This is a significant opportunity but would be a larger architectural change. Worth noting as a future direction, not a cycle-7 fix.

Source: [Boris Cherny announcement](https://www.threads.com/@boris_cherny/post/DVAAnexgRUj/), [Claude Code common workflows](https://code.claude.com/docs/en/common-workflows)

### Agent Teams (Currently Active)
Agent teams are experimental but enabled in this project's settings. Key limitations relevant to PAS: no session resumption with in-process teammates, task status can lag, and shutdown behavior has known issues. PAS is already using this capability for cycle-7.

Source: [Agent teams docs](https://code.claude.com/docs/en/agent-teams)

## Competitive Landscape

### Plugin Sync Tools
Several tools have emerged for syncing skills/plugins across AI CLI tools:
- **skillshare**: Keeps skills in one directory and creates symlinks. Relevant pattern for Signal 3 (library mirror drift) — symlinks would keep mirrors in sync by definition.
- **Claude Plugin Sync**: Syncs plugins between Claude Code and Copilot CLI.

**What PAS does better:** PAS has a clear source-of-truth model (plugins/pas/library/ is source, library/ is mirror). The problem is not architectural — it's operational: nothing enforces the sync.

**Opportunity:** A PostToolUse hook on `Write|Edit` that detects changes to `plugins/pas/library/` and either auto-copies to `library/` or warns about drift. Alternatively, a simple shell script in hooks that runs on `Stop` to check for drift and report it.

### Agentic Framework Patterns
The broader ecosystem continues to converge on:
- **Process-as-code** (YAML/markdown definitions of multi-agent workflows)
- **Feedback loops** built into agent lifecycles
- **Plugin marketplaces** as distribution channels

PAS is well-positioned on all three. No competing framework has PAS's combination of process definition + feedback system + marketplace distribution.

## Ecosystem Trends

### Hook-driven Development
The community is increasingly using hooks as the primary enforcement mechanism rather than relying on CLAUDE.md instructions alone. Pattern: CLAUDE.md for guidance, hooks for enforcement. This is directly relevant to Signals 1 and 2 — PAS currently relies entirely on CLAUDE.md text for behavioral constraints that would be better enforced by hooks.

**Evidence:** Multiple blog posts and community repos dedicated to hook patterns (disler/claude-code-hooks-mastery, hook-driven dev workflows posts). The shift is from "tell the model what to do" to "prevent the model from doing what it shouldn't."

### Plugin Ecosystem Maturation
The marketplace ecosystem is maturing with better discovery, managed updates, and the git-subdir source type. PAS's marketplace distribution is current and aligned with the platform direction.

## Opportunities

1. **PreToolUse guard for plugins/pas/ edits (Signal 2)** — High impact, directly prevents the dogfooding gap. A hook that denies direct edits to `plugins/pas/` outside of a pas-development execution context would mechanically enforce the process.

2. **PostToolUse or Stop hook for library mirror sync (Signal 3)** — Medium impact. A hook that detects when `plugins/pas/library/` files change and flags (or auto-syncs) the mirror would eliminate drift as a recurring problem.

3. **UserPromptSubmit context injection (Signal 2)** — Medium impact, complements the PreToolUse guard. Injects routing guidance before the model even starts planning.

4. **Worktree-based release phase (Signal 1, future)** — High potential but larger scope than cycle-7. Native worktree support would eliminate the branch-switching class of bugs entirely.

## Risks

1. **Agent teams experimental status** — PAS relies on agent teams for its development process. The feature has known limitations (no session resumption, task status lag). If Anthropic changes the API or removes experimental features, PAS would need to fall back to sequential subagent orchestration.

2. **Hook JSON schema stability** — PAS hooks depend on specific input fields (`cwd`, `last_assistant_message`, tool input shapes). These are not formally versioned. A Claude Code update could change field names or structure.

3. **PreToolUse deny behavior** — There is a reported issue (anthropics/claude-code#4362) about PreToolUse `approve: false` being ignored. If PAS implements a PreToolUse guard for Signal 2, it needs to verify the deny mechanism works reliably in the current version.

## Implications for Signal Priority

- **Signal 2 (plan mode bypass)** has the strongest ecosystem support for a robust fix. The platform now provides mechanical enforcement (PreToolUse deny) that didn't exist or wasn't well-documented in earlier cycles. This should be prioritized.
- **Signal 3 (library mirror drift)** has a clean hook-based solution available (PostToolUse or Stop-phase sync check). Low complexity, high reliability improvement.
- **Signal 1 (release branch switching)** has a long-term solution (worktrees) but fixing the process.md/pr-management inconsistency is the right cycle-7 scope.
- **Signals 4 and 5 (housekeeping)** have no ecosystem implications — they are internal consistency fixes.
