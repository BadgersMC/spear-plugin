#!/usr/bin/env bats
# tests/hooks/detect.bats — TDD-13: SPEAR project detection + no-op outside

load test_helper

setup() {
  setup_tempdir
}

teardown() {
  teardown_tempdir
}

@test "hook emits 'not a SPEAR project' when docs missing" {
  # Empty temp dir — no docs/requirements.md, no docs/tasks.md
  run bash "$HOOK_BIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a SPEAR project"* ]]
}

@test "hook succeeds silently when both SPEAR docs present" {
  # Temp dir with the two required marker files
  mkdir -p docs
  echo "# requirements stub" > docs/requirements.md
  echo "# tasks stub"        > docs/tasks.md

  run bash "$HOOK_BIN"
  [ "$status" -eq 0 ]
  [[ "$output" != *"not a SPEAR project"* ]]
}
