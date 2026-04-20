[PPU-01]
Target: process:pas-development
Frequency: Stated once in my perspective (under "PR scoping recommendation"), explicitly validated by the cycle completing with a single 100-file PR that violates the documented constraint.
Evidence: My perspective file, section "PR scoping recommendation", argued explicitly for staged PRs citing cycle-14's dogfooding hazard (#113). The cycle shipped single-PR anyway. Either my recommendation was rejected on merit (in which case the rationale should land in the cycle-15 changelog), or the constraint was forgotten mid-execution (in which case the skill needs a hard guard). Owner-preference clarification needed: under what cycle types is single-PR acceptable even when it violates the plugin-only-diff rule?
Priority: MEDIUM
Preference: Before future large architectural cycles, make the PR-scoping decision explicit at the end of Planning (document: "This cycle will ship as N PRs. Rationale: ..."). Do not let PR scope be decided at Release time by default.

---

Route: none (all signals are process/agent/skill-local; no framework:pas targets identified in this session).
