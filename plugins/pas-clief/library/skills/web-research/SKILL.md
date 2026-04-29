---
name: web-research
description: Use when an agent needs to gather sources or background information from the web for a topic. Produces a concise sources file with URLs, summaries, and the most relevant excerpts.
---

# web-research

## When to use

You need outside information to draft, fact-check, or contextualize a piece of work. The orchestrator named this skill in your spawn prompt.

## How to use

1. Identify the topic. The orchestrator hands you a brief or question.
2. Use available web tools (WebFetch, WebSearch) to gather 3–7 sources.
3. For each source: capture the URL, a 2–3 sentence summary, and the single most relevant excerpt.
4. Write the result to `workspace/<process>/<session>/outputs/<NN>-sources.md` in this format:

```markdown
# Sources for {{topic}}

## {{title or domain}}

- url: {{url}}
- summary: {{2-3 sentences}}
- excerpt: > {{quote}}
```

5. Note any contradictions between sources — flag them so the next phase can address them.

## Inputs

- A topic or question (string).
- Any prior session material that hints at known sources.

## Outputs

- A markdown file with N source entries.
- A short summary line in `notes.md`: `web-research: gathered N sources for <topic>`.
