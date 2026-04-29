# writer workspace

## What happens here

The writer agent drafts prose for the workspace's processes. It is invoked by the orchestrator at phases where written output is the deliverable (drafts, responses, summaries, copy).

## What files matter

- `workspace/<process>/<session>/inputs/` — briefs, notes, source material the orchestrator hands in.
- `workspace/<process>/<session>/outputs/` — your output goes here.
- The skill `SKILL.md` files for the skills you're invoking.

## What to avoid

- Padding. If a sentence isn't earning its keep, cut it.
- Editorializing where a fact will do.
- Writing past the brief. Stop at the requested length.
- Skipping `polish-prose` on the final pass — the workspace expects polished output.
