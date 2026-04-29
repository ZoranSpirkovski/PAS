# {{workspace_name}}

{{one_to_three_line_identity}}

## Workspaces

- `library/agents/` — reusable agents you've defined for this workspace.
- `library/skills/` — reusable skills (capabilities) used by your agents and processes.
- `.claude/skills/<process>/` — your processes, slash-invokable as `/<process>`.
- `workspace/<process>/<session-id>/` — execution state for runs of your processes.

## Routing table

| Task | Go to | Read | Skills |
|------|-------|------|--------|
{{routing_rows}}

## Naming conventions

- Drafts: `_draft.md`. Final: `_final.md`. Versioned: `_v2.md`, `_v3.md`.
- Date prefix: `YYYY-MM-DD-<slug>.md`.
- Feedback: `feedback/YYYY-MM-DD-<source>-<topic>.md`.

## Rules

- **Workspace isolation.** Never reference one workspace's information inside another workspace's session.
- **Path resolution.** Plain names in process recipes search `library/` first (this project), then the plugin's library. Use `plugin:<name>` to force the plugin version.
- **Feedback.** Drop markdown into the relevant artifact's `feedback/` folder. Triage manually.
