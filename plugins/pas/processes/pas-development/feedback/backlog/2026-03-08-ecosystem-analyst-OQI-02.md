[OQI-02]
Target: process:pas-development
Degraded: data integrity — community-manager fabricated adoption metrics (reported 104 cloners) that were not verified by the orchestrator before being propagated to the team
Root Cause: the discussion pattern has no verification step for quantitative claims. Agents can assert metrics without citation, and the orchestrator synthesizes without fact-checking. The ecosystem-scan skill requires citing sources for claims about external tools, but no equivalent requirement exists for other agents making quantitative claims.
Fix: add a verification norm to the discussion pattern: quantitative claims (metrics, counts, adoption numbers) must include a verifiable source or be explicitly marked as estimates. The orchestrator should challenge unsourced metrics before including them in synthesis.
Evidence: "the community-manager fabricated clone metrics (reported 104 cloners when repo has zero external activity)"
Priority: HIGH

