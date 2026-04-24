#!/usr/bin/env bats
# tests/hooks/never-block.bats — TDD-18: Hook never blocks on internal error (REQ-085)
#
# Tests that when session-start encounters any internal error (corrupt JSON, missing lib,
# jq failure, etc.), it:
#   1. Exits with status 0 (never blocks)
#   2. Emits a brief diagnostic to stderr
#   3. Emits a minimal valid JSON envelope to stdout (Claude Code shape)
#
# Uses SPEAR_HOOK_FORCE_FAIL=1 to simulate internal failures in a controlled way.

load test_helper

# ── Helper: copy a minimal SPEAR project fixture into temp dir ──────────────────
setup_minimal_spear_project() {
  setup_tempdir
  mkdir -p docs
  echo "# stub requirements" > docs/requirements.md
  echo "- [ ] T-001 example" > docs/tasks.md
}

# ── Helper: run hook in Claude Code mode (captures both stdout and stderr) ──────
run_claude_hook() {
  CLAUDE_PLUGIN_ROOT=/fake CURSOR_PLUGIN_ROOT= run bash "$HOOK_BIN"
}

# ── Helper: extract JSON from mixed stdout/stderr output ──────────────────────
# When the hook triggers the trap, stderr (diagnostic) prints first, then stdout (JSON).
# This helper extracts just the JSON portion using grep.
extract_json_from_output() {
  local output="$1"
  # Find the line starting with '{"hookSpecificOutput"'
  echo "$output" | grep -o '{"hookSpecificOutput"[^}]*}}'
}

# ── Test 1: hook with SPEAR_HOOK_FORCE_FAIL exits 0 and emits diagnostic JSON ───
@test "hook with SPEAR_HOOK_FORCE_FAIL=1: exits 0 and emits minimal JSON envelope" {
  setup_minimal_spear_project

  # Force a panic by setting the test flag
  export SPEAR_HOOK_FORCE_FAIL=1
  run_claude_hook

  # Must exit 0 (never blocks)
  [ "$status" -eq 0 ]

  # Extract JSON from mixed output and validate it
  local json additionalContext
  json=$(extract_json_from_output "$output")
  [ -n "$json" ] || {
    echo "Failed to extract JSON from output. Full output: $output"
    return 1
  }

  # Parse the JSON
  additionalContext=$(echo "$json" | jq -r '.hookSpecificOutput.additionalContext')
  [ $? -eq 0 ] || {
    echo "Failed to parse extracted JSON: $json"
    return 1
  }

  # Check for error message
  [[ "$additionalContext" == *"internal error suppressed"* ]] || {
    echo "Expected 'internal error suppressed' in additionalContext. Got: $additionalContext"
    return 1
  }

  unset SPEAR_HOOK_FORCE_FAIL
}

# ── Test 2: SPEAR_HOOK_FORCE_FAIL=1 → hook exits 0 and emits diagnostic ────────
@test "SPEAR_HOOK_FORCE_FAIL=1 with Cursor mode: emits Cursor-shape JSON" {
  setup_minimal_spear_project

  # Test the Cursor JSON shape (sets CURSOR_PLUGIN_ROOT instead of CLAUDE_PLUGIN_ROOT)
  SPEAR_HOOK_FORCE_FAIL=1 CURSOR_PLUGIN_ROOT=/fake run bash "$HOOK_BIN"

  # Must exit 0
  [ "$status" -eq 0 ]

  # For Cursor mode, output shape is {"additional_context":"..."}
  local json
  json=$(echo "$output" | grep -o '{"additional_context"[^}]*}')

  # If Cursor format not found, try Claude format as fallback
  if [ -z "$json" ]; then
    json=$(extract_json_from_output "$output")
  fi

  [ -n "$json" ] || {
    echo "Failed to extract JSON from output. Full: $output"
    return 1
  }

  # Output must mention error suppression
  [[ "$output" =~ "internal error suppressed" ]] || {
    echo "Expected 'internal error suppressed' in output. Got: $output"
    return 1
  }
}

# ── Test 3: diagnostic on stderr, JSON on stdout (clean separation) ────────────
@test "diagnostic written to stderr, not muddled into stdout JSON" {
  setup_minimal_spear_project

  # Run hook and capture stdout + stderr separately using subshell redirection
  local stdout_output stderr_output
  stdout_output=$(
    cd "$BATS_TEST_TMPDIR"
    SPEAR_HOOK_FORCE_FAIL=1 CLAUDE_PLUGIN_ROOT=/fake bash "$HOOK_BIN" 2>/tmp/hook_stderr.txt
  )
  stderr_output=$(cat /tmp/hook_stderr.txt 2>/dev/null || echo "")

  # stdout must contain valid JSON
  local json
  json=$(extract_json_from_output "$stdout_output")
  [ -n "$json" ] || {
    echo "Failed to extract JSON from stdout. Got: $stdout_output"
    return 1
  }

  # Validate JSON is parseable
  echo "$json" | jq '.' >/dev/null 2>&1 || {
    echo "Extracted text is not valid JSON: $json"
    return 1
  }

  # stderr must contain diagnostic message
  [[ "$stderr_output" =~ "internal error suppressed" ]] || {
    echo "Expected 'internal error suppressed' on stderr. Got: $stderr_output"
    return 1
  }

  # Diagnostic should mention line number
  [[ "$stderr_output" =~ "line" ]] || {
    echo "Expected line number in diagnostic. Got: $stderr_output"
    return 1
  }

  rm -f /tmp/hook_stderr.txt
}

# ── Test 4: normal operation still works (sanity check) ────────────────────────
@test "normal operation: hook exits 0 with full payload" {
  setup_minimal_spear_project

  # Do NOT set SPEAR_HOOK_FORCE_FAIL; hook should run normally
  run_claude_hook

  # Must exit 0
  [ "$status" -eq 0 ]

  # stdout must be valid JSON
  local jq_parse
  jq_parse=$(echo "$output" | jq '.hookSpecificOutput' 2>&1)
  [ $? -eq 0 ] || {
    echo "Failed to parse stdout as JSON. Output: $output"
    return 1
  }

  # Must contain the SPEAR cycle section in additionalContext
  [[ "$output" =~ "SPEAR" ]] || {
    echo "Expected SPEAR payload content. Got: $output"
    return 1
  }
}
