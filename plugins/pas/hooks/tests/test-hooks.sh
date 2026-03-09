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

# --- Setup test environment ---

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR" /tmp/test-hook-stdout /tmp/test-hook-stderr' EXIT

# Create PAS config
cat > "$TESTDIR/pas-config.yaml" <<'EOF'
feedback: enabled
feedback_disabled_at: ~
EOF

# Create workspace with in_progress status
mkdir -p "$TESTDIR/workspace/test/cycle-1/feedback"
cat > "$TESTDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
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
  0 "session-start: no pas-config.yaml"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$NOPADIR\",\"stop_hook_active\":false,\"session_id\":\"test1234abcd\"}" \
  0 "completion-gate: no pas-config.yaml"

run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$NOPADIR\",\"task_subject\":\"[PAS] Self-evaluation\"}" \
  0 "task-completion: no pas-config.yaml"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$NOPADIR\",\"agent_id\":\"test-agent\"}" \
  0 "check-self-eval: no pas-config.yaml"

run_hook "route-feedback.sh" \
  "{\"cwd\":\"$NOPADIR\"}" \
  0 "route-feedback: no pas-config.yaml"

# =========================================================================
# Section 2: workspace.sh — in_progress preference (C1 regression)
# =========================================================================

printf "\n${BOLD}2. Workspace resolution — in_progress preference (C1)${RESET}\n"

# Create a second workspace that is completed (more recent mtime)
mkdir -p "$TESTDIR/workspace/test/cycle-0/feedback"
cat > "$TESTDIR/workspace/test/cycle-0/status.yaml" <<'EOF'
process: test
instance: cycle-0
started_at: 2026-03-09T10:00:00+00:00
completed_at: 2026-03-09T18:00:00+00:00
status: completed
EOF
# Touch completed workspace to make it more recent
sleep 0.1
touch "$TESTDIR/workspace/test/cycle-0/status.yaml"

# Source workspace.sh and test
RESULT=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$TESTDIR/workspace'")
if echo "$RESULT" | grep -q "cycle-1/status.yaml"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} workspace resolution prefers in_progress over completed\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("workspace resolution: got $RESULT instead of cycle-1")
  printf "  ${RED}FAIL${RESET} workspace resolution (got: %s)\n" "$RESULT"
fi

# Test fallback: when no in_progress workspace exists, fall back to most recent
mkdir -p "$TESTDIR/workspace-fallback/old/feedback"
cat > "$TESTDIR/workspace-fallback/old/status.yaml" <<'EOF'
process: test
instance: old
status: completed
EOF

RESULT2=$(bash -c "source '$HOOKS_DIR/lib/workspace.sh'; find_active_workspace_status '$TESTDIR/workspace-fallback'")
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

assert_file_contains "$TESTDIR/workspace/test/cycle-1/status.yaml" \
  "current_session: abc12345" "session-start: writes current_session to status.yaml"

assert_file_contains "$TESTDIR/workspace/test/cycle-1/status.yaml" \
  "id: abc12345" "session-start: appends session to sessions list"

# =========================================================================
# Section 4: verify-completion-gate.sh
# =========================================================================

printf "\n${BOLD}4. verify-completion-gate.sh${RESET}\n"

# 4a: Pending phases → exit 0 (don't block mid-work)
run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: pending phases → exit 0"

# 4b: All completed, no feedback → exit 2
cat > "$TESTDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
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
echo "No issues detected." > "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: session feedback exists → exit 0"

# 4d: Feedback from DIFFERENT session → exit 2
rm "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"
echo "No issues detected." > "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-previous.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  2 "completion-gate: wrong session feedback → exit 2"

# 4e: stop_hook_active → exit 0 (loop prevention)
run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":true,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: stop_hook_active → exit 0 (loop prevention)"

