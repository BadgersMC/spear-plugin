#!/usr/bin/env bats

# Tests for probe_tools function (REQ-021, REQ-022)
# Validates tool availability detection with caching

setup() {
  # Source the probe library under test
  source "plugins/spear/hooks/lib/probe.sh"
}

# Test 1: None available — all env vars unset, PATH=/dev/null
@test "probe_tools: none available when all env vars unset and PATH empty" {
  unset SPEAR_PROBE_CONTEXT7 SPEAR_PROBE_MGREP SPEAR_PROBE_SEMGREP
  unset _SPEAR_PROBE_DONE _SPEAR_PROBE_OUTPUT

  # Block access to any real semgrep binary (subshell so PATH change doesn't leak to teardown)
  output=$(PATH="/dev/null" probe_tools)

  # All three should show unavailable
  [[ "$output" == *"context7: unavailable"* ]] || {
    echo "Expected 'context7: unavailable' in output, got:"
    echo "$output"
    false
  }
  [[ "$output" == *"mgrep: unavailable"* ]] || {
    echo "Expected 'mgrep: unavailable' in output, got:"
    echo "$output"
    false
  }
  [[ "$output" == *"semgrep: unavailable"* ]] || {
    echo "Expected 'semgrep: unavailable' in output, got:"
    echo "$output"
    false
  }
}

# Test 2: All available — all env vars set to "1"
@test "probe_tools: all available when all env vars are 1" {
  unset _SPEAR_PROBE_DONE _SPEAR_PROBE_OUTPUT

  export SPEAR_PROBE_CONTEXT7="1"
  export SPEAR_PROBE_MGREP="1"
  export SPEAR_PROBE_SEMGREP="1"

  output=$(probe_tools)

  [[ "$output" == *"context7: available"* ]] || {
    echo "Expected 'context7: available' in output, got:"
    echo "$output"
    false
  }
  [[ "$output" == *"mgrep: available"* ]] || {
    echo "Expected 'mgrep: available' in output, got:"
    echo "$output"
    false
  }
  [[ "$output" == *"semgrep: available"* ]] || {
    echo "Expected 'semgrep: available' in output, got:"
    echo "$output"
    false
  }
}

# Test 3: Mixed — only context7 available
@test "probe_tools: mixed availability (only context7)" {
  unset _SPEAR_PROBE_DONE _SPEAR_PROBE_OUTPUT

  export SPEAR_PROBE_CONTEXT7="1"
  unset SPEAR_PROBE_MGREP SPEAR_PROBE_SEMGREP

  # Block semgrep fallback via env-scoped PATH (no leak to teardown)
  output=$(PATH="/dev/null" probe_tools)

  [[ "$output" == *"context7: available"* ]] || {
    echo "Expected 'context7: available', got:"
    echo "$output"
    false
  }
  [[ "$output" == *"mgrep: unavailable"* ]] || {
    echo "Expected 'mgrep: unavailable', got:"
    echo "$output"
    false
  }
  [[ "$output" == *"semgrep: unavailable"* ]] || {
    echo "Expected 'semgrep: unavailable', got:"
    echo "$output"
    false
  }
}

# Test 4: semgrep fallback — env var unset but command exists
@test "probe_tools: semgrep fallback to command -v when env var unset" {
  unset _SPEAR_PROBE_DONE _SPEAR_PROBE_OUTPUT

  unset SPEAR_PROBE_CONTEXT7 SPEAR_PROBE_MGREP SPEAR_PROBE_SEMGREP

  # Create a temp directory with a fake semgrep script
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/semgrep" << 'EOF'
#!/bin/bash
echo "fake semgrep"
EOF
  chmod +x "$tmpdir/semgrep"

  # Add to front of PATH
  export PATH="$tmpdir:$PATH"

  output=$(probe_tools)

  [[ "$output" == *"semgrep: available"* ]] || {
    echo "Expected 'semgrep: available' via fallback, got:"
    echo "$output"
    false
  }

  # Cleanup
  rm -rf "$tmpdir"
}

# Test 5: Cache guard works — _SPEAR_PROBE_DONE prevents re-checking
@test "probe_tools: cache guard variable set on first call" {
  # Test that probe_tools sets the cache guard on first call
  unset _SPEAR_PROBE_DONE _SPEAR_PROBE_OUTPUT

  export SPEAR_PROBE_CONTEXT7="1"
  export SPEAR_PROBE_MGREP="1"
  unset SPEAR_PROBE_SEMGREP
  export PATH="/dev/null"

  # Direct call (not in subshell) so cache persists
  probe_tools > /dev/null

  # Verify cache guard was set
  [[ "${_SPEAR_PROBE_DONE:-}" == "1" ]] || {
    echo "Expected _SPEAR_PROBE_DONE=1 after first call"
    false
  }

  [[ -n "${_SPEAR_PROBE_OUTPUT:-}" ]] || {
    echo "Expected _SPEAR_PROBE_OUTPUT to be set after first call"
    false
  }

  # Verify the cached output contains the original probe results
  [[ "${_SPEAR_PROBE_OUTPUT:-}" == *"context7: available"* ]] || {
    echo "Expected cached output to show context7: available"
    false
  }
}
