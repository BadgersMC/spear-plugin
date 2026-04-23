#!/usr/bin/env bats
# tests/hooks/stdout-shape.bats — TDD-15: Claude Code stdout JSON shape (REQ-082)

load test_helper

setup() {
  setup_tempdir
  # Create a minimal SPEAR project in the temp dir
  mkdir -p docs
  echo "# requirements stub" > docs/requirements.md
  echo "# tasks stub"        > docs/tasks.md
}

teardown() {
  teardown_tempdir
}

# ── Helper: run hook in Claude Code mode ────────────────────────────────────
run_claude_hook() {
  CLAUDE_PLUGIN_ROOT=/fake CURSOR_PLUGIN_ROOT= run bash "$HOOK_BIN"
}

# ── Tests ────────────────────────────────────────────────────────────────────

@test "Claude Code branch: exits 0" {
  run_claude_hook
  [ "$status" -eq 0 ]
}

@test "Claude Code branch: emits hookSpecificOutput only" {
  run_claude_hook
  [ "$status" -eq 0 ]

  # Must be valid JSON
  echo "$output" | jq . > /dev/null

  # hookEventName must be "SessionStart"
  result=$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName')
  [ "$result" = "SessionStart" ]

  # additionalContext must be non-empty
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'

  # Must NOT have an additional_context key at the top level
  echo "$output" | jq -e 'has("additional_context") | not'
}

@test "Claude Code branch: additionalContext includes SPEAR header" {
  run_claude_hook
  [ "$status" -eq 0 ]

  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"# SPEAR"* ]]
}

@test "Claude Code branch: additionalContext includes cycle rules" {
  run_claude_hook
  [ "$status" -eq 0 ]

  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # Must contain the SPEAR cycle steps
  [[ "$ctx" == *"SPEC"*    ]]
  [[ "$ctx" == *"PROVE"*   ]]
  [[ "$ctx" == *"ENGINE"*  ]]
  [[ "$ctx" == *"ARCH"*    ]]
  [[ "$ctx" == *"REFINE"*  ]]
}

@test "Claude Code branch: additionalContext is non-empty string" {
  run_claude_hook
  [ "$status" -eq 0 ]

  len=$(echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length')
  [ "$len" -gt 0 ]
}

@test "Claude Code branch: output is valid JSON (jq exit 0)" {
  run_claude_hook
  [ "$status" -eq 0 ]

  # pipe through jq . and assert exit 0
  echo "$output" | jq . > /dev/null
  [ $? -eq 0 ]
}

@test "Claude Code branch: additional_context key is absent" {
  run_claude_hook
  [ "$status" -eq 0 ]

  echo "$output" | jq -e '.additional_context == null'
}
