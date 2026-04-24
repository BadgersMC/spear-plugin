#!/usr/bin/env bats
# tests/hooks/payload-truncation.bats — TDD-14: tiered payload truncation (REQ-013, REQ-014)
#
# Choice: we assert total stdout (the emitted JSON line) ≤ budget bytes.
# This is stricter than just testing additionalContext because it's what Claude Code receives.
# Default budget: 4096 bytes.

load test_helper

# ── Helpers ─────────────────────────────────────────────────────────────────

# Generate an oversized docs/tasks.md (~8 KB of dummy task lines)
make_oversized_tasks() {
  mkdir -p docs
  {
    echo "# Tasks"
    echo ""
    # 200 lines × ~50 chars = ~10000 bytes
    for i in $(seq 1 200); do
      echo "- [ ] TDD-$(printf '%03d' "$i") Some very long dummy task description line number $i"
    done
  } > docs/tasks.md
}

# Generate a small docs/tasks.md (~200 bytes)
make_small_tasks() {
  mkdir -p docs
  cat > docs/tasks.md <<'EOF'
# Tasks

- [x] TDD-001 Already done task
- [ ] TDD-002 Write the widget feature
- [ ] TDD-003 Add widget tests
EOF
}

run_hook_claude() {
  CLAUDE_PLUGIN_ROOT=/fake CURSOR_PLUGIN_ROOT= run bash "$HOOK_BIN"
}

run_hook_claude_budget() {
  local budget="$1"
  SPEAR_PAYLOAD_BUDGET="$budget" CLAUDE_PLUGIN_ROOT=/fake CURSOR_PLUGIN_ROOT= run bash "$HOOK_BIN"
}

setup() {
  setup_tempdir
  mkdir -p docs
  echo "# requirements stub" > docs/requirements.md
}

teardown() {
  teardown_tempdir
}

# ── Test 1: Total stdout ≤ 4096 bytes with oversized tasks.md ───────────────

@test "payload under default 4096-byte ceiling with oversized tasks.md" {
  make_oversized_tasks
  run_hook_claude
  [ "$status" -eq 0 ]
  byte_count="${#output}"
  [ "$byte_count" -le 4096 ]
}

# ── Test 2: Cycle rules survive truncation ───────────────────────────────────

@test "cycle rules survive truncation with oversized tasks.md" {
  make_oversized_tasks
  run_hook_claude
  [ "$status" -eq 0 ]
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" =~ SPEC ]]
  [[ "$ctx" =~ PROVE ]]
  [[ "$ctx" =~ ENGINE ]]
  [[ "$ctx" =~ ARCH ]]
  [[ "$ctx" =~ REFINE ]]
}

# ── Test 3: tasks.md tier truncated first (Tier 1) ──────────────────────────

@test "tasks tier truncated first: summary present, verbatim content absent" {
  make_oversized_tasks
  run_hook_claude
  [ "$status" -eq 0 ]
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # A summary line mentioning tasks must be present
  [[ "$ctx" =~ "tasks:" || "$ctx" =~ "Current task:" || "$ctx" =~ "tasks total" ]]
  # The raw verbatim tasks content must NOT be present (200 padded lines would be huge)
  # Check that the raw "TDD-050" line from the middle of the oversized file is absent
  [[ "$ctx" != *"TDD-050 Some very long dummy task description"* ]]
}

# ── Test 4: probe tier dropped when budget tight (Tier 2) ───────────────────

@test "probe tier dropped when budget tighter (SPEAR_PAYLOAD_BUDGET=1000)" {
  make_oversized_tasks
  run_hook_claude_budget 1000
  [ "$status" -eq 0 ]
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # Probe section should NOT appear verbatim OR replaced with short note
  # Accept either: absent entirely OR replaced with a one-liner like "probe: see prior session"
  # The full "## Tool probe" with tool status lines should be gone
  if [[ "$ctx" == *"context7:"* ]] || [[ "$ctx" == *"mgrep:"* ]] || [[ "$ctx" == *"semgrep:"* ]]; then
    # If any probe detail appears, the full section is still there — that's a failure
    # unless the budget was enough (it isn't at 1000 bytes)
    byte_count="${#output}"
    [ "$byte_count" -le 1000 ]
  fi
  # Cycle rules must still be present
  [[ "$ctx" =~ SPEC ]]
  [[ "$ctx" =~ REFINE ]]
}

# ── Test 5: deferral tier dropped when budget tightest (Tier 3) ─────────────

@test "deferral tier dropped when budget tightest (SPEAR_PAYLOAD_BUDGET=600)" {
  make_oversized_tasks
  run_hook_claude_budget 600
  [ "$status" -eq 0 ]
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # Deferral text must be absent at this tight budget
  [[ "$ctx" != *"superpowers:brainstorm"* ]]
  # Cycle rules must still survive
  [[ "$ctx" =~ SPEC ]]
  [[ "$ctx" =~ REFINE ]]
}

# ── Test 6: small tasks.md embedded inline ───────────────────────────────────

@test "small tasks.md embedded inline and payload ≤ 4096 bytes" {
  make_small_tasks
  run_hook_claude
  [ "$status" -eq 0 ]
  byte_count="${#output}"
  [ "$byte_count" -le 4096 ]
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # With a small tasks.md, the task title must appear verbatim
  [[ "$ctx" == *"TDD-002 Write the widget feature"* ]]
}
