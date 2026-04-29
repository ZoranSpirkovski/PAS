# Phase 03: Publish

## Agent

(orchestrator handles directly — no agent spawn)

## Inputs

- `outputs/02-polished-draft.md` — the polished draft.

## Outputs

- `workspace/newsletter/<session>/outputs/03-final.md` — the approved final.
- A line in `notes.md` recording publication.

## Instructions

The orchestrator handles this phase directly:

1. Surface `02-polished-draft.md` for the user's review.
2. Ask the user: "Approve as-is, request changes, or cancel?"
3. If changes requested, hand back to the writer with the user's feedback. (Loop within phase 02 if needed.)
4. On approval, copy `02-polished-draft.md` → `03-final.md`.
5. Ask the user where they want to publish (the orchestrator may offer to draft a paste-ready version for the user's chosen channel; pas-clief itself does not push to external services).
6. Update `STATUS.md` to `complete`.

## Self-eval criteria

- Did the user approve without changes? If not, what kind of changes — surface-level (polish slipped through) or substantive (draft missed the brief)? Record in feedback for the writer.
- Was the round-trip with the user tight (one revision or fewer)?
