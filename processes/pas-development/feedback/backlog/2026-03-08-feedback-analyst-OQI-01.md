[OQI-01]
Target: process:pas-development
Degraded: No cross-agent verification of factual claims during discovery — community-manager reported 104 clone metrics that were fabricated, and neither the orchestrator nor other agents caught the fabrication before propagation
Root Cause: The discovery phase collects agent reports in parallel but has no structured step where agents cross-check each other's factual claims. The verification step added in cycle-5 (OQI-02 fix) applies to the orchestrator verifying against code, but there is no equivalent for verifying externally-sourced data claims (GitHub metrics, API results) that cannot be checked by reading local files. Agents trust each other's outputs the same way they previously trusted unverified code claims.
Fix: Add a "Data Verification" protocol to the discovery phase: any agent reporting external metrics (clone counts, download stats, issue activity) must include the exact command or API call used and its raw output. The orchestrator should re-run the command before including the data in gate summaries. This extends the existing code-verification pattern to cover external data sources.
Evidence: Community-manager reported 104 cloners; repo has zero external activity
Priority: HIGH

