---
name: bootstrap-marketplace
description: Scaffold a new user-controlled marketplace repository for PAS plugins. Invoked by /pas when cwd is not inside a marketplace and the user chooses to bootstrap one here.
---

# Bootstrap Marketplace

Creates a minimal Claude Code marketplace repository scaffold at the current working directory. After this runs, the user has:

- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `plugins/<first-plugin>/.claude-plugin/plugin.json` — a starter plugin.
- Empty `plugins/<first-plugin>/hooks/` and `plugins/<first-plugin>/skills/` directories.
- An initial git commit (the directory is `git init`-ed if not already a repo).

After bootstrap, the user can:

- Use `/pas:pas` to create skills and processes inside the new marketplace.
- Register the marketplace with Claude Code: `/plugin marketplace add .` (for local testing) or `gh repo create` + `/plugin marketplace add <org>/<repo>`.

## When to Use

- Invoked by the `/pas` Marketplace Gate when the user chooses "bootstrap here."
- Invoked directly by a user starting a new skills marketplace from scratch.

## When NOT to Use

- Do NOT run this if `.claude-plugin/marketplace.json` already exists in cwd or any parent — the user is already inside a marketplace.
- Do NOT run this inside an existing git repo that represents something else (e.g., a consumer project). Check with the user first.

## Process

1. **Check preconditions:**
   - `[ ! -f "$(pwd)/.claude-plugin/marketplace.json" ]` — else refuse.
   - Ask the user for:
     - **Marketplace name** (e.g., `internal-skill-marketplace`, `my-skills`). Used as the `name` field in `marketplace.json` — kebab-case recommended.
     - **First plugin name** (e.g., `my-plugin`). The initial plugin directory created under `plugins/`.
     - **Marketplace description** (one sentence).

2. **Run the scaffold script:**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-marketplace/scripts/scaffold-marketplace.sh" \
     --marketplace-name "$MARKETPLACE_NAME" \
     --plugin-name "$PLUGIN_NAME" \
     --description "$DESCRIPTION"
   ```

3. **Report to user:**

   - Print the created file tree.
   - Suggest next steps:
     - Run `/pas:pas` in this directory to create your first skill or process.
     - When ready to share: `gh repo create <org>/<name> --public|--private --source=. --push`.
     - Register with Claude Code: `/plugin marketplace add <org>/<name>` then `/plugin install <plugin-name>@<marketplace-name>`.

## Output Format

- A printed tree of created files.
- Git initial commit hash (if git init was performed).
- Next-step instructions tailored to whether the user has `gh` authenticated.

## Common Mistakes

- Scaffolding over an existing marketplace (the precondition check prevents this — don't bypass it).
- Forgetting to set `marketplace_name` and `plugin_name` to distinct values — they can be the same, but usually aren't (the marketplace is a container for multiple plugins).
