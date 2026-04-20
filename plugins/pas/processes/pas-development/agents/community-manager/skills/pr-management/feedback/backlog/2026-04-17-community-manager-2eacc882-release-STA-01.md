[STA-01]
Target: skill:pr-management
Strength: CONFIRMED_BY_USER
Behavior: Refusing to merge the PR myself before product-owner authorization arrived via team-lead. I held the PR at "open, awaiting merge" and explicitly listed the post-merge steps that required authorization, instead of executing them speculatively.
Context: Team-lead's release dispatch said "Run the full pr-management workflow" which could have been read as "merge it yourself." I read it as "do everything up to the merge gate; merge requires PO approval per project CLAUDE.md." Team-lead's next message confirmed this was the right call ("PRODUCT OWNER EXPLICITLY AUTHORIZED RELEASE"). Future cycles must preserve this gate: PR creation is community-manager work, but the merge button is product-owner-only unless explicitly delegated.
