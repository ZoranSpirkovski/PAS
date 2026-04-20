[OQI-02]
Target: skill:ecosystem-scan
Degraded: My initial WebFetch calls hit a 301 redirect from `docs.claude.com` to `code.claude.com`, requiring a second round-trip per URL. Wasted ~2 tool calls.
Root Cause: The skill's "Process" step 1 says "Check Claude Code documentation" without naming the canonical host.
Fix: Add a note in `ecosystem-scan/SKILL.md` Process step 1: "Canonical Claude Code docs host is `code.claude.com` (not `docs.claude.com` — the latter 301-redirects)."
Evidence: Both WebFetch calls returned `REDIRECT DETECTED ... Status: 301 Moved Permanently`.
Priority: LOW

No other issues detected. Round 1 dispatch was clear, scoped, and the cited project-memory ecosystem facts (`agent_id`, `TeammateIdle`, agent hooks, `${CLAUDE_PLUGIN_ROOT}`) accurately matched what current docs confirmed.
