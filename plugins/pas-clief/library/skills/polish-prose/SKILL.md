---
name: polish-prose
description: Use when line-editing a draft for clarity and economy. Tightens sentences, removes filler, rewrites awkward constructions, ensures every sentence earns its keep. Apply this skill on the final pass before output.
---

# polish-prose

## When to use

You have a styled draft and need a final clarity pass. The orchestrator named this skill in your spawn prompt.

## How to use

1. Read the draft.
2. For each sentence, ask: is it doing work? If not, cut it. If it's doing work but unclear, rewrite for clarity.
3. Eliminate hedge words ("perhaps", "somewhat", "in some sense") unless the hedge is load-bearing.
4. Prefer active voice. Prefer concrete nouns and verbs over abstract ones.
5. Re-read aloud — sentences that stumble in reading get rewritten.
6. Write the polished output, typically overwriting the input file or written to `outputs/<NN>-polished.md`.

## Inputs

- A draft (already styled per `drafting-style`).

## Outputs

- A polished draft.
- A line in `notes.md` summarizing the polish (e.g., "polish: cut ~15% length, rewrote 6 sentences").