# 4f: Completed workspace → exit 0 (C2 regression — Issue #23)
cat > "$TESTDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
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
cat > "$TESTDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
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
echo "No issues detected." > "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  2 "completion-gate: missing agent feedback → exit 2 (Issue #19)"

assert_stderr_contains "Agent self-evaluation missing" \
  "completion-gate: stderr names missing agents (Issue #19)"

# Add agent feedback → exit 0
echo "No issues detected." > "$TESTDIR/workspace/test/cycle-1/feedback/framework-architect.md"
echo "No issues detected." > "$TESTDIR/workspace/test/cycle-1/feedback/dx-specialist.md"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$TESTDIR\",\"stop_hook_active\":false,\"session_id\":\"abc12345xyz\"}" \
  0 "completion-gate: all agent feedback present → exit 0 (Issue #19)"

# Clean up agent feedback files
rm -f "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"
rm -f "$TESTDIR/workspace/test/cycle-1/feedback/framework-architect.md"
rm -f "$TESTDIR/workspace/test/cycle-1/feedback/dx-specialist.md"

# =========================================================================
# Section 5: verify-task-completion.sh
# =========================================================================

printf "\n${BOLD}5. verify-task-completion.sh${RESET}\n"

# Restore in_progress status for task tests
cat > "$TESTDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
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
rm -f "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-previous.md"

# 5a: Self-eval task without feedback → exit 2
run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"[PAS] Self-evaluation\"}" \
  2 "task-completion: self-eval without feedback → exit 2"

assert_stderr_contains "Cannot complete" "task-completion: stderr shows blocker message"

# 5b: Self-eval task with feedback → exit 0
echo "No issues detected." > "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md"

run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"[PAS] Self-evaluation\"}" \
  0 "task-completion: self-eval with feedback → exit 0"

# 5c: Finalize task without completed status → exit 2
run_hook "verify-task-completion.sh" \
  "{\"cwd\":\"$TESTDIR\",\"task_subject\":\"[PAS] Finalize status\"}" \
  2 "task-completion: finalize without completed status → exit 2"

# 5d: Finalize task with completed status → exit 0
cat > "$TESTDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
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
cat > "$TESTDIR/workspace/test/cycle-1/status.yaml" <<'EOF'
process: test
instance: cycle-1
status: in_progress

phases:
  discovery:
    status: completed
EOF

# 6a: Agent with feedback file → exit 0
echo "No issues detected." > "$TESTDIR/workspace/test/cycle-1/feedback/test-agent.md"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$TESTDIR\",\"agent_id\":\"test-agent\"}" \
  0 "check-self-eval: agent feedback exists → exit 0"

# 6b: Agent without feedback → exit 2
rm "$TESTDIR/workspace/test/cycle-1/feedback/test-agent.md"

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$TESTDIR\",\"agent_id\":\"test-agent\"}" \
  2 "check-self-eval: agent feedback missing → exit 2"

assert_stderr_contains "SELF-EVALUATION MISSING" "check-self-eval: stderr shows missing message"

# 6c: Feedback disabled → exit 0
cat > "$TESTDIR/pas-config.yaml" <<'EOF'
feedback: disabled
EOF

run_hook "check-self-eval.sh" \
  "{\"cwd\":\"$TESTDIR\",\"agent_id\":\"test-agent\"}" \
  0 "check-self-eval: feedback disabled → exit 0"

# Restore feedback enabled
cat > "$TESTDIR/pas-config.yaml" <<'EOF'
feedback: enabled
feedback_disabled_at: ~
EOF

# =========================================================================
# Section 7: route-feedback.sh
# =========================================================================

printf "\n${BOLD}7. route-feedback.sh${RESET}\n"

# 7a: Route signals from feedback file, preserve file, mark as routed
rm -f "$TESTDIR/workspace/test/cycle-1/feedback/"*.md
rm -f "$TESTDIR/workspace/test/cycle-1/feedback/"*.routed

cat > "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md" <<'EOF'
[OQI-01]
Target: process:test
Degraded: Test signal for routing
Priority: LOW
EOF

# Create the process feedback dir for routing target
mkdir -p "$TESTDIR/processes/test/feedback/backlog"

run_hook "route-feedback.sh" \
  "{\"cwd\":\"$TESTDIR\"}" \
  0 "route-feedback: routes signals → exit 0"

assert_file_exists "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md" \
  "route-feedback: feedback file preserved (not deleted)"

assert_file_exists "$TESTDIR/workspace/test/cycle-1/feedback/orchestrator-abc12345.md.routed" \
  "route-feedback: .routed marker created"

# 7b: Second run skips already-routed files
BEFORE_COUNT=$(find "$TESTDIR/processes/test/feedback/backlog" -name "*.md" 2>/dev/null | wc -l)

run_hook "route-feedback.sh" \
  "{\"cwd\":\"$TESTDIR\"}" \
  0 "route-feedback: second run exits 0"

AFTER_COUNT=$(find "$TESTDIR/processes/test/feedback/backlog" -name "*.md" 2>/dev/null | wc -l)
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

printf "\n${BOLD}8. pas-create-process — lifecycle ref + --force safety${RESET}\n"

CREATE_SCRIPT="$HOOKS_DIR/../processes/pas/agents/orchestrator/skills/creating-processes/scripts/pas-create-process"
GEN_DIR=$(mktemp -d)

# 8a: Generated process includes lifecycle section
bash "$CREATE_SCRIPT" \
  --name test-proc \
  --goal "Test process" \
  --orchestration solo \
  --phase "work:orchestrator:input:output:user-approval" \
  --input "data:Test input" \
  --base-dir "$GEN_DIR" 2>/dev/null

if grep -q "library/orchestration/lifecycle.md" "$GEN_DIR/processes/test-proc/process.md"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} pas-create-process: process.md references lifecycle.md (C3)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("process.md missing lifecycle.md reference")
  printf "  ${RED}FAIL${RESET} pas-create-process: process.md missing lifecycle.md reference\n"
