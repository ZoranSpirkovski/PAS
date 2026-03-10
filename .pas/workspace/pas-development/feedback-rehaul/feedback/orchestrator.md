[OQI-01]
Target: framework:pas
Degraded: Workspace recognition — orchestrator did not recognize or use existing workspace at workspace/pas-development/feedback-rehaul/ despite it being visible in git status untracked files
Root Cause: The executing-plans skill does not instruct the agent to check for an existing workspace before starting. The agent treated the plan execution as a standalone task rather than a continuation of the pas-development process instance.
Fix: The SessionStart hook (just implemented) will surface active workspaces. But the executing-plans skill should also check for active workspaces when the plan file lives inside a PAS repo.
Evidence: "what is workspace/pas-development/feedback-rehaul this is the workspace why don't you recognize that"
Priority: HIGH

[OQI-02]
Target: framework:pas
Degraded: PR scope — first PR (#9) included library/, CHANGELOG.md, and .claude/ files alongside plugins/pas/ changes. Required user correction and force-push to fix.
Root Cause: No convention existed for PR scope until user requested it. Plan did not separate plugin changes from dev-only changes.
Fix: PR scope convention now added to CLAUDE.md. Future plans should separate plugin deliverables from dev-only artifacts.
Evidence: "PRs should only be made for direct PAS UPGRADES/UPDATES IMO"
Priority: MEDIUM

[OQI-03]
Target: framework:pas
Degraded: Self-evaluation skipped again — orchestrator completed all implementation, testing, PR creation, and branch management without writing feedback or updating status.yaml. 5th consecutive session with this failure.
Root Cause: The executing-plans skill finishes with the finishing-a-development-branch skill, which focuses on git workflow (merge/PR/discard), not PAS lifecycle completion. The PAS shutdown sequence is not structurally connected to the skill chain.
Fix: The hooks implemented in this session (SessionStart context injection, Stop gate, TaskCompleted gate) should prevent this in future sessions. The orchestrator will literally be blocked from stopping.
Evidence: "also from what I see and correct me if I'm wrong we still didn't do the feedback properly"
Priority: HIGH
