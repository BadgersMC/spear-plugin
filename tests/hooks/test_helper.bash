#!/usr/bin/env bash
# tests/hooks/test_helper.bash — common Bats helper for hook tests

# Ensure jq and bats are on PATH
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Absolute path to repo root (two levels up from tests/hooks/)
SPEAR_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Path to the hook under test
HOOK_BIN="${SPEAR_REPO_ROOT}/plugins/spear/hooks/session-start"

# setup_tempdir — create a fresh temp dir and cd into it
# Sets BATS_TEST_TMPDIR to the new dir path.
setup_tempdir() {
  BATS_TEST_TMPDIR="$(mktemp -d)"
  export BATS_TEST_TMPDIR
  cd "$BATS_TEST_TMPDIR"
}

# teardown_tempdir — remove the temp dir created by setup_tempdir
teardown_tempdir() {
  if [ -n "${BATS_TEST_TMPDIR:-}" ] && [ -d "$BATS_TEST_TMPDIR" ]; then
    rm -rf "$BATS_TEST_TMPDIR"
  fi
}
