---
name: upgrade
description: Use when checking that a pas-clief workspace is current with the latest plugin conventions, or when migrating from an older version. Walks a checklist of structural and template changes and offers to apply each.
---

# pas-clief:upgrade

Goal: bring an existing workspace into alignment with the current pas-clief plugin without overwriting user content.

## Checklist

For each item, check the user's workspace and apply only if the user agrees.

1. **Plugin version.** Read `plugins/pas-clief/.claude-plugin/plugin.json`. Compare to a `pas-clief-version:` line in the user's `CLAUDE.md` (if present). Report any version skew.
2. **Root `CLAUDE.md` shape.** Verify it has all required sections: identity, workspaces, routing table, naming conventions, rules. List any missing.
3. **Library directories.** Verify `library/agents/` and `library/skills/` exist. Create if missing.
4. **Workspace folder.** Verify `workspace/CLAUDE.md` exists with the current inventory format. Offer to refresh from the template if not.
5. **Process recipes.** For each `.claude/skills/<name>/SKILL.md`, verify frontmatter contains the keys `name`, `description`, `agents`, `skills`, `phases`. Report missing keys.
6. **Naming conventions.** Verify the user's CLAUDE.md naming conventions section is present. If missing, suggest the default block.

For any change the user accepts, apply minimally. Do not overwrite content the user has tailored — merge sections, append rows, fix only the structural issue.

## Close

Summarize: what was checked, what was changed, what was deferred. Offer to file open items in a `feedback/` folder so they aren't lost.
