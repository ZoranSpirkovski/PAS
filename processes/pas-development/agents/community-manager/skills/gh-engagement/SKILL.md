---
name: gh-engagement
description: Use when engaging with contributors on GitHub issues. Guides tone, comment structure, and when to ask for clarification vs acknowledge vs resolve.
---

# GitHub Engagement

## Overview

Guide interactions with contributors on GitHub issues. Ensure responses are helpful, specific, and move the conversation toward resolution.

## When to Use

- When an issue needs clarification before it can be acted on
- When acknowledging a report that will be addressed
- When providing status updates on in-progress work
- When an issue has been resolved and needs a closing comment

## Process

### Asking for Clarification

1. Thank the reporter briefly
2. Explain specifically what information is missing and why it matters
3. Provide a template or example of what a good answer looks like
4. Run: `gh issue comment {number} --repo ZoranSpirkovski/PAS --body "{comment}"`

### Acknowledging a Report

1. Confirm you've read and understood the issue
2. State what category it falls into (bug, feature request, etc.)
3. If it will be addressed in the current cycle, say so
4. Run: `gh issue comment {number} --repo ZoranSpirkovski/PAS --body "{comment}"`

### Status Updates

1. Reference the specific work being done
2. Link to the PR if one exists
3. Run: `gh issue comment {number} --repo ZoranSpirkovski/PAS --body "{comment}"`

### Resolution

1. Explain what was done to resolve the issue
2. Link to the PR or commit
3. Do NOT close the issue — the product owner decides when to close
4. Run: `gh issue comment {number} --repo ZoranSpirkovski/PAS --body "{comment}"`

## Tone Guide

- Be concise — no filler, no corporate speak
- Match the contributor's energy — if they're frustrated, acknowledge it; if they're excited, share it
- Use "we" for the project, not "I"
- Never blame the user for confusion — if something is confusing, that's a DX issue to fix
- No emojis unless the contributor uses them first

## Quality Checks

- Every comment adds value (no "thanks for reporting!" without substance)
- Clarification requests are specific enough that the contributor knows exactly what to provide
- Comments reference specific artifacts or code when possible

## Common Mistakes

(Populated by feedback over time)
