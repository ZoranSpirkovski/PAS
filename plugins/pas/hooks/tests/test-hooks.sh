#!/usr/bin/env bash
set -euo pipefail

# PAS Hook Test Harness
# Tests all hook scripts against their I/O contract: stdin JSON, exit code, stdout/stderr.
# Usage: bash plugins/pas/hooks/tests/test-hooks.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
ERRORS=()

# Colors (if terminal supports them)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' RED='' BOLD='' RESET=''
fi

run_hook() {
  local hook_script="$1"
  local input_json="$2"
  local expected_exit="$3"
  local test_name="$4"

  local actual_exit=0
  local stdout stderr
  stdout=$(echo "$input_json" | bash "$HOOKS_DIR/$hook_script" 2>/tmp/test-hook-stderr) || actual_exit=$?
  stderr=$(cat /tmp/test-hook-stderr 2>/dev/null || echo "")

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$test_name: expected exit $expected_exit, got $actual_exit")
    printf "  ${RED}FAIL${RESET} %s (expected exit %d, got %d)\n" "$test_name" "$expected_exit" "$actual_exit"
    if [ -n "$stderr" ]; then
      printf "       stderr: %s\n" "$(echo "$stderr" | head -1)"
    fi
  fi

  # Return stdout and stderr for assertions
  echo "$stdout" > /tmp/test-hook-stdout
  echo "$stderr" > /tmp/test-hook-stderr
}

assert_stdout_contains() {
  local pattern="$1"
  local test_name="$2"
  if grep -q "$pattern" /tmp/test-hook-stdout 2>/dev/null; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$test_name: stdout missing pattern '$pattern'")
    printf "  ${RED}FAIL${RESET} %s (stdout missing '%s')\n" "$test_name" "$pattern"
  fi
}

assert_stderr_contains() {
  local pattern="$1"
  local test_name="$2"
  if grep -q "$pattern" /tmp/test-hook-stderr 2>/dev/null; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$test_name: stderr missing pattern '$pattern'")
    printf "  ${RED}FAIL${RESET} %s (stderr missing '%s')\n" "$test_name" "$pattern"
  fi
}

assert_file_exists() {
  local file="$1"
  local test_name="$2"
  if [ -f "$file" ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$test_name: file not found: $file")
    printf "  ${RED}FAIL${RESET} %s (file not found)\n" "$test_name"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local test_name="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$test_name: file '$file' missing pattern '$pattern'")
    printf "  ${RED}FAIL${RESET} %s (file missing '%s')\n" "$test_name" "$pattern"
  fi
}

