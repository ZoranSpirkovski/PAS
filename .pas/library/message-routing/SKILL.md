---
name: message-routing
description: Use when classifying user messages at process gates. Carried by orchestrator agents to determine how to handle user responses.
---

# Message Routing

Classify user messages at gates to determine the correct response. Used by orchestrator agents during supervised mode when a gate pauses for user input.

## When to Use

- A phase has completed and the orchestrator is presenting output at a gate
- The user has responded to a gate prompt
- You need to determine: does this response mean "proceed" or something else?

## Classifications

### 1. Approval

**Signals:** "looks good", "continue", "approved", "go", "next", "yes", "lgtm", thumbs up, or any clear indication of satisfaction.

**Behavior:** Proceed to the next phase. No further action needed at this gate.

### 2. Feedback

**Signals:** "this is too promotional", "the tone is wrong", "needs more sources", or any critique of the output quality.

**Behavior:**
1. **Fix in session**: route the feedback to the appropriate agent to revise the output. Re-present the gate after revision.
2. **Queue for permanent improvement**: if feedback is enabled, write a structured signal to the workspace feedback inbox (`workspace/{process}/{slug}/feedback/`). Use the self-evaluation signal format:
   - PPU if the feedback expresses a persistent preference
   - OQI if the feedback identifies an output quality issue
   - Include `Target:` pointing to the skill or agent that produced the output

### 3. Question

**Signals:** "why this angle?", "what sources did you use?", "can you explain...", or any request for information about the output.

**Behavior:** Answer the question using context from the phase output and agent work. Then re-present the gate. Do not proceed until the user gives an explicit approval or instruction.

### 4. Instruction

**Signals:** "also include the SEC filing", "add a quote from...", "change the headline to...", or any directive to modify or extend the output.

**Behavior:** Incorporate the instruction into the current phase output. Route to the appropriate agent if needed. Re-present the gate after the change is made.

## Ambiguous Messages

If the user's response does not clearly fit one classification:

- Default to **Question** (safest: ask for clarification rather than proceeding incorrectly)
- Ask: "I want to make sure I understand. Are you asking me to [interpretation], or would you like to proceed?"
- Never assume approval from an ambiguous message

## Multiple Classifications

A single message can contain multiple classifications. Handle them in order:

1. Answer any questions first
2. Incorporate any instructions
3. Fix any feedback
4. Only then check for approval

Example: "Why did you use that source? Also add the SEC filing. Otherwise looks good." = Question + Instruction + Approval. Answer the question, add the SEC filing, then proceed.
