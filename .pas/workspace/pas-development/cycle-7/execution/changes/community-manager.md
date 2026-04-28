# Community Manager — Execution Changes

## P4: Add post-merge safety to pr-management skill

**File:** `processes/pas-development/agents/community-manager/skills/pr-management/SKILL.md`

### Changes

1. **Added Step 6: Merge main back into dev** (lines 91-116)
   - After PR merge, sync main back into dev with `--no-ff` merge
   - Immediate verification of dev-only directories (`processes/pas-development/process.md`, `library/`, `workspace/`)
   - Restore procedure from `HEAD~1` if any directories are missing
   - Explanation of why this step is required (prevents divergence, guards against the bug that deleted `processes/pas-development/` twice)

2. **Updated Step 5** (line 85-89)
   - Removed the "Do NOT merge main back into dev" warning that contradicted the new Step 6

3. **Updated Common Mistakes** (lines 127-131)
   - Removed: "Merging main back into dev (risks deleting dev-only directories — never do this)"
   - Added: "Skipping Step 6 (merge main back into dev) — causes divergence and harder cherry-picks"
   - Added: "Skipping the post-merge directory verification — the merge can delete dev-only directories"

### Rationale

The previous advice ("never merge main back into dev") was a blunt safety measure. The real risk was not the merge itself but the lack of verification afterward. The new Step 6 makes the merge a required step with an explicit safety check, directly preventing the class of bug that deleted `processes/pas-development/` twice.
