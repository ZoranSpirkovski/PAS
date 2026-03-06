---
name: supervised
description: User reviews and approves created artifacts before committing
gates: enforced
---

## Behavior

- After clarifying intent, present a preview of what will be created
- Do NOT create files until the user approves the plan
- Show file structure and key content before writing
- If the user requests changes, adjust the plan and re-present

## Gate Protocol

At each gate:
1. Show what will be created (directory structure, key file contents)
2. Ask: "Does this look right, or should I adjust anything?"
