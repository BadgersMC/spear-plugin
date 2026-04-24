#!/usr/bin/env bats
# tests/hooks/reconcile.bats — TDD-17: stale-state reconciliation (REQ-049 + REQ-101)
#
# Tests the reconcile_state function and its integration into session-start.
# Uses the stale-state fixture: tests/hooks/fixtures/stale-state/
#   - docs/requirements.md  (stub)
#   - docs/tasks.md         (stub)
#   - .claude/spear-state.json  (seeded green)
#   - bin/gradle            (fake — always exits 1 / red)

load test_helper

FIXTURE_DIR="${SPEAR_REPO_ROOT}/tests/hooks/fixtures/stale-state"

# ── Helper: copy the stale-state fixture into a fresh temp project ───────────
# After this call, $BATS_TEST_TMPDIR/project is a self-contained SPEAR project
# with the fixture files, and CWD is that project dir.
setup_stale_state_fixture() {
  local dest="${BATS_TEST_TMPDIR}/project"
  cp -r "$FIXTURE_DIR/." "$dest"
  # Ensure fake gradle is executable after copy
  chmod +x "$dest/bin/gradle"
  cd "$dest"
}

# ── Helper: run hook in Claude Code mode from CWD ───────────────────────────
run_claude_hook() {
  CLAUDE_PLUGIN_ROOT=/fake CURSOR_PLUGIN_ROOT= run bash "$HOOK_BIN"
}

# ── Test 1: no state file → no notice, no error ──────────────────────────────
@test "reconcile: no state file → no notice, no error" {
  setup_tempdir
  # Minimal SPEAR project with NO spear-state.json
  mkdir -p docs
  echo "# stub" > docs/requirements.md
  echo "- [ ] T-001 example" > docs/tasks.md

  run_claude_hook

  [ "$status" -eq 0 ]

  # Must not mention reconciliation in output
  [[ "$output" != *"RECONCILE"* ]]
  [[ "$output" != *"state corrected"* ]]
}

# ── Test 2: stored green, observed red → corrects to red and emits notice ────
@test "reconcile: stored green, observed red → corrects to red and notices" {
  setup_stale_state_fixture
  # Prepend fixture's bin/ to PATH so 'gradle' resolves to the fake red runner
  export PATH="${BATS_TEST_TMPDIR}/project/bin:${PATH}"
  export SPEAR_TEST_RUNNER="${BATS_TEST_TMPDIR}/project/bin/gradle"

  run_claude_hook

  [ "$status" -eq 0 ]

  # State file testStatus must now be "red"
  local new_status
  new_status=$(jq -r '.testStatus' .claude/spear-state.json)
  [ "$new_status" = "red" ]

  # additionalContext in output must mention the correction
  local ctx
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"state corrected"* ]] || [[ "$ctx" == *"Notice"* ]]
  [[ "$ctx" == *"green"* ]]
}

# ── Test 3: stored matches observed → no correction, no notice ───────────────
@test "reconcile: stored matches observed → no correction, no notice" {
  setup_stale_state_fixture
  # Seed the state as "red" so it matches the fake gradle's exit 1
  jq '.testStatus = "red"' .claude/spear-state.json > .claude/spear-state.json.tmp
  mv .claude/spear-state.json.tmp .claude/spear-state.json

  export PATH="${BATS_TEST_TMPDIR}/project/bin:${PATH}"
  export SPEAR_TEST_RUNNER="${BATS_TEST_TMPDIR}/project/bin/gradle"

  run_claude_hook

  [ "$status" -eq 0 ]

  # testStatus must remain "red" — no correction applied
  local new_status
  new_status=$(jq -r '.testStatus' .claude/spear-state.json)
  [ "$new_status" = "red" ]

  # Payload must NOT contain "state corrected"
  local ctx
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" != *"state corrected"* ]]
}

# ── Test 4: no runner available → skip silently ──────────────────────────────
# When SPEAR_TEST_RUNNER is unset/empty AND gradle is not on PATH,
# reconciliation is skipped: exit 0, state unchanged, no crash.
@test "reconcile: when no runner available → skip silently" {
  setup_stale_state_fixture
  # Clear PATH of any gradle — remove fixture bin and restrict to minimum
  export PATH="/usr/bin:/bin"
  unset SPEAR_TEST_RUNNER

  run_claude_hook

  [ "$status" -eq 0 ]

  # State file testStatus must remain "green" (unchanged)
  # Use absolute jq path since PATH is restricted in this test
  local status_val
  status_val=$("$HOME/bin/jq" -r '.testStatus' .claude/spear-state.json)
  [ "$status_val" = "green" ]

  # Payload must not contain "state corrected"
  # Use absolute jq path since PATH is restricted in this test
  local ctx
  ctx=$(echo "$output" | "$HOME/bin/jq" -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" != *"state corrected"* ]]
}
