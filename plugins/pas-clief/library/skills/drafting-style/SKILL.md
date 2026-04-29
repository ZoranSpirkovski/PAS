---
name: drafting-style
description: Use when applying a workspace's drafting conventions to written output — voice, format, sentence rhythm, the things that make output feel like it belongs to this project. Reads the workspace's style notes if any and adjusts the draft accordingly.
---

# drafting-style

## When to use

You have a first draft and need to align it to this workspace's conventions before polishing for line clarity. The orchestrator named this skill in your spawn prompt.

## How to use

1. Read `<workspace-root>/REFERENCES.md` if it exists, looking for a "voice" or "style" section. Read any prior `outputs/` files in the workspace as exemplars.
2. Identify the conventions: typical sentence length, headings or no headings, level of formality, use of first/second/third person, list style, footnote style.
3. Re-read the draft. Adjust passages that don't match the conventions.
4. Output the adjusted draft. Note in `notes.md` what kinds of changes you made (e.g., "shortened intro paragraph; switched to second person for the CTA").

## Inputs

- A draft (markdown or plain text).
- Workspace-level style references.

## Outputs

- An adjusted draft, typically overwriting the input file or written to `outputs/<NN>-styled.md`.
