# Workspace inventory

Execution state for runs of this project's processes. Each session lives at `<process-name>/<session-id>/`.

## Layout per session

- `STATUS.md` — current phase, history of phase transitions, pointer to active outputs.
- `notes.md` — free-form session log (orchestrator and agents append here).
- `outputs/` — phase outputs. One file or folder per phase.
- `feedback/` — session-level feedback drops.

## Active sessions

(Populated by the orchestrator as sessions run; remove or archive when done.)
