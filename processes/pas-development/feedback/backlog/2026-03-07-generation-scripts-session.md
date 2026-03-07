[OQI-01]
Target: process:pas-development
Degraded: Generation scripts testing destroyed the entire pas-development process directory (53 files)
Root Cause: The pas-create-* scripts generate artifacts relative to CWD into processes/. Test cleanup commands (`rm -rf processes/test-process`, `rm -rf processes/test-pipeline`) operated on the project root's processes/ directory, which contains the real pas-development process. The test artifacts and the real process shared the same parent directory.
Fix: Script tests must use a dedicated temporary directory, not the project root. Either: (1) run tests in a temp dir with `cd $(mktemp -d)`, or (2) use a dedicated `test/` output directory, or (3) use git worktrees for testing. Never run `rm -rf` on paths under `processes/` at the project root.
Evidence: "git status showed 53 deleted files under processes/pas-development/. All agents, skills, modes, process.md, and changelogs were gone. Restored via git checkout HEAD."
Priority: HIGH

[OQI-02]
Target: process:pas-development
Degraded: Session ran without workspace initialization, status tracking, or self-evaluation
Root Cause: The session executed the generation scripts plan by reading docs/plans/ directly and working through tasks manually. The pas-development process orchestration was never invoked — no workspace was created, no status.yaml was initialized, no self-eval was written. The user had to explicitly request feedback collection.
Fix: When running under pas-development, the orchestrator must create workspace/pas-development/{slug}/ and status.yaml before phase 1, track status during execution, and write self-eval at shutdown. This is the process's responsibility, not just the framework hooks'.
Evidence: "User said 'the feedback mechanisms do not work' and 'workspace should also have been created'. workspace/ had only .gitkeep after completing all 7 tasks."
Priority: HIGH

[PPU-01]
Target: process:pas-development
Frequency: 2/2 sessions (SEO process creation + generation scripts)
Evidence: "User had to manually intervene both times to initiate feedback collection. Neither session produced feedback autonomously."
Priority: HIGH
Preference: Every pas-development session must produce feedback. The orchestrator must not declare completion without having written self-eval or explicitly noting "No issues detected." This is non-negotiable.