assert_dir_exists() {
  local dir="$1"
  local test_name="$2"
  if [ -d "$dir" ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$test_name: dir not found: $dir")
    printf "  ${RED}FAIL${RESET} %s (dir not found)\n" "$test_name"
  fi
}

assert_dir_not_exists() {
  local dir="$1"
  local test_name="$2"
  if [ ! -d "$dir" ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("$test_name: dir should not exist: $dir")
    printf "  ${RED}FAIL${RESET} %s (dir should not exist)\n" "$test_name"
  fi
}

# --- Setup test environment ---

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR" /tmp/test-hook-stdout /tmp/test-hook-stderr' EXIT

# Create PAS config under .pas/
mkdir -p "$TESTDIR/.pas"
cat > "$TESTDIR/.pas/config.yaml" <<'EOF'
feedback: enabled
feedback_disabled_at: ~
EOF

# Create workspace with in_progress status
mkdir -p "$TESTDIR/.pas/workspace/test/cycle-1/feedback"
cat > "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
started_at: 2026-03-10T10:00:00+00:00
completed_at: ~
status: in_progress

phases:
  discovery:
    status: completed
  planning:
    status: pending
EOF

printf "\n${BOLD}=== PAS Hook Test Harness ===${RESET}\n\n"

# =========================================================================
# Section 1: Non-PAS project (all hooks should exit 0 silently)
# =========================================================================

printf "${BOLD}1. Non-PAS project — all hooks exit 0${RESET}\n"

NOPADIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR" "$NOPADIR" /tmp/test-hook-stdout /tmp/test-hook-stderr' EXIT

run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$NOPADIR\",\"source\":\"startup\",\"session_id\":\"test1234abcd\"}" \
  0 "session-start: no .pas/config.yaml"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$NOPADIR\",\"stop_hook_active\":false,\"session_id\":\"test1234abcd\"}" \
  0 "completion-gate: no .pas/config.yaml"

run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$NOPADIR\",\"task_subject\":\"[PAS] Self-evaluation\"}" \
  0 "task-completion: no .pas/config.yaml"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$NOPADIR\",\"agent_id\":\"test-agent\"}" \
  0 "check-self-eval: no .pas/config.yaml"

run_hook "route-feedback.sh" \
  "{\"cwd\":\"$NOPADIR\"}" \
  0 "route-feedback: no .pas/config.yaml"

# =========================================================================
# Section 2: workspace.sh — in_progress preference (C1 regression)
# =========================================================================

printf "\n${BOLD}2. Workspace resolution — in_progress preference (C1)${RESET}\n"

# Create a second workspace that is completed (more recent mtime)
mkdir -p "$TESTDIR/.pas/workspace/test/cycle-0/feedback"
cat > "$TESTDIR/.pas/workspace/test/cycle-0/status.yaml" <<'EOF'
process: test
instance: cycle-0
started_at: 2026-03-09T10:00:00+00:00
completed_at: 2026-03-09T18:00:00+00:00
status: completed
EOF
# Touch completed workspace to make it more recent
sleep 0.1
touch "$TESTDIR/.pas/workspace/test/cycle-0/status.yaml"

# Source workspace.sh and test
RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$TESTDIR/.pas/workspace'")
if echo "$RESULT" | grep -q "cycle-1/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} workspace resolution prefers in_progress over completed\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("workspace resolution: got $RESULT instead of cycle-1")
  printf "  ${RED}FAIL${RESET} workspace resolution (got: %s)\n" "$RESULT"
fi

# Test fallback: when no in_progress workspace exists, fall back to most recent
mkdir -p "$TESTDIR/.pas/workspace-fallback/old/feedback"
cat > "$TESTDIR/.pas/workspace-fallback/old/status.yaml" <<'EOF'
process: test
instance: old
status: completed
EOF

RESULT2=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$TESTDIR/.pas/workspace-fallback'")
if echo "$RESULT2" | grep -q "old/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} workspace resolution falls back to completed when no in_progress\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("workspace fallback: got $RESULT2 instead of old")
  printf "  ${RED}FAIL${RESET} workspace fallback (got: %s)\n" "$RESULT2"
fi

# =========================================================================
# Section 3: pas-session-start.sh
# =========================================================================

printf "\n${BOLD}3. pas-session-start.sh${RESET}\n"

run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$TESTDIR\",\"source\":\"startup\",\"session_id\":\"abc12345xyz\"}" \
  0 "session-start: exits 0 with PAS config"

assert_stdout_contains "Session ID: abc12345" "session-start: outputs session ID"
assert_stdout_contains "PAS Framework Active" "session-start: outputs framework status"
assert_stdout_contains "feedback: enabled" "session-start: outputs feedback status"
assert_stdout_contains "CREATION ROUTING" "session-start: outputs creation routing instruction"
assert_stdout_contains "DEVELOPMENT ROUTING" "session-start: outputs development routing instruction"

# NEW (cycle 16, #173): fresh sessions must NOT auto-bind to an existing
# in_progress workspace. The status.yaml from setup has no `id: abc12345` in
# its sessions list, so this session is fresh and the hook must leave the
# workspace untouched. Skills bind explicitly when they create or claim a
# workspace (Session Binding Contract, library/orchestration/lifecycle.md).
if grep -q '^current_session:' "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("session-start (#173): fresh session auto-bound — current_session: was written")
  printf "  ${RED}FAIL${RESET} session-start: fresh session auto-bound (regression of #173)\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} session-start: fresh session does NOT auto-bind (#173)\n"
fi
if grep -q "id: abc12345" "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("session-start (#173): fresh session appended to sessions list")
  printf "  ${RED}FAIL${RESET} session-start: fresh session appended to sessions list (regression of #173)\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} session-start: fresh session not appended to sessions list (#173)\n"
fi
assert_stdout_contains "PAS_WORKSPACE_MISMATCH=cycle-1" \
  "session-start (#174): emits parseable PAS_WORKSPACE_MISMATCH= for unbound in_progress workspace"
assert_stdout_contains "PAS_WORKSPACE_MISMATCH_PATH=" \
  "session-start (#174): emits parseable PAS_WORKSPACE_MISMATCH_PATH="

# Cycle-17: hardened wording for the unbound-fresh-session branch.
# The orchestrator-side binding bug recurred after 1.4.1 because the
# SessionStart text told fresh sessions "you're not bound, invoke a skill"
# without forbidding manual writes. The new wording makes the prohibition
# explicit. See doctrines.md → Workspace Binding Is Skill-Owned → Phase
# Advancement Test.
assert_stdout_contains "DO NOT register this session" \
  "session-start (cycle-17): unbound branch tells orchestrator not to register"
assert_stdout_contains "DO NOT add a 'sessions:' entry" \
  "session-start (cycle-17): unbound branch forbids appending to sessions: list"
assert_stdout_contains "Only the skill that owns the workspace" \
  "session-start (cycle-17): unbound branch attributes ownership to the owning skill"

# Reconnect path: pre-seed the session id into the workspace's sessions list,
# then re-run session-start and assert that current_session: IS now refreshed.
cat >> "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<EOF

sessions:
  - id: abc12345
    started_at: 2026-03-10T10:00:00+00:00
    completed_at: ~
    feedback_collected: false
EOF
run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$TESTDIR\",\"source\":\"resume\",\"session_id\":\"abc12345xyz\"}" \
  0 "session-start (#173): reconnect runs cleanly"
assert_file_contains "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" \
  "current_session: abc12345" "session-start: reconnect refreshes current_session"

# =========================================================================
# Section 4: verify-completion-gate.sh
# =========================================================================

printf "\n${BOLD}4. verify-completion-gate.sh${RESET}\n"

# 4a: Pending phases → exit 0 (don't block mid-work)
run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: pending phases → exit 0"

# 4b: All completed, no feedback → exit 2
cat > "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: in_progress
current_session: abc12345

phases:
  discovery:
    status: completed
  planning:
    status: completed
EOF

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  2 "completion-gate: all completed, no feedback → exit 2"

assert_stderr_contains "COMPLETION GATE FAILED" "completion-gate: stderr shows gate failure"
assert_stderr_contains "orchestrator-abc12345.md" "completion-gate: stderr names expected file"

# 4c: Session-specific feedback exists → exit 0
echo "No issues detected." > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: session feedback exists → exit 0"

# 4d: Feedback from DIFFERENT session → exit 2
rm "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"
echo "No issues detected." > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-previous.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  2 "completion-gate: wrong session feedback → exit 2"

# 4e: stop_hook_active → exit 0 (loop prevention)
run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":true,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: stop_hook_active → exit 0 (loop prevention)"

# 4f: Completed workspace → exit 0 (C2 regression — Issue #23)
cat > "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: completed
completed_at: 2026-03-10T18:00:00+00:00

phases:
  discovery:
    status: completed
  planning:
    status: completed
EOF

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"newsession\"}" \
  0 "completion-gate: completed workspace → exit 0 (Issue #23 regression)"

# 4g: Agent feedback enforcement (Issue #19 regression)
cat > "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: in_progress
current_session: abc12345

phases:
  discovery:
    status: completed
    agent: framework-architect
  planning:
    status: completed
    agent: dx-specialist
EOF

# Orchestrator feedback exists, but agent feedback missing → exit 2
echo "No issues detected." > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  2 "completion-gate: missing agent feedback → exit 2 (Issue #19)"

assert_stderr_contains "Agent self-evaluation missing" \
  "completion-gate: stderr names missing agents (Issue #19)"

# Add agent feedback → exit 0
echo "No issues detected." > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/framework-architect.md"
echo "No issues detected." > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/dx-specialist.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: all agent feedback present → exit 0 (Issue #19)"

# Clean up agent feedback files
rm -f "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"
rm -f "$TESTDIR/.pas/workspace/test/cycle-1/feedback/framework-architect.md"
rm -f "$TESTDIR/.pas/workspace/test/cycle-1/feedback/dx-specialist.md"

# =========================================================================
# Section 5: verify-task-completion.sh
# =========================================================================

printf "\n${BOLD}5. verify-task-completion.sh${RESET}\n"

# Restore in_progress status for task tests
cat > "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: in_progress
current_session: abc12345

phases:
  discovery:
    status: completed
  planning:
    status: completed
EOF
rm -f "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-previous.md"

# 5a: Self-eval task without feedback → exit 2
run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"[PAS] Self-evaluation\"}" \
  2 "task-completion: self-eval without feedback → exit 2"

assert_stderr_contains "Cannot complete" "task-completion: stderr shows blocker message"

# 5b: Self-eval task with feedback → exit 0
echo "No issues detected." > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"

run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"[PAS] Self-evaluation\"}" \
  0 "task-completion: self-eval with feedback → exit 0"

# 5c: Finalize task without completed status → exit 2
run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"[PAS] Finalize status\"}" \
  2 "task-completion: finalize without completed status → exit 2"

# 5d: Finalize task with completed status → exit 0
cat > "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: completed
completed_at: 2026-03-10T18:00:00+00:00
current_session: abc12345

phases:
  discovery:
    status: completed
  planning:
    status: completed
EOF

run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"[PAS] Finalize status\"}" \
  0 "task-completion: finalize with completed status → exit 0"

# 5e: Non-PAS task → exit 0 (no interference)
run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"Fix the login bug\"}" \
  0 "task-completion: non-PAS task → exit 0"

# =========================================================================
# Section 6: check-self-eval.sh
# =========================================================================

printf "\n${BOLD}6. check-self-eval.sh${RESET}\n"

# Restore in_progress status
cat > "$TESTDIR/.pas/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: in_progress

phases:
  discovery:
    status: completed
EOF

# 6a: Agent with feedback file → exit 0
echo "No issues detected." > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/test-agent.md"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$TESTDIR\",\"agent_id\":\"test-agent\"}" \
  0 "check-self-eval: agent feedback exists → exit 0"

# 6b: Agent without feedback → exit 2
rm "$TESTDIR/.pas/workspace/test/cycle-1/feedback/test-agent.md"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$TESTDIR\",\"agent_id\":\"test-agent\"}" \
  2 "check-self-eval: agent feedback missing → exit 2"

assert_stderr_contains "shutting down without writing self-evaluation" "check-self-eval: stderr shows missing message"
assert_stderr_contains "feedback: disabled" "check-self-eval: stderr documents opt-out path"

# 6c: Feedback disabled → exit 0
cat > "$TESTDIR/.pas/config.yaml" <<'EOF'
feedback: disabled
EOF

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$TESTDIR\",\"agent_id\":\"test-agent\"}" \
  0 "check-self-eval: feedback disabled → exit 0"

# Restore feedback enabled
cat > "$TESTDIR/.pas/config.yaml" <<'EOF'
feedback: enabled
feedback_disabled_at: ~
EOF

# =========================================================================
# Section 7: route-feedback.sh
# =========================================================================

printf "\n${BOLD}7. route-feedback.sh${RESET}\n"

# 7a: Route signals from feedback file, preserve file, mark as routed
rm -f "$TESTDIR/.pas/workspace/test/cycle-1/feedback/"*.md
rm -f "$TESTDIR/.pas/workspace/test/cycle-1/feedback/"*.routed

cat > "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md" <<'EOF'
[OQI-01]
Target: process:test
Degraded: Test signal for routing
Priority: LOW
EOF

# Create the process feedback dir for routing target
mkdir -p "$TESTDIR/.pas/processes/test/feedback/backlog"

run_hook "route-feedback.sh" \
  "{\"cwd\":\"$TESTDIR\"}" \
  0 "route-feedback: routes signals → exit 0"

assert_file_exists "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md" \
  "route-feedback: feedback file preserved (not deleted)"

assert_file_exists "$TESTDIR/.pas/workspace/test/cycle-1/feedback/orchestrator-abc12345.md.routed" \
  "route-feedback: .routed marker created"

# 7b: Second run skips already-routed files
BEFORE_COUNT=$(find "$TESTDIR/.pas/processes/test/feedback/backlog" -name "*.md" 2>/dev/null | wc -l)

run_hook "route-feedback.sh" \
  "{\"cwd\":\"$TESTDIR\"}" \
  0 "route-feedback: second run exits 0"

AFTER_COUNT=$(find "$TESTDIR/.pas/processes/test/feedback/backlog" -name "*.md" 2>/dev/null | wc -l)
if [ "$BEFORE_COUNT" -eq "$AFTER_COUNT" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} route-feedback: no duplicate routing on second run\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("route-feedback: duplicate routing ($BEFORE_COUNT → $AFTER_COUNT files)")
  printf "  ${RED}FAIL${RESET} route-feedback: duplicate routing (%d → %d files)\n" "$BEFORE_COUNT" "$AFTER_COUNT"
fi

# =========================================================================
# Section 8: pas-create-process script (C3, C4 regression)
# =========================================================================

printf "\n${BOLD}8. pas-create-process — .pas/ paths + --force safety${RESET}\n"

CREATE_SCRIPT="$HOOKS_DIR/../processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process"
GEN_DIR=$(mktemp -d)

# 8a: Generated process lives under .pas/processes/
bash "$CREATE_SCRIPT" \
  --name test-proc \
  --goal "Test process" \
  --orchestration solo \
  --phase "work:orchestrator:input:output:user-approval" \
  --input "data:Test input" \
  --base-dir "$GEN_DIR" 2>/dev/null

assert_dir_exists "$GEN_DIR/.pas/processes/test-proc" \
  "pas-create-process: process created under .pas/processes/"

assert_file_exists "$GEN_DIR/.pas/processes/test-proc/process.md" \
  "pas-create-process: process.md exists"

# 8b: process.md references plugin library
assert_file_contains "$GEN_DIR/.pas/processes/test-proc/process.md" \
  "CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md" \
  "pas-create-process: process.md references plugin library lifecycle.md"

assert_file_contains "$GEN_DIR/.pas/processes/test-proc/process.md" \
  "status_file: .pas/workspace/test-proc/" \
  "pas-create-process: status_file uses .pas/workspace/"

# 8c: Thin launcher in .claude/skills/ references .pas/ paths
assert_file_exists "$GEN_DIR/.claude/skills/test-proc/SKILL.md" \
  "pas-create-process: thin launcher in .claude/skills/"

assert_file_contains "$GEN_DIR/.claude/skills/test-proc/SKILL.md" \
  ".pas/processes/test-proc/process.md" \
  "pas-create-process: thin launcher references .pas/processes/"

assert_file_contains "$GEN_DIR/.claude/skills/test-proc/SKILL.md" \
  "CLAUDE_PLUGIN_ROOT}/library/orchestration/lifecycle.md" \
  "pas-create-process: thin launcher references plugin library"

# 8d: No artifacts at project root
assert_dir_not_exists "$GEN_DIR/processes" \
  "pas-create-process: no processes/ at project root"

# 8e: feedback/backlog exists
assert_dir_exists "$GEN_DIR/.pas/processes/test-proc/feedback/backlog" \
  "pas-create-process: feedback/backlog exists"

# 8f: --force preserves reference/ directory (C4)
mkdir -p "$GEN_DIR/.pas/processes/test-proc/reference/source"
echo "precious data" > "$GEN_DIR/.pas/processes/test-proc/reference/source/material.txt"

bash "$CREATE_SCRIPT" \
  --name test-proc \
  --goal "Test process" \
  --orchestration solo \
  --phase "work:orchestrator:input:output:user-approval" \
  --input "data:Test input" \
  --base-dir "$GEN_DIR" \
  --force 2>/dev/null

if [ -f "$GEN_DIR/.pas/processes/test-proc/reference/source/material.txt" ]; then
  CONTENT=$(cat "$GEN_DIR/.pas/processes/test-proc/reference/source/material.txt")
  if [ "$CONTENT" = "precious data" ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} pas-create-process: --force preserves reference/ (C4)\n"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("--force: reference file corrupted")
    printf "  ${RED}FAIL${RESET} pas-create-process: --force corrupted reference file\n"
  fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("--force: reference/ directory deleted")
  printf "  ${RED}FAIL${RESET} pas-create-process: --force deleted reference/ directory\n"
fi

rm -rf "$GEN_DIR"

# =========================================================================
# Section 9: pas-development-session-start.sh
# =========================================================================

printf "\n${BOLD}9. pas-development-session-start.sh${RESET}\n"

# 9a: PAS development project — outputs routing
DEVDIR=$(mktemp -d)
mkdir -p "$DEVDIR/.claude/skills/pas-development"
echo "---" > "$DEVDIR/.claude/skills/pas-development/SKILL.md"

run_hook "pas-development-session-start.sh" \
  "{\"cwd\":\"$DEVDIR\",\"session_id\":\"test1234\"}" \
  0 "pas-dev-session-start: PAS dev project → exit 0"

assert_stdout_contains "DEVELOPMENT ROUTING" \
  "pas-dev-session-start: outputs development routing"

# 9b: Non-PAS-development project — silent
NONDEVDIR=$(mktemp -d)

run_hook "pas-development-session-start.sh" \
  "{\"cwd\":\"$NONDEVDIR\",\"session_id\":\"test1234\"}" \
  0 "pas-dev-session-start: non-dev project → exit 0"

if ! grep -q "DEVELOPMENT ROUTING" /tmp/test-hook-stdout 2>/dev/null; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} pas-dev-session-start: no output for non-dev project\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("pas-dev-session-start: should not output for non-dev project")
  printf "  ${RED}FAIL${RESET} pas-dev-session-start: should not output for non-dev project\n"
fi

rm -rf "$DEVDIR" "$NONDEVDIR"

# =========================================================================
# Section 10: Edge cases
# =========================================================================

printf "\n${BOLD}10. Edge cases${RESET}\n"

# 9a: Missing session_id — hooks should handle gracefully
run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$TESTDIR\",\"source\":\"startup\"}" \
  0 "edge-case: missing session_id → session-start exits 0"

# 9b: Empty workspace directory — no status.yaml found
EMPTYDIR=$(mktemp -d)
mkdir -p "$EMPTYDIR/.pas"
cat > "$EMPTYDIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
mkdir -p "$EMPTYDIR/.pas/workspace"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$EMPTYDIR\",\"stop_hook_active\":false,\"session_id\":\"test1234\"}" \
  0 "edge-case: empty workspace dir → exit 0"

rm -rf "$EMPTYDIR"

# 9c: No workspace directory at all
NOWSDIR=$(mktemp -d)
mkdir -p "$NOWSDIR/.pas"
cat > "$NOWSDIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$NOWSDIR\",\"stop_hook_active\":false,\"session_id\":\"test1234\"}" \
  0 "edge-case: no workspace dir → exit 0"

rm -rf "$NOWSDIR"

# =========================================================================
# Section 11: Migration — old-style layout auto-migrates
# =========================================================================

printf "\n${BOLD}11. Migration — old-style layout auto-migrates${RESET}\n"

MIGDIR=$(mktemp -d)

# Set up old-style layout at root
cat > "$MIGDIR/pas-config.yaml" <<'EOF'
feedback: enabled
feedback_disabled_at: ~
EOF
mkdir -p "$MIGDIR/workspace/test/cycle-1/feedback"
cat > "$MIGDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: in_progress

phases:
  work:
    status: completed
EOF
mkdir -p "$MIGDIR/processes/test/feedback/backlog"
mkdir -p "$MIGDIR/library/orchestration"

# Run session-start hook — should trigger migration
run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$MIGDIR\",\"source\":\"startup\",\"session_id\":\"mig12345xyz\"}" \
  0 "migration: session-start triggers migration → exit 0"

# Verify migration happened
assert_file_exists "$MIGDIR/.pas/config.yaml" \
  "migration: .pas/config.yaml exists after migration"

assert_dir_exists "$MIGDIR/.pas/workspace" \
  "migration: .pas/workspace/ exists after migration"

assert_dir_exists "$MIGDIR/.pas/processes" \
  "migration: .pas/processes/ exists after migration"

assert_dir_exists "$MIGDIR/.pas/library" \
  "migration: .pas/library/ exists after migration"

# Old paths should be gone
if [ ! -f "$MIGDIR/pas-config.yaml" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} migration: old pas-config.yaml removed\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("migration: old pas-config.yaml still exists")
  printf "  ${RED}FAIL${RESET} migration: old pas-config.yaml still exists\n"
fi

if [ ! -d "$MIGDIR/workspace" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} migration: old workspace/ removed\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("migration: old workspace/ still exists")
  printf "  ${RED}FAIL${RESET} migration: old workspace/ still exists\n"
fi

rm -rf "$MIGDIR"

# =========================================================================
# Section: C05 — agent_type scoping + #71 substantive-message bypass
# =========================================================================

printf "\n${BOLD}C05. agent_type scoping for non-PAS subagents${RESET}\n"

# Setup a workspace whose status.yaml declares specific PAS agents
C05DIR=$(mktemp -d)
mkdir -p "$C05DIR/.pas/workspace/proc/inst-c05/feedback"
printf 'feedback: enabled\n' > "$C05DIR/.pas/config.yaml"
cat > "$C05DIR/.pas/workspace/proc/inst-c05/status.yaml" <<'EOF'
process: proc
instance: inst-c05
status: in_progress
current_session: c05test1

phases:
  discovery:
    status: in_progress
    agent: [framework-architect, dx-specialist]
  planning:
    status: pending
    agent: framework-architect
EOF

# T-C05-1: agent_type "Explore" (not in status.yaml allowlist), no feedback
# file → SubagentStop exits 0 silently (non-PAS passthrough). This is the
# core bug from #67/#68/#38.
run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C05DIR\",\"agent_id\":\"some-explore-id\",\"agent_type\":\"Explore\"}" \
  0 "C05-1: agent_type Explore → exit 0 (non-PAS passthrough)"

# T-C05-2: agent_type framework-architect (in allowlist), no feedback file
# → SubagentStop exits 2 (PAS scoping retained — gate still works).
run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C05DIR\",\"agent_id\":\"framework-architect\",\"agent_type\":\"framework-architect\"}" \
  2 "C05-2: PAS-defined agent without feedback → exit 2 (gate enforced)"

assert_stderr_contains "shutting down without writing self-evaluation" \
  "C05-2: stderr shows the standard block message"

# T-C05-3: PAS agent with feedback file present → exit 0
echo "No issues detected." > "$C05DIR/.pas/workspace/proc/inst-c05/feedback/framework-architect.md"
run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C05DIR\",\"agent_id\":\"framework-architect\",\"agent_type\":\"framework-architect\"}" \
  0 "C05-3: PAS agent with feedback file → exit 0"

# T-C05-4: empty agent_type → SAFE-FAIL to "treat as PAS agent" (over-block).
# A previously-passing fixture (no feedback file for unknown agent) must
# still block — confirms we did NOT silently weaken the gate.
rm -f "$C05DIR/.pas/workspace/proc/inst-c05/feedback/framework-architect.md"
run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C05DIR\",\"agent_id\":\"unknown-agent\",\"agent_type\":\"\"}" \
  2 "C05-4: empty agent_type → safe-fail over-block (gate not weakened)"

# T-C05-5: SessionStart with non-empty agent_id → no PAS lifecycle text
run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$C05DIR\",\"source\":\"startup\",\"session_id\":\"c05sub1\",\"agent_id\":\"some-subagent-id\"}" \
  0 "C05-5: SessionStart with agent_id → exit 0"

if grep -q "PAS Framework Active" /tmp/test-hook-stdout 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("C05-5: SessionStart should NOT inject 'PAS Framework Active' for subagents")
  printf "  ${RED}FAIL${RESET} C05-5: PAS lifecycle text leaked into subagent context\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C05-5: no PAS lifecycle text in subagent SessionStart\n"
fi

# T-C05-6: SessionStart with empty agent_id (orchestrator) → full text injected
run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$C05DIR\",\"source\":\"startup\",\"session_id\":\"c05orch1\"}" \
  0 "C05-6: SessionStart without agent_id → exit 0"

assert_stdout_contains "PAS Framework Active" \
  "C05-6: orchestrator SessionStart still injects lifecycle text"

# T-C05-7: substantive last_assistant_message (>200 chars, no summary
# keywords) → exits 0 with audit-line on stderr (#71 substantive bypass).
LONG_MSG="This is a long substantive review message that contains the actual findings the parent agent needs to receive. It deliberately avoids any of the boilerplate summary phrases that the bypass heuristic looks for, so the gate must let this through. The message is well over two hundred characters so the length check passes too."
run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C05DIR\",\"agent_id\":\"framework-architect\",\"agent_type\":\"framework-architect\",\"last_assistant_message\":\"$LONG_MSG\"}" \
  0 "C05-7: substantive response → exit 0 (#71 bypass)"

assert_stderr_contains "substantive response detected" \
  "C05-7: stderr emits audit line so bypass is visible"

# T-C05-8: short summary boilerplate → still blocks (the bug we're fixing).
# "Self-evaluation written. No issues detected during this review." is
# exactly the elision text from the #71 bug report.
SHORT_MSG="Self-evaluation written. No issues detected during this review."
run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C05DIR\",\"agent_id\":\"framework-architect\",\"agent_type\":\"framework-architect\",\"last_assistant_message\":\"$SHORT_MSG\"}" \
  2 "C05-8: summary-boilerplate response → exit 2 (block — that's the bug)"

# T-C05-9 (C05.1 fixup): Agent-tool subagents inherit parent's SessionStart
# context, not their own. The injected text MUST include a SUBAGENT NOTE
# carve-out so subagents reading the parent's context know the lifecycle
# does not apply to them — without this, Explore/Plan/general-purpose
# subagents short-circuit into the PAS shutdown ritual (the residual #38
# behavior caught in I2 validation).
run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$C05DIR\",\"source\":\"startup\",\"session_id\":\"c05fixup\"}" \
  0 "C05-9: orchestrator SessionStart exits 0 with SUBAGENT NOTE present"

assert_stdout_contains "SUBAGENT NOTE" \
  "C05-9: orchestrator's injected text includes SUBAGENT NOTE carve-out"

assert_stdout_contains "spawned via the Agent tool" \
  "C05-9: SUBAGENT NOTE explains who it applies to"

assert_stdout_contains "DO NOT follow this lifecycle" \
  "C05-9: SUBAGENT NOTE gives subagents an explicit opt-out"

# T-C05-10 (C05.1 fixup): LAST_MSG with embedded newlines must not crash
# the integer comparison. Pre-fix: `wc -c | tr -d ' '` could leave a
# trailing newline in LAST_MSG_LEN; `[ "$X" -gt 200 ]` then crashed under
# set -euo pipefail with "integer expression expected" — same family as
# #55. The printf '%s' + tr '[:space:]' fix prevents the crash.
LONG_MSG_WITH_NEWLINE=$(printf '%s\n%s\n%s' \
  "Multi-line substantive response that the agent wrote as its actual report." \
  "It includes embedded newlines because real subagent responses do." \
  "Total length is comfortably over the 200-char threshold for the bypass.")

# Use jq to safely encode the multi-line string into the JSON payload.
LMSG_JSON=$(printf '%s' "$LONG_MSG_WITH_NEWLINE" | jq -Rs .)
PAYLOAD="{\"cwd\":\"$C05DIR\",\"agent_id\":\"framework-architect\",\"agent_type\":\"framework-architect\",\"last_assistant_message\":${LMSG_JSON}}"

run_hook "check-self-eval.sh" "$PAYLOAD" 0 \
  "C05-10: LAST_MSG with newlines → exit 0 cleanly (no integer-expression crash)"

if grep -qE 'integer expression expected' /tmp/test-hook-stderr 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("C05-10: integer expression crash leaked into stderr")
  printf "  ${RED}FAIL${RESET} C05-10: integer expression crash present in stderr\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C05-10: no integer-expression error in stderr\n"
fi

rm -rf "$C05DIR"

# =========================================================================
# Section: C06 — verify-completion-gate absolute-path diagnostics
# =========================================================================

printf "\n${BOLD}C06. verify-completion-gate absolute-path diagnostics${RESET}\n"

C06DIR=$(mktemp -d)
mkdir -p "$C06DIR/.pas/workspace/proc/inst-c06/feedback"
printf 'feedback: enabled\n' > "$C06DIR/.pas/config.yaml"
cat > "$C06DIR/.pas/workspace/proc/inst-c06/status.yaml" <<'EOF'
process: proc
instance: inst-c06
status: in_progress
current_session: c06test1

phases:
  discovery:
    status: completed
EOF

# T-C06-1: missing orchestrator feedback → stderr contains an absolute path
# (starts with /), not just the bare filename.
run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$C06DIR\",\"stop_hook_active\":false,\"session_id\":\"c06test1\"}" \
  2 "C06-1: missing orchestrator → exit 2"

if grep -qE "Orchestrator self-evaluation missing: /" /tmp/test-hook-stderr 2>/dev/null; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C06-1: stderr names absolute path (starts with /)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C06-1: stderr missing absolute orchestrator path")
  printf "  ${RED}FAIL${RESET} C06-1: stderr missing absolute path\n"
fi

# T-C06-2: stderr includes the resolver diagnostic line
assert_stderr_contains "Resolved PAS_PROJECT_ROOT:" \
  "C06-2: stderr exposes PAS_PROJECT_ROOT for diagnosability"

assert_stderr_contains "Checked feedback dir:" \
  "C06-2: stderr names the feedback dir actually checked"

# T-C06-3: worktree fixture — agent writes feedback in main checkout's .pas/,
# hook called from worktree cwd → exits 0 because PAS_PROJECT_ROOT resolves
# back to the main worktree (closes #70-F4 deadlock + makes the diagnostic
# the only thing the user sees on a true mismatch, not a phantom failure).
WTBASE=$(mktemp -d)
( cd "$WTBASE" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -m init -q ) >/dev/null 2>&1
mkdir -p "$WTBASE/.pas/workspace/proc/inst-wt/feedback"
printf 'feedback: enabled\n' > "$WTBASE/.pas/config.yaml"
cat > "$WTBASE/.pas/workspace/proc/inst-wt/status.yaml" <<'EOF'
process: proc
instance: inst-wt
status: in_progress
current_session: wt12abcd

phases:
  discovery:
    status: completed
EOF
echo "ok" > "$WTBASE/.pas/workspace/proc/inst-wt/feedback/orchestrator-wt12abcd.md"
( cd "$WTBASE" && git worktree add -q "$WTBASE/.wt-c06" -b c06-test-branch ) >/dev/null 2>&1

if [ -d "$WTBASE/.wt-c06" ]; then
  run_hook "verify-completion-gate.sh" \
    "{\"cwd\":\"$WTBASE/.wt-c06\",\"stop_hook_active\":false,\"session_id\":\"wt12abcd\"}" \
    0 "C06-3: worktree cwd resolves to main .pas/, finds feedback → exit 0"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C06-3: worktree fixture unavailable (skipped)\n"
fi
rm -rf "$WTBASE" "$C06DIR"

# =========================================================================
# Section: C08 — verify-task-completion phase output_files checkpoint
# =========================================================================

printf "\n${BOLD}C08. verify-task-completion output_files checkpoint${RESET}\n"

C08DIR=$(mktemp -d)
mkdir -p "$C08DIR/.pas/workspace/proc/inst-c08/feedback"
mkdir -p "$C08DIR/.pas/workspace/proc/inst-c08/discovery"
printf 'feedback: enabled\n' > "$C08DIR/.pas/config.yaml"

# status.yaml uses the live key-based phase schema (matches cycle-14/status.yaml)
cat > "$C08DIR/.pas/workspace/proc/inst-c08/status.yaml" <<'EOF'
process: proc
instance: inst-c08
status: in_progress
current_session: c08test1

phases:
  discovery:
    status: in_progress
    agent: framework-architect
    output_files:
      - discovery/priorities.md
      - discovery/perspective.md
  planning:
    status: pending
    agent: framework-architect
    output_files:
      - planning/implementation-plan.md
  execution:
    status: pending
    output_files: []
EOF

# T-C08-1: phase deliverable missing → TaskCompleted blocked, exit 2
run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$C08DIR\",\"task_subject\":\"[PAS] Phase: discovery\",\"session_id\":\"c08test1\"}" \
  2 "C08-1: missing output_files → exit 2 blocks task completion"

assert_stderr_contains "phase deliverables missing" \
  "C08-1: stderr names the failure mode"

assert_stderr_contains "discovery/priorities.md" \
  "C08-1: stderr lists the missing file"

# T-C08-2: write the required files → TaskCompleted allowed
echo "priorities content" > "$C08DIR/.pas/workspace/proc/inst-c08/discovery/priorities.md"
echo "perspective content" > "$C08DIR/.pas/workspace/proc/inst-c08/discovery/perspective.md"

run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$C08DIR\",\"task_subject\":\"[PAS] Phase: discovery\",\"session_id\":\"c08test1\"}" \
  0 "C08-2: all output_files present → exit 0"

# T-C08-3: phase with empty output_files (no enforcement applies) → exit 0
run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$C08DIR\",\"task_subject\":\"[PAS] Phase: execution\",\"session_id\":\"c08test1\"}" \
  0 "C08-3: phase with empty output_files → exit 0 (no-op)"

# T-C08-4 (bonus): phase with no output_files block at all → exit 0
cat > "$C08DIR/.pas/workspace/proc/inst-c08/status.yaml" <<'EOF'
process: proc
instance: inst-c08
status: in_progress
current_session: c08test1

phases:
  oldphase:
    status: in_progress
    agent: someagent
EOF

run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$C08DIR\",\"task_subject\":\"[PAS] Phase: oldphase\",\"session_id\":\"c08test1\"}" \
  0 "C08-4: phase with no output_files block → exit 0 (back-compat)"

rm -rf "$C08DIR"

# =========================================================================
# Section: C04 — session-id-first workspace resolution
# =========================================================================

printf "\n${BOLD}C04. session-id-first workspace resolution${RESET}\n"

# Two sibling workspaces under the same process; resolver should pick the
# one whose current_session matches the given id, NOT the most-recently-
# touched one (which was the pre-fix behavior — bug #52).
C04DIR=$(mktemp -d)
mkdir -p "$C04DIR/.pas/workspace/proc/inst-a/feedback"
mkdir -p "$C04DIR/.pas/workspace/proc/inst-b/feedback"
printf 'feedback: enabled\n' > "$C04DIR/.pas/config.yaml"

# inst-a: older workspace, matches session id 'aaaa1111'
cat > "$C04DIR/.pas/workspace/proc/inst-a/status.yaml" <<'EOF'
process: proc
instance: inst-a
status: in_progress
current_session: aaaa1111

phases:
  discovery:
    status: pending
EOF

# Sleep then write inst-b LATER so it has newer mtime and would win mtime fight
sleep 0.1
cat > "$C04DIR/.pas/workspace/proc/inst-b/status.yaml" <<'EOF'
process: proc
instance: inst-b
status: in_progress
current_session: bbbb2222

phases:
  discovery:
    status: pending
EOF

# T-C04-1: session id matches inst-a → resolver picks inst-a even though
# inst-b was just written and has newer mtime
RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$C04DIR/.pas/workspace' aaaa1111")
if echo "$RESULT" | grep -q "inst-a/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C04-1: session id beats mtime (picks matching workspace)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C04-1: expected inst-a, got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C04-1: picked wrong workspace (got: '%s')\n" "$RESULT"
fi

# T-C04-2: no current_session anywhere — fall back to mtime (back-compat)
C04DIR2=$(mktemp -d)
mkdir -p "$C04DIR2/.pas/workspace/proc/inst-x"
mkdir -p "$C04DIR2/.pas/workspace/proc/inst-y"
cat > "$C04DIR2/.pas/workspace/proc/inst-x/status.yaml" <<'EOF'
process: proc
instance: inst-x
status: in_progress
EOF
sleep 0.1
cat > "$C04DIR2/.pas/workspace/proc/inst-y/status.yaml" <<'EOF'
process: proc
instance: inst-y
status: in_progress
EOF

RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$C04DIR2/.pas/workspace' nosuchid")
if echo "$RESULT" | grep -q "inst-y/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C04-2: no match on session id → falls back to mtime (back-compat)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C04-2: expected inst-y (newer mtime), got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C04-2: mtime fallback broken (got: '%s')\n" "$RESULT"
fi

# T-C04-3: empty session_id arg → falls back to mtime (sessions without ids)
RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$C04DIR2/.pas/workspace' ''")
if echo "$RESULT" | grep -q "inst-y/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C04-3: empty session_id → mtime fallback\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C04-3: empty session_id broke resolution (got: '$RESULT')")
  printf "  ${RED}FAIL${RESET} C04-3: empty session_id (got: '%s')\n" "$RESULT"
fi

# T-C04-4: matching workspace has status pending, not in_progress — session
# id still wins over the status filter.
C04DIR4=$(mktemp -d)
mkdir -p "$C04DIR4/.pas/workspace/proc/inst-pending"
mkdir -p "$C04DIR4/.pas/workspace/proc/inst-active"
cat > "$C04DIR4/.pas/workspace/proc/inst-pending/status.yaml" <<'EOF'
process: proc
instance: inst-pending
status: pending
current_session: ccccdddd
EOF
sleep 0.1
cat > "$C04DIR4/.pas/workspace/proc/inst-active/status.yaml" <<'EOF'
process: proc
instance: inst-active
status: in_progress
current_session: eeeeffff
EOF

RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$C04DIR4/.pas/workspace' ccccdddd")
if echo "$RESULT" | grep -q "inst-pending/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C04-4: session id beats in_progress status filter\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C04-4: expected inst-pending, got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C04-4: session id didn't beat status filter (got: '%s')\n" "$RESULT"
fi

rm -rf "$C04DIR" "$C04DIR2" "$C04DIR4"

# =========================================================================
# Section: C07 — route-feedback.sh framework_signal_repo enforcement
# =========================================================================

printf "\n${BOLD}C07. route-feedback.sh framework_signal_repo enforcement${RESET}\n"

# T-C07-1: signal with valid framework_signal_repo → audit log records target.
# We DON'T actually call gh issue create (no auth in test); the route function
# logs the target repo BEFORE the gh call so we can assert it from log alone.
C07DIR=$(mktemp -d)
mkdir -p "$C07DIR/.pas/workspace/proc/inst-c07/feedback"
cat > "$C07DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
framework_signal_repo: ZoranSpirkovski/PAS
EOF
cat > "$C07DIR/.pas/workspace/proc/inst-c07/status.yaml" <<'EOF'
process: proc
instance: inst-c07
status: in_progress

phases:
  discovery:
    status: completed
EOF

cat > "$C07DIR/.pas/workspace/proc/inst-c07/feedback/agent-c07.md" <<'EOF'
[OQI-99]
Target: framework:pas
Route: github-issue
Degraded: test signal for routing audit
Priority: LOW
EOF

run_hook "route-feedback.sh" \
  "{\"cwd\":\"$C07DIR\"}" \
  0 "C07-1: routing with valid config → exit 0"

if [ -f "$C07DIR/.pas/feedback/framework-routing.log" ] && \
   grep -q "Filing OQI-99 on repo ZoranSpirkovski/PAS" "$C07DIR/.pas/feedback/framework-routing.log"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C07-1: audit log records target repo before gh call\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C07-1: audit log missing 'Filing OQI-99 on repo ZoranSpirkovski/PAS'")
  printf "  ${RED}FAIL${RESET} C07-1: audit log missing target-repo line\n"
fi

# T-C07-2: signal with EMPTY framework_signal_repo → REFUSED, no gh call.
# Achieved by clearing both project config AND CLAUDE_PLUGIN_ROOT so the
# fallback can't supply a default either.
C07DIR2=$(mktemp -d)
mkdir -p "$C07DIR2/.pas/workspace/proc/inst-c07b/feedback"
cat > "$C07DIR2/.pas/config.yaml" <<'EOF'
feedback: enabled
framework_signal_repo:
EOF
cat > "$C07DIR2/.pas/workspace/proc/inst-c07b/status.yaml" <<'EOF'
process: proc
instance: inst-c07b
status: in_progress

phases:
  discovery:
    status: completed
EOF

cat > "$C07DIR2/.pas/workspace/proc/inst-c07b/feedback/agent-c07b.md" <<'EOF'
[OQI-98]
Target: framework:pas
Route: github-issue
Degraded: test signal that should NOT be filed
Priority: LOW
EOF

# Run with CLAUDE_PLUGIN_ROOT pointed at a minimally-valid fake plugin whose
# pas-config.yaml is absent/empty — the "must refuse" path. The hardened
# resolver requires .claude-plugin/plugin.json + hooks/ to accept the path.
FAKE_PLUGIN=$(mktemp -d)
mkdir -p "$FAKE_PLUGIN/.claude-plugin" "$FAKE_PLUGIN/hooks"
printf '{"name":"fake-for-c07-2"}' > "$FAKE_PLUGIN/.claude-plugin/plugin.json"
RESULT=$(echo "{\"cwd\":\"$C07DIR2\"}" | env CLAUDE_PLUGIN_ROOT="$FAKE_PLUGIN" bash "$HOOKS_DIR/route-feedback.sh" 2>/dev/null; echo "exit=$?")
if echo "$RESULT" | grep -q 'exit=0'; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C07-2: hook exits 0 on empty config (no crash)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C07-2: hook crashed on empty framework_signal_repo: $RESULT")
  printf "  ${RED}FAIL${RESET} C07-2: hook crashed (got: %s)\n" "$RESULT"
fi

if [ -f "$C07DIR2/.pas/feedback/framework-routing.log" ] && \
   grep -q "REFUSED:.*OQI-98" "$C07DIR2/.pas/feedback/framework-routing.log"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C07-2: REFUSED log entry written for empty config\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C07-2: missing REFUSED log entry for OQI-98")
  printf "  ${RED}FAIL${RESET} C07-2: REFUSED entry missing\n"
fi

rm -rf "$C07DIR" "$C07DIR2" "$FAKE_PLUGIN"

# =========================================================================
# Section: C03 — check-self-eval.sh grep -c integer comparison fix
# =========================================================================

printf "\n${BOLD}C03. check-self-eval.sh grep -c fix${RESET}\n"

# Setup: enable feedback, in_progress workspace, feedback file present so the
# transcript-secondary path is what's exercised — and feedback file ABSENT so
# we hit the secondary path. We need a real transcript file with no signals.
C03DIR=$(mktemp -d)
mkdir -p "$C03DIR/.pas/workspace/proc/inst-c03/feedback"
printf 'feedback: enabled\n' > "$C03DIR/.pas/config.yaml"
cat > "$C03DIR/.pas/workspace/proc/inst-c03/status.yaml" <<'EOF'
process: proc
instance: inst-c03
status: in_progress

phases:
  discovery:
    status: completed
EOF

# T-C03-1: transcript with zero signal patterns → exits 2 cleanly (block,
# but no integer-comparison crash). Pre-fix: would crash with `[: 0\n0:
# integer expression expected` and exit 1, not 2.
TRANSCRIPT_NO_SIGNALS=$(mktemp)
printf 'just some text\nno signal markers here\nfinal line\n' > "$TRANSCRIPT_NO_SIGNALS"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C03DIR\",\"agent_id\":\"unknown-agent\",\"agent_transcript_path\":\"$TRANSCRIPT_NO_SIGNALS\"}" \
  2 "C03-1: zero-signal transcript → exit 2 cleanly (no integer-comparison crash)"

if grep -q 'integer expression expected' /tmp/test-hook-stderr 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("C03-1: integer comparison crash leaked into stderr")
  printf "  ${RED}FAIL${RESET} C03-1: integer comparison crash present in stderr\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C03-1: no integer-comparison error in stderr\n"
fi

# T-C03-2: transcript WITH a signal pattern → exit 0 (signal detected via
# secondary path). No agent_id-matching feedback file should be required.
TRANSCRIPT_WITH_SIGNAL=$(mktemp)
printf 'agent did some work\n[PPU-01]\nTarget: skill:foo\n' > "$TRANSCRIPT_WITH_SIGNAL"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$C03DIR\",\"agent_id\":\"unknown-agent\",\"agent_transcript_path\":\"$TRANSCRIPT_WITH_SIGNAL\"}" \
  0 "C03-2: transcript with PPU-01 signal → exit 0 (secondary path detects)"

rm -f "$TRANSCRIPT_NO_SIGNALS" "$TRANSCRIPT_WITH_SIGNAL"
rm -rf "$C03DIR"

# =========================================================================
# Section: C02 — pas-session-start.sh tolerates missing fields (warns)
# =========================================================================

printf "\n${BOLD}C02. pas-session-start.sh missing-field tolerance${RESET}\n"

# T-C02-1: status.yaml missing instance: → exit 0, warn names instance
C02DIR=$(mktemp -d)
mkdir -p "$C02DIR/.pas/workspace/proc/inst-1/feedback"
printf 'feedback: enabled\n' > "$C02DIR/.pas/config.yaml"
cat > "$C02DIR/.pas/workspace/proc/inst-1/status.yaml" <<'EOF'
process: proc
status: in_progress

phases:
  discovery:
    status: pending
EOF

run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$C02DIR\",\"source\":\"startup\",\"session_id\":\"c02test1\"}" \
  0 "C02-1: missing instance field → exit 0"

assert_stdout_contains "Missing required fields: instance" \
  "C02-1: stdout warns about missing instance field"

# T-C02-2: status.yaml missing instance AND status — defaults applied
C02DIR2=$(mktemp -d)
mkdir -p "$C02DIR2/.pas/workspace/proc/inst-2/feedback"
printf 'feedback: enabled\n' > "$C02DIR2/.pas/config.yaml"
cat > "$C02DIR2/.pas/workspace/proc/inst-2/status.yaml" <<'EOF'
process: proc

phases:
  discovery:
    status: pending
EOF

run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$C02DIR2\",\"source\":\"startup\",\"session_id\":\"c02test2\"}" \
  0 "C02-2: missing instance AND status → exit 0"

assert_stdout_contains "inst-2 (status: unknown)" \
  "C02-2: INSTANCE defaults to dirname, status to 'unknown'"

# T-C02-3: complete status.yaml — no warning
C02DIR3=$(mktemp -d)
mkdir -p "$C02DIR3/.pas/workspace/proc/inst-3/feedback"
printf 'feedback: enabled\n' > "$C02DIR3/.pas/config.yaml"
cat > "$C02DIR3/.pas/workspace/proc/inst-3/status.yaml" <<'EOF'
process: proc
instance: inst-3
status: in_progress

phases:
  discovery:
    status: pending
EOF

run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$C02DIR3\",\"source\":\"startup\",\"session_id\":\"c02test3\"}" \
  0 "C02-3: complete status.yaml → exit 0"

if grep -q "Missing required fields" /tmp/test-hook-stdout 2>/dev/null; then
  FAIL=$((FAIL + 1))
  ERRORS+=("C02-3: complete status.yaml should NOT trigger warning")
  printf "  ${RED}FAIL${RESET} C02-3: warning printed for complete status.yaml\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C02-3: no warning for complete status.yaml\n"
fi

rm -rf "$C02DIR" "$C02DIR2" "$C02DIR3"

# =========================================================================
# Section: C01 — lib/guards.sh defensive defaults + resolve_pas_project_root
# =========================================================================

printf "\n${BOLD}C01. lib/guards.sh foundation${RESET}\n"

# T-C01-1: resolve_claude_plugin_root walk-up populates a valid plugin path when env is unset.
# Sourcing alone no longer auto-sets the var; the function must be called.
RESULT=$(env -u CLAUDE_PLUGIN_ROOT bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_claude_plugin_root && echo \"\$CLAUDE_PLUGIN_ROOT\"")
if [ -n "$RESULT" ] && [ -f "$RESULT/.claude-plugin/plugin.json" ] && [ -d "$RESULT/hooks" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C01-1: resolve_claude_plugin_root walk-up finds valid plugin\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C01-1: walk-up failed (got: '$RESULT')")
  printf "  ${RED}FAIL${RESET} C01-1: walk-up (got: '%s')\n" "$RESULT"
fi

# T-C01-2: resolve_pas_project_root from cwd containing .pas/config.yaml
RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_pas_project_root '$TESTDIR'")
if [ "$RESULT" = "$TESTDIR" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C01-2: resolve_pas_project_root from PAS-root cwd\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C01-2: expected '$TESTDIR', got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C01-2: resolve from PAS-root cwd (got: '%s')\n" "$RESULT"
fi

# T-C01-3: walk up from a deep subdirectory
mkdir -p "$TESTDIR/sub/deeper/nest"
RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_pas_project_root '$TESTDIR/sub/deeper/nest'")
if [ "$RESULT" = "$TESTDIR" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C01-3: resolve walks up from deep subdirectory\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C01-3: expected '$TESTDIR', got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C01-3: walk up from subdir (got: '%s')\n" "$RESULT"
fi

# T-C01-4: git worktree fallback — worktree dir has no .pas/, main dir does
WTBASE=$(mktemp -d)
( cd "$WTBASE" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -m init -q ) >/dev/null 2>&1
mkdir -p "$WTBASE/.pas"
printf 'feedback: enabled\n' > "$WTBASE/.pas/config.yaml"
( cd "$WTBASE" && git worktree add -q "$WTBASE/.wt" -b c01-test-branch ) >/dev/null 2>&1
if [ -d "$WTBASE/.wt" ]; then
  RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_pas_project_root '$WTBASE/.wt'")
  # Resolve symlinks for comparison (macOS/Linux tmpdir realpath quirks)
  EXPECTED_REAL=$(cd "$WTBASE" && pwd -P)
  RESULT_REAL=$(cd "$RESULT" 2>/dev/null && pwd -P || echo "$RESULT")
  if [ "$RESULT_REAL" = "$EXPECTED_REAL" ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} C01-4: resolve falls back to git --show-toplevel from worktree\n"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("C01-4: expected '$EXPECTED_REAL', got '$RESULT_REAL'")
    printf "  ${RED}FAIL${RESET} C01-4: worktree fallback (got: '%s')\n" "$RESULT_REAL"
  fi
else
  # Worktree creation failed — skip but don't fail the suite
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C01-4: worktree fixture unavailable (skipped, but no failure)\n"
fi
rm -rf "$WTBASE"

# T-C01-5: from /tmp (non-PAS, non-git) returns non-zero
if bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_pas_project_root /tmp" >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  ERRORS+=("C01-5: expected non-zero exit when no PAS root resolvable")
  printf "  ${RED}FAIL${RESET} C01-5: should return non-zero from /tmp\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C01-5: returns non-zero when no PAS root resolvable\n"
fi

# =========================================================================
# C10: resolve_claude_plugin_root hardened resolver
# =========================================================================

# T-C10-1: valid env var is accepted (strategy 1)
RESULT=$(env CLAUDE_PLUGIN_ROOT="$(cd "$HOOKS_DIR/.." && pwd)" bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_claude_plugin_root && echo \"\$CLAUDE_PLUGIN_ROOT\"")
EXPECTED=$(cd "$HOOKS_DIR/.." && pwd)
if [ "$RESULT" = "$EXPECTED" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C10-1: valid env var accepted (strategy 1)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C10-1: expected '$EXPECTED', got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C10-1: env-var path (got: '%s')\n" "$RESULT"
fi

# T-C10-2: invalid env var is rejected, walk-up succeeds (strategy 2)
RESULT=$(env CLAUDE_PLUGIN_ROOT=/nonexistent-plugin-path bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_claude_plugin_root && echo \"\$CLAUDE_PLUGIN_ROOT\"" 2>/dev/null)
if [ -n "$RESULT" ] && [ -f "$RESULT/.claude-plugin/plugin.json" ] && [ "$RESULT" != "/nonexistent-plugin-path" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C10-2: invalid env rejected, walk-up recovers\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C10-2: expected recovery via walk-up (got: '$RESULT')")
  printf "  ${RED}FAIL${RESET} C10-2: walk-up recovery (got: '%s')\n" "$RESULT"
fi

# T-C10-3: env set without hooks/ dir is rejected (validation)
TMPROOT=$(mktemp -d)
mkdir -p "$TMPROOT/.claude-plugin"
printf '{"name":"fake"}' > "$TMPROOT/.claude-plugin/plugin.json"
# No hooks/ dir — should fail validation on strategy 1 and fall through to walk-up
RESULT=$(env CLAUDE_PLUGIN_ROOT="$TMPROOT" bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_claude_plugin_root && echo \"\$CLAUDE_PLUGIN_ROOT\"" 2>/dev/null)
if [ -n "$RESULT" ] && [ "$RESULT" != "$TMPROOT" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C10-3: invalid env (no hooks/) rejected, falls through\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C10-3: expected rejection of env without hooks/ dir (got: '$RESULT')")
  printf "  ${RED}FAIL${RESET} C10-3: validation (got: '%s')\n" "$RESULT"
fi
rm -rf "$TMPROOT"

# T-C10-4: all strategies fail → loud stderr + non-zero exit
# Copy guards.sh to a location with no plugin ancestors, point HOME away.
ISOLATED=$(mktemp -d)
cp "$HOOKS_DIR/lib/guards.sh" "$ISOLATED/guards.sh"
FAKE_HOME=$(mktemp -d)
ERR_OUTPUT=$(env -u CLAUDE_PLUGIN_ROOT HOME="$FAKE_HOME" bash -c "source '$ISOLATED/guards.sh' && resolve_claude_plugin_root" 2>&1) && EXIT=$? || EXIT=$?
if [ "$EXIT" -ne 0 ] && echo "$ERR_OUTPUT" | grep -q "unable to resolve CLAUDE_PLUGIN_ROOT"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C10-4: all strategies fail → non-zero + stderr diagnosis\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C10-4: expected non-zero exit + 'unable to resolve' stderr (exit=$EXIT, output='$ERR_OUTPUT')")
  printf "  ${RED}FAIL${RESET} C10-4: loud failure missing (exit=%d)\n" "$EXIT"
fi
rm -rf "$ISOLATED" "$FAKE_HOME"

# =========================================================================
# C11: resolve_marketplace_root (Marketplace Gate helper)
# =========================================================================

# T-C11-1: cwd inside marketplace tree → echoes marketplace root
C11DIR=$(mktemp -d)
mkdir -p "$C11DIR/.claude-plugin" "$C11DIR/sub/deep"
printf '{"name":"test-market"}' > "$C11DIR/.claude-plugin/marketplace.json"
RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_marketplace_root '$C11DIR/sub/deep'")
if [ "$RESULT" = "$C11DIR" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C11-1: walks up from subdir to marketplace root\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C11-1: expected '$C11DIR', got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C11-1: walk-up (got: '%s')\n" "$RESULT"
fi

# T-C11-2: cwd IS the marketplace root → echoes cwd
RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_marketplace_root '$C11DIR'")
if [ "$RESULT" = "$C11DIR" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C11-2: cwd IS marketplace → echoes cwd\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C11-2: expected '$C11DIR', got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C11-2: cwd-root (got: '%s')\n" "$RESULT"
fi

# T-C11-3: cwd outside any marketplace → non-zero exit
C11DIR_OUT=$(mktemp -d)
if bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_marketplace_root '$C11DIR_OUT'" >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  ERRORS+=("C11-3: expected non-zero exit outside any marketplace")
  printf "  ${RED}FAIL${RESET} C11-3: should return non-zero\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C11-3: non-zero exit outside marketplace\n"
fi
rm -rf "$C11DIR" "$C11DIR_OUT"

# =========================================================================
# C13: workspace-only PAS project detection (P7 consumer shrink)
# =========================================================================

# T-C13-1: a project with only .pas/workspace/ (no config.yaml) is valid
C13DIR=$(mktemp -d)
mkdir -p "$C13DIR/.pas/workspace"
RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && CWD='$C13DIR' guard_pas_project && echo \"OK: \$PAS_PROJECT_ROOT\"")
if [ "$RESULT" = "OK: $C13DIR" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C13-1: workspace-only project recognized (no config.yaml)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C13-1: expected 'OK: $C13DIR', got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C13-1: workspace-only (got: '%s')\n" "$RESULT"
fi

# T-C13-2: guard_feedback_enabled falls back to plugin pas-config.yaml
# Use real plugin root (has feedback: enabled in pas-config.yaml)
PLUGIN_ROOT=$(cd "$HOOKS_DIR/.." && pwd)
if bash -c "source '$HOOKS_DIR/lib/guards.sh' && CWD='$C13DIR' CLAUDE_PLUGIN_ROOT='$PLUGIN_ROOT' guard_feedback_enabled" 2>/dev/null; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C13-2: feedback-enabled falls back to plugin default\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C13-2: guard_feedback_enabled failed with workspace-only + plugin default")
  printf "  ${RED}FAIL${RESET} C13-2: plugin fallback failed\n"
fi
rm -rf "$C13DIR"

# =========================================================================
# C12: marketplace-aware feedback routing + host-id filenames
# =========================================================================

# T-C12-1: resolve_host_id reads from project override file
C12DIR=$(mktemp -d)
mkdir -p "$C12DIR/.pas/workspace"
echo "my-test-host" > "$C12DIR/.pas/workspace/host-id"
RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_host_id '$C12DIR'")
if [ "$RESULT" = "my-test-host" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C12-1: host-id read from project override\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C12-1: expected 'my-test-host', got '$RESULT'")
  printf "  ${RED}FAIL${RESET} C12-1: host-id override (got: '%s')\n" "$RESULT"
fi
rm -rf "$C12DIR"

# T-C12-2: resolve_host_id falls back to sanitized basename
C12DIR2=$(mktemp -d)
# Dir name includes safe chars; no override file
HOST_RESULT=$(bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_host_id '$C12DIR2'")
EXPECTED=$(basename "$C12DIR2" | tr -cd 'A-Za-z0-9._-')
if [ "$HOST_RESULT" = "$EXPECTED" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C12-2: host-id falls back to sanitized basename\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C12-2: expected '$EXPECTED', got '$HOST_RESULT'")
  printf "  ${RED}FAIL${RESET} C12-2: host-id fallback (got: '%s')\n" "$HOST_RESULT"
fi
rm -rf "$C12DIR2"

# T-C12-3: routed filename includes host-id (end-to-end via route-feedback.sh)
C12DIR3=$(mktemp -d)
mkdir -p "$C12DIR3/.pas/workspace/proc/inst-c12/feedback"
mkdir -p "$C12DIR3/.pas/processes/proc/agents/tester/feedback/backlog"
echo "my-host-c12" > "$C12DIR3/.pas/workspace/host-id"
cat > "$C12DIR3/.pas/config.yaml" <<EOF
feedback: enabled
framework_signal_repo: ZoranSpirkovski/PAS
EOF
cat > "$C12DIR3/.pas/workspace/proc/inst-c12/status.yaml" <<EOF
process: proc
instance: inst-c12
status: in_progress

phases:
  discovery:
    status: completed
EOF
cat > "$C12DIR3/.pas/workspace/proc/inst-c12/feedback/tester-c12.md" <<'EOF'
[OQI-01]
Target: agent:tester
Degraded: nothing important
Priority: LOW
EOF
echo "{\"cwd\":\"$C12DIR3\"}" | bash "$HOOKS_DIR/route-feedback.sh" >/dev/null 2>&1 || true
# Expect a file in the backlog with the host-id in its name
ROUTED=$(find "$C12DIR3/.pas/processes/proc/agents/tester/feedback/backlog" -name "*my-host-c12*" 2>/dev/null | head -1)
if [ -n "$ROUTED" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C12-3: routed filename includes host-id\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C12-3: no routed file with host-id found in backlog")
  printf "  ${RED}FAIL${RESET} C12-3: host-id not in filename\n"
  ls "$C12DIR3/.pas/processes/proc/agents/tester/feedback/backlog/" 2>&1 | head -3
fi
rm -rf "$C12DIR3"

# T-C12-4: resolve_origin_marketplace returns non-zero without registry
FAKE_HOME=$(mktemp -d)
if env CLAUDE_PLUGIN_ROOT="/some/path/.claude/plugins/cache/fake/pas/1.0.0" HOME="$FAKE_HOME" \
   bash -c "source '$HOOKS_DIR/lib/guards.sh' && resolve_origin_marketplace" >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  ERRORS+=("C12-4: expected non-zero exit when registry absent")
  printf "  ${RED}FAIL${RESET} C12-4: should fail with no registry\n"
else
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C12-4: resolve_origin_marketplace fails cleanly without registry\n"
fi
rm -rf "$FAKE_HOME"

# =========================================================================
# Section C16: Hook substrate concurrency cluster
# (#155, #156, #162, #173, #174 — see plugins/pas/hooks/changelog.md 1.4.1)
# =========================================================================
printf "\n${BOLD}13. C16 — concurrency cluster${RESET}\n"

# T-C16-1a: workspace.sh Pass 0 matches `current_session:` (regression for #155 fix)
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/inst-cs/feedback"
cat > "$C16DIR/.pas/workspace/proc/inst-cs/status.yaml" <<'EOF'
process: proc
instance: inst-cs
status: in_progress
current_session: deadbeef
EOF
RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$C16DIR/.pas/workspace' 'deadbeef'")
if echo "$RESULT" | grep -q "inst-cs/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-1a: Pass 0 matches current_session: field (regression)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-1a: current_session: match failed (got: $RESULT)")
  printf "  ${RED}FAIL${RESET} C16-1a (got: %s)\n" "$RESULT"
fi
rm -rf "$C16DIR"

# T-C16-1b: workspace.sh Pass 0 matches `session_id:` field (#155 fix)
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/inst-sid/feedback"
cat > "$C16DIR/.pas/workspace/proc/inst-sid/status.yaml" <<'EOF'
process: proc
instance: inst-sid
status: in_progress
session_id: cafebabe
EOF
RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$C16DIR/.pas/workspace' 'cafebabe'")
if echo "$RESULT" | grep -q "inst-sid/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-1b: Pass 0 matches session_id: field (#155)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-1b: session_id: match failed (got: $RESULT)")
  printf "  ${RED}FAIL${RESET} C16-1b (got: %s)\n" "$RESULT"
fi
rm -rf "$C16DIR"

# T-C16-1c: with neither field set, falls through to mtime (regression)
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/inst-noid/feedback"
cat > "$C16DIR/.pas/workspace/proc/inst-noid/status.yaml" <<'EOF'
process: proc
instance: inst-noid
status: in_progress
EOF
RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$C16DIR/.pas/workspace' 'nomatch1'")
if echo "$RESULT" | grep -q "inst-noid/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-1c: falls through to Pass 1 when no field matches\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-1c: Pass 1 fallback failed (got: $RESULT)")
  printf "  ${RED}FAIL${RESET} C16-1c (got: %s)\n" "$RESULT"
fi
rm -rf "$C16DIR"

# T-C16-2a: route-feedback warnings.log anchors to PAS_PROJECT_ROOT, not CWD
# When CWD is under .pas/workspace/<X>/, the old code created
# .pas/workspace/<X>/.pas/feedback/warnings.log (recursive). New code uses
# PAS_PROJECT_ROOT.
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/inst-cwd/feedback"
mkdir -p "$C16DIR/.pas/processes/proc/feedback/backlog"
cat > "$C16DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
cat > "$C16DIR/.pas/workspace/proc/inst-cwd/status.yaml" <<'EOF'
process: proc
instance: inst-cwd
status: in_progress
current_session: cwdtest1
EOF
# Write a feedback file with an UNKNOWN target so we trigger the warnings.log path
cat > "$C16DIR/.pas/workspace/proc/inst-cwd/feedback/orchestrator-cwdtest1.md" <<'EOF'
[OQI-99]
Target: bogus:nothing
Degraded: warnings-log smoke test
Priority: LOW
EOF
# Run hook with CWD set to PROJECT ROOT (this is what Claude Code passes); the
# bug manifested because route-feedback used $CWD literally even when guards
# resolved PAS_PROJECT_ROOT correctly.
echo "{\"cwd\":\"$C16DIR\",\"session_id\":\"cwdtest1xyz\"}" | bash "$HOOKS_DIR/route-feedback.sh" >/dev/null 2>&1 || true
if [ -f "$C16DIR/.pas/feedback/warnings.log" ] && [ ! -d "$C16DIR/.pas/workspace/proc/inst-cwd/.pas" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-2a: warnings.log anchors to PAS_PROJECT_ROOT (#156)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-2a: warnings.log not at expected path or recursive .pas/.pas/ created")
  printf "  ${RED}FAIL${RESET} C16-2a — log: $(ls $C16DIR/.pas/feedback/ 2>&1 | head -3) ; recursive: $(find $C16DIR -name '.pas' -type d 2>/dev/null | wc -l)\n"
fi
rm -rf "$C16DIR"

# T-C16-2b: Tier 3 process resolution uses PAS_PROJECT_ROOT (#156 issue 3)
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/inst-tier3/feedback"
mkdir -p "$C16DIR/.pas/processes/local-process/feedback/backlog"
cat > "$C16DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
cat > "$C16DIR/.pas/workspace/proc/inst-tier3/status.yaml" <<'EOF'
process: proc
instance: inst-tier3
status: in_progress
current_session: tier3xyz
EOF
cat > "$C16DIR/.pas/workspace/proc/inst-tier3/feedback/orchestrator-tier3xyz.md" <<'EOF'
[OQI-77]
Target: process:local-process
Degraded: tier3 smoke test
Priority: LOW
EOF
echo "{\"cwd\":\"$C16DIR\",\"session_id\":\"tier3xyzfull\"}" | bash "$HOOKS_DIR/route-feedback.sh" >/dev/null 2>&1 || true
ROUTED=$(find "$C16DIR/.pas/processes/local-process/feedback/backlog" -type f 2>/dev/null | head -1)
if [ -n "$ROUTED" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-2b: Tier 3 anchors to PAS_PROJECT_ROOT (#156)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-2b: Tier 3 routing did not land in backlog")
  printf "  ${RED}FAIL${RESET} C16-2b: signal not routed to local process backlog\n"
fi
rm -rf "$C16DIR"

# T-C16-3: SessionStart with two in_progress workspaces + fresh id leaves
# both untouched (no auto-bind). Belt-and-suspenders for #173.
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/A/feedback"
mkdir -p "$C16DIR/.pas/workspace/proc/B/feedback"
cat > "$C16DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
cat > "$C16DIR/.pas/workspace/proc/A/status.yaml" <<'EOF'
process: proc
instance: A
status: in_progress

phases:
  discovery:
    status: pending
EOF
cat > "$C16DIR/.pas/workspace/proc/B/status.yaml" <<'EOF'
process: proc
instance: B
status: in_progress

phases:
  discovery:
    status: pending
EOF
sleep 0.05
touch "$C16DIR/.pas/workspace/proc/B/status.yaml"  # B is mtime winner
A_BEFORE=$(stat -c %s "$C16DIR/.pas/workspace/proc/A/status.yaml")
B_BEFORE=$(stat -c %s "$C16DIR/.pas/workspace/proc/B/status.yaml")
echo "{\"cwd\":\"$C16DIR\",\"source\":\"startup\",\"session_id\":\"freshid1abcdef\"}" | bash "$HOOKS_DIR/pas-session-start.sh" >/dev/null 2>&1 || true
A_AFTER=$(stat -c %s "$C16DIR/.pas/workspace/proc/A/status.yaml")
B_AFTER=$(stat -c %s "$C16DIR/.pas/workspace/proc/B/status.yaml")
if [ "$A_BEFORE" = "$A_AFTER" ] && [ "$B_BEFORE" = "$B_AFTER" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-3: fresh session leaves both in_progress workspaces untouched (#173)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-3: fresh session modified status.yaml (A: $A_BEFORE→$A_AFTER, B: $B_BEFORE→$B_AFTER)")
  printf "  ${RED}FAIL${RESET} C16-3: fresh session modified workspace (A: %s→%s, B: %s→%s)\n" "$A_BEFORE" "$A_AFTER" "$B_BEFORE" "$B_AFTER"
fi
rm -rf "$C16DIR"

# T-C16-5a: Stop hook with binding match → gate fires normally (regression)
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/inst-bound/feedback"
cat > "$C16DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
cat > "$C16DIR/.pas/workspace/proc/inst-bound/status.yaml" <<'EOF'
process: proc
instance: inst-bound
status: in_progress
current_session: bound123

phases:
  discovery:
    status: completed
EOF
OUT=$(echo "{\"cwd\":\"$C16DIR\",\"stop_hook_active\":false,\"session_id\":\"bound123fullid\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" 2>&1 || true)
RC=$?
EXIT=$(echo "{\"cwd\":\"$C16DIR\",\"stop_hook_active\":false,\"session_id\":\"bound123fullid\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" >/dev/null 2>&1; echo $?)
if [ "$EXIT" = "2" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-5a: gate fires normally when session matches binding\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-5a: expected exit 2 when bound and feedback missing, got $EXIT")
  printf "  ${RED}FAIL${RESET} C16-5a (exit: %s)\n" "$EXIT"
fi
rm -rf "$C16DIR"

# T-C16-5b: Stop hook with session_id NOT matching resolved workspace
# (mtime-fallback misroute scenario) → exit 0 with stderr warning, do not block.
C16DIR=$(mktemp -d)
mkdir -p "$C16DIR/.pas/workspace/proc/inst-other/feedback"
cat > "$C16DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
# Workspace is in_progress and bound to a DIFFERENT session.
cat > "$C16DIR/.pas/workspace/proc/inst-other/status.yaml" <<'EOF'
process: proc
instance: inst-other
status: in_progress
current_session: other999

phases:
  discovery:
    status: completed
EOF
OUT=$(echo "{\"cwd\":\"$C16DIR\",\"stop_hook_active\":false,\"session_id\":\"mineabc1xyz\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" 2>&1)
EXIT=$(echo "{\"cwd\":\"$C16DIR\",\"stop_hook_active\":false,\"session_id\":\"mineabc1xyz\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" >/dev/null 2>&1; echo $?)
if [ "$EXIT" = "0" ] && echo "$OUT" | grep -q "does not bind session mineabc1"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C16-5b: cross-session misroute warns and skips gate (#162, #160)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C16-5b: expected exit 0 + warning, got exit $EXIT, out: $OUT")
  printf "  ${RED}FAIL${RESET} C16-5b (exit: %s)\n" "$EXIT"
fi
rm -rf "$C16DIR"

# =========================================================================
# Section C17: orchestrator-side binding & phase-advancement gate
# =========================================================================
# Cycle-17 cluster: cycle-16 closed the hook-side auto-bind path, but the
# bug recurred because orchestrators / consumer skills kept manually
# writing `current_session:` and appending to `sessions:` for fresh
# sessions in workspaces they weren't advancing. The phase-advancement
# check in verify-completion-gate.sh is a belt-and-suspenders defense.

printf "\n${BOLD}14. C17 — phase-advancement gate${RESET}\n"

# T-C17-1: binding matches AND every phase still pending → gate skipped.
# Simulates an orchestrator that wrote current_session: but never advanced
# any phase — exactly the offending pattern from pas-misrouted-and-migration-ts.
C17DIR=$(mktemp -d)
mkdir -p "$C17DIR/.pas/workspace/proc/inst-pa/feedback"
cat > "$C17DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
cat > "$C17DIR/.pas/workspace/proc/inst-pa/status.yaml" <<'EOF'
process: proc
instance: inst-pa
status: in_progress
current_session: c17abc12

phases:
  discovery:
    status: pending
  planning:
    status: pending
EOF
OUT=$(echo "{\"cwd\":\"$C17DIR\",\"stop_hook_active\":false,\"session_id\":\"c17abc12xyz\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" 2>&1)
EXIT=$(echo "{\"cwd\":\"$C17DIR\",\"stop_hook_active\":false,\"session_id\":\"c17abc12xyz\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" >/dev/null 2>&1; echo $?)
if [ "$EXIT" = "0" ] && echo "$OUT" | grep -q "no advanced phases"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C17-1: binding matches + all phases pending → gate skipped (cycle-17)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C17-1: expected exit 0 + 'no advanced phases' warning, got exit $EXIT, out: $OUT")
  printf "  ${RED}FAIL${RESET} C17-1 (exit: %s)\n" "$EXIT"
fi
rm -rf "$C17DIR"

# T-C17-2: binding matches AND at least one phase completed AND no feedback
# → gate fires. Confirms the new check did NOT break the normal path where
# real work happened and feedback is genuinely missing.
C17DIR=$(mktemp -d)
mkdir -p "$C17DIR/.pas/workspace/proc/inst-pb/feedback"
cat > "$C17DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
cat > "$C17DIR/.pas/workspace/proc/inst-pb/status.yaml" <<'EOF'
process: proc
instance: inst-pb
status: in_progress
current_session: c17def34

phases:
  discovery:
    status: completed
  planning:
    status: completed
EOF
EXIT=$(echo "{\"cwd\":\"$C17DIR\",\"stop_hook_active\":false,\"session_id\":\"c17def34xyz\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" >/dev/null 2>&1; echo $?)
if [ "$EXIT" = "2" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C17-2: binding matches + phases completed + no feedback → gate fires\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C17-2: expected exit 2, got exit $EXIT")
  printf "  ${RED}FAIL${RESET} C17-2 (exit: %s)\n" "$EXIT"
fi
rm -rf "$C17DIR"

# T-C17-3: binding matches AND one phase in_progress + one pending AND no
# feedback → gate skipped (pending short-circuit at L59 of verify-completion-gate.sh
# fires; this also asserts the new phase-advancement check let it through).
C17DIR=$(mktemp -d)
mkdir -p "$C17DIR/.pas/workspace/proc/inst-pc/feedback"
cat > "$C17DIR/.pas/config.yaml" <<'EOF'
feedback: enabled
EOF
cat > "$C17DIR/.pas/workspace/proc/inst-pc/status.yaml" <<'EOF'
process: proc
instance: inst-pc
status: in_progress
current_session: c17ghi56

phases:
  discovery:
    status: in_progress
  planning:
    status: pending
EOF
EXIT=$(echo "{\"cwd\":\"$C17DIR\",\"stop_hook_active\":false,\"session_id\":\"c17ghi56xyz\"}" | bash "$HOOKS_DIR/verify-completion-gate.sh" >/dev/null 2>&1; echo $?)
if [ "$EXIT" = "0" ]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} C17-3: binding matches + mid-cycle (one in_progress, one pending) → gate skipped\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("C17-3: expected exit 0, got exit $EXIT")
  printf "  ${RED}FAIL${RESET} C17-3 (exit: %s)\n" "$EXIT"
fi
rm -rf "$C17DIR"

# =========================================================================
# Summary
# =========================================================================

printf "\n${BOLD}=== Results ===${RESET}\n"
printf "  ${GREEN}Passed: %d${RESET}\n" "$PASS"
printf "  ${RED}Failed: %d${RESET}\n" "$FAIL"

if [ ${#ERRORS[@]} -gt 0 ]; then
  printf "\n${BOLD}Failures:${RESET}\n"
  for err in "${ERRORS[@]}"; do
    printf "  - %s\n" "$err"
  done
fi

printf "\nTotal: %d tests\n" $((PASS + FAIL))

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
