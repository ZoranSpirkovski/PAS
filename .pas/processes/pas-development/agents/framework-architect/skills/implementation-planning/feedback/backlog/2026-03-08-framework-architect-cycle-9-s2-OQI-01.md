[OQI-01]
Target: skill:implementation-planning
Degraded: Scope estimation precision
Root Cause: The skill says "Estimate scope: flag any priority that seems too large for a single cycle." I flagged library dedup as too large, but the estimation is qualitative ("too large to combine"). There is no quantitative framework — how many file modifications constitute "too large"? How many lines of change? The skill gives no guidance on calibrating scope.
Fix: Add a rough heuristic to the implementation-planning skill: "A single execution phase should target 10-15 file modifications maximum. Beyond that, split into sub-cycles." This prevents both over-scoping and under-scoping.
Evidence: "Library dedup is too large for this cycle" — true, but I had to make this call on intuition rather than a defined threshold.
Priority: LOW