fi

# 8b: Generated thin launcher includes lifecycle reference
if grep -q "lifecycle.md" "$GEN_DIR/.claude/skills/test-proc/SKILL.md"; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${RESET} pas-create-process: thin launcher references lifecycle.md (C3)\n"
else
  FAIL=$((FAIL + 1))
  ERRORS+=("thin launcher missing lifecycle.md reference")
  printf "  ${RED}FAIL${RESET} pas-create-process: thin launcher missing lifecycle.md reference\n"
fi

# 8c: --force preserves reference/ directory (C4)
mkdir -p "$GEN_DIR/processes/test-proc/reference/source"
echo "precious data" > "$GEN_DIR/processes/test-proc/reference/source/material.txt"

bash "$CREATE_SCRIPT" \
  --name test-proc \
  --goal "Test process" \
  --orchestration solo \
  --phase "work:orchestrator:input:output:user-approval" \
  --input "data:Test input" \
  --base-dir "$GEN_DIR" \
  --force 2>/dev/null

if [ -f "$GEN_DIR/processes/test-proc/reference/source/material.txt" ]; then
  CONTENT=$(cat "$GEN_DIR/processes/test-proc/reference/source/material.txt")
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
# Section 9: Edge cases
# =========================================================================

printf "\n${BOLD}9. Edge cases${RESET}\n"

# 9a: Missing session_id — hooks should handle gracefully
run_hook "pas-session-start.sh" \
  "{\"cwd\":\"$TESTDIR\",\"source\":\"startup\"}" \
  0 "edge-case: missing session_id → session-start exits 0"

# 9b: Empty workspace directory — no status.yaml found
EMPTYDIR=$(mktemp -d)
cat > "$EMPTYDIR/pas-config.yaml" <<'EOF'
feedback: enabled
EOF
mkdir -p "$EMPTYDIR/workspace"

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$EMPTYDIR\",\"stop_hook_active\":false,\"session_id\":\"test1234\"}" \
  0 "edge-case: empty workspace dir → exit 0"

rm -rf "$EMPTYDIR"

# 9c: No workspace directory at all
NOWSDIR=$(mktemp -d)
cat > "$NOWSDIR/pas-config.yaml" <<'EOF'
feedback: enabled
EOF

run_hook "verify-completion-gate.sh" \
  "{\"cwd\":\"$NOWSDIR\",\"stop_hook_active\":false,\"session_id\":\"test1234\"}" \
  0 "edge-case: no workspace dir → exit 0"

rm -rf "$NOWSDIR"

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
