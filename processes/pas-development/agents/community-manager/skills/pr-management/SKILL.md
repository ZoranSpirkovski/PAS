---
name: pr-management
description: Use in the Release phase to commit, branch, PR, and sync. Only plugin files go to main — everything else stays on dev.
---

# PR Management

## Branch Rules

- `main` — Plugin distribution only. Contains `plugins/pas/` and nothing else.
- `dev` — Development workspace. Everything lives here: processes, workspace, library, feedback, plans.

**PRs target `main` and contain only `plugins/pas/` files. Dev artifacts never leave dev.**

## When to Use

After Validation passes and the product owner approves release.

## Process

### Step 1: Separate commits on dev

Create two commits on `dev`:

1. **Plugin commit** — only files under `plugins/pas/`:
   ```bash
   git add plugins/pas/...
   git commit -m "{descriptive message}"
   ```

2. **Dev artifacts commit** — everything else (workspace, feedback, .gitignore, etc.):
   ```bash
   git add .gitignore workspace/ processes/ library/ ...
   git commit -m "Cycle-{N} dev artifacts: {brief summary}"
   ```

Push dev: `git push origin dev`

### Step 2: Feature branch off main

```bash
git checkout main && git pull origin main
git checkout -b {branch-name} main
git cherry-pick {plugin-commit-hash}
```

If cherry-pick conflicts (modify/delete for files new to main), resolve by keeping the modified version:
```bash
git add {conflicted-files}
git cherry-pick --continue --no-edit
```

**Branch naming:** Use the primary change as the branch name, e.g., `fix/feedback-deletion-workspace-utility`.

### Step 3: Verify plugin-only diff

```bash
git diff main --stat
```

Every file in the diff MUST be under `plugins/pas/`. If any non-plugin file appears, abort and fix.

### Step 4: Create PR

```bash
git push -u origin {branch-name}
gh pr create --base main --title "{title}" --body "{body}"
```

**PR body format:**
```markdown
## Summary

- {bullet points describing changes}

## Test plan

- [ ] {verification items from validation report}
```

**Issue linking:** Use "closes #N" in the PR body for issues this fixes. Comment on the issue with root cause and fix reference.

### Step 5: Clean up

After the product owner merges the PR on GitHub:

```bash
git branch -d <feature-branch>
```

### Step 6: Merge main back into dev

After the PR is merged on main, sync main back into dev so that merge commits and any squash diffs are reflected:

```bash
git checkout dev
git fetch origin main
git merge origin/main --no-ff -m "Merge main into dev after PR #{N}"
```

**Immediately verify dev-only directories survived the merge:**

```bash
test -f processes/pas-development/process.md && echo "OK: process.md" || echo "MISSING: process.md"
test -d library/ && echo "OK: library/" || echo "MISSING: library/"
test -d workspace/ && echo "OK: workspace/" || echo "MISSING: workspace/"
```

If any are missing, restore them from the commit before the merge:

```bash
git checkout HEAD~1 -- processes/ library/ workspace/
git commit -m "Restore dev-only directories after main merge"
```

This step is required. Skipping it causes dev and main to diverge, and the next cherry-pick becomes harder. The verification guard prevents the class of bug that has deleted `processes/pas-development/` twice in the past.

## Quality Checks

- PR diff contains ONLY `plugins/pas/` files
- All related issues are linked with "closes #N"
- PR title is under 70 characters
- No AI attribution in commits, PR description, or comments
- Branch is deleted after merge (GitHub auto-delete or manual)

## Common Mistakes

- Cherry-picking the dev artifacts commit instead of the plugin commit
- Skipping Step 6 (merge main back into dev) — causes divergence and harder cherry-picks
- Skipping the post-merge directory verification — the merge can delete dev-only directories
- Including workspace or process files in the PR
