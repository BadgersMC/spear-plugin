#!/usr/bin/env bash
#
# plugins/spear/hooks/lib/reconcile.sh — Stale-state reconciliation.
#
# Provides:
#   reconcile_state
#     Reads .claude/spear-state.json (relative to $PWD).
#     If testFile + testName + testStatus are all present:
#       - Determines the test runner via $SPEAR_TEST_RUNNER (default: "gradle").
#       - If runner is not executable/available, skips silently.
#       - Runs: <runner> test --tests <testName>
#         exit 0 → observed=green, non-zero → observed=red.
#       - If observed != stored: corrects testStatus + lastUpdated in state file,
#         echoes a RECONCILE_NOTICE line to stdout.
#     Echoes empty string if no correction needed.
#     Never exits non-zero — internal failures are swallowed silently.
#
# REQ-049: stale-state reconciliation on session-start.
# REQ-101: stale-state fixture with stub gradle returning red.

reconcile_state() {
  local state_file=".claude/spear-state.json"

  # No state file → nothing to do
  if [ ! -f "$state_file" ]; then
    echo ""
    return 0
  fi

  # Read required fields from state
  local test_file test_name stored_status
  test_file=$(jq -r '.testFile // ""' "$state_file" 2>/dev/null || echo "")
  test_name=$(jq -r '.testName // ""' "$state_file" 2>/dev/null || echo "")
  stored_status=$(jq -r '.testStatus // ""' "$state_file" 2>/dev/null || echo "")

  # All three fields must be present
  if [ -z "$test_file" ] || [ -z "$test_name" ] || [ -z "$stored_status" ]; then
    echo ""
    return 0
  fi

  # Determine runner — use $SPEAR_TEST_RUNNER if set, otherwise look for gradle
  local runner="${SPEAR_TEST_RUNNER:-}"
  if [ -z "$runner" ]; then
    # Try to find gradle on PATH
    if command -v gradle >/dev/null 2>&1; then
      runner="gradle"
    elif command -v gradlew >/dev/null 2>&1; then
      runner="gradlew"
    else
      # No runner detected — skip silently
      echo "reconcile: no runner detected; status unchanged" >&2
      echo ""
      return 0
    fi
  fi

  # Verify runner is executable
  if ! command -v "$runner" >/dev/null 2>&1; then
    # Runner not on PATH — skip silently
    echo ""
    return 0
  fi

  # Run the test and capture exit code
  local observed_status
  if "$runner" test --tests "$test_name" >/dev/null 2>&1; then
    observed_status="green"
  else
    observed_status="red"
  fi

  # Compare observed vs stored
  if [ "$observed_status" = "$stored_status" ]; then
    # No discrepancy — no action needed
    echo ""
    return 0
  fi

  # Discrepancy detected — correct the state file
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")

  # Update only testStatus and lastUpdated, preserving all other fields
  local tmp_file="${state_file}.reconcile.tmp"
  jq --arg s "$observed_status" --arg t "$now" \
    '.testStatus = $s | .lastUpdated = $t' \
    "$state_file" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$state_file" || {
    # jq update failed — leave state unchanged, still emit notice
    rm -f "$tmp_file"
  }

  # Emit notice to stdout (consumed by session-start for inclusion in payload)
  echo "state corrected: testStatus ${stored_status} → ${observed_status} (${test_name})"
}
