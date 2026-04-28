# Cycle 12 Discovery — Milestone 2 Completion + Version Auto-Bump

## Directive

> "You need to always update the version with every new push so that the marketplace knows that we have made changes."
> Expanded scope: "Let's do it all" — complete remaining Milestone 2 items alongside the directive.

## Milestone Status

- **Milestone 1**: Complete (9/9 criteria pass). Roadmap needs updating.
- **Milestone 2**: 3/5 items done (test harness, error handling, signal schema). 2 remaining.

## Priorities

### P1: Version Auto-Bump (directive)
- Create `bump-version.sh` script to increment patch version across all 3 locations
- Integrate into pr-management as mandatory pre-commit step
- Allow `.claude-plugin/marketplace.json` in PRs (distribution artifact)

### P2: Library Dedup Implementation (Milestone 2)
- Implement Option A from design doc: `${CLAUDE_PLUGIN_ROOT}/library/` resolution
- Update `pas-create-process` to generate references using plugin library path
- Modify first-run detection to stop copying library files
- Project-level override mechanism for custom library skills
- First-run creates only `pas-config.yaml` and `workspace/`

### P3: README End-to-End Example (Milestone 2)
- Add full walkthrough showing process creation → execution → feedback → completion
- Include example process.md, agent definition, generated directory structure
- Show feedback signal writing and routing

### P4: Roadmap Housekeeping (dev-only)
- Mark Milestone 1 as complete in roadmap
- Update Milestone 2 progress with items completed in cycles 10-12
- Update plugin version (current: 1.3.0)

## Risk Assessment

- **Library dedup** is the highest-risk item — changes how processes reference library skills. Needs careful testing with pas-development process.
- **Version auto-bump** is low risk — additive change to release workflow.
- **README** is zero risk — documentation only.
