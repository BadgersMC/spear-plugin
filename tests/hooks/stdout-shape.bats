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

# ── Helper: run hook in Cursor mode (both roots set) ──────────────────────────
run_cursor_hook_both_set() {
  CLAUDE_PLUGIN_ROOT=/fake CURSOR_PLUGIN_ROOT=/fake run bash "$HOOK_BIN"
}

# ── Helper: run hook in Cursor mode (only Cursor root set) ──────────────────
run_cursor_hook_only() {
  CLAUDE_PLUGIN_ROOT= CURSOR_PLUGIN_ROOT=/fake run bash "$HOOK_BIN"
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

# ── Cursor branch tests (REQ-083, TDD-16) ────────────────────────────────────

@test "Cursor branch (both roots set): exits 0" {
  run_cursor_hook_both_set
  [ "$status" -eq 0 ]
}

@test "Cursor branch (both roots set): emits additional_context only" {
  run_cursor_hook_both_set
  [ "$status" -eq 0 ]

  # Must be valid JSON
  echo "$output" | jq . > /dev/null

  # additional_context must be non-empty
  echo "$output" | jq -e '.additional_context | length > 0'

  # Must NOT have hookSpecificOutput key anywhere
  echo "$output" | jq -e 'has("hookSpecificOutput") | not'
}

@test "Cursor branch (both roots set): additional_context includes SPEAR" {
  run_cursor_hook_both_set
  [ "$status" -eq 0 ]

  ctx=$(echo "$output" | jq -r '.additional_context')
  [[ "$ctx" == *"SPEAR"* ]]
}

@test "Cursor branch (only Cursor root set): exits 0" {
  run_cursor_hook_only
  [ "$status" -eq 0 ]
}

@test "Cursor branch (only Cursor root set): emits additional_context only" {
  run_cursor_hook_only
  [ "$status" -eq 0 ]

  # Must be valid JSON
  echo "$output" | jq . > /dev/null

  # additional_context must be non-empty
  echo "$output" | jq -e '.additional_context | length > 0'

  # Must NOT have hookSpecificOutput key anywhere
  echo "$output" | jq -e 'has("hookSpecificOutput") | not'
}

@test "Cursor branch (only Cursor root set): additional_context includes SPEAR" {
  run_cursor_hook_only
  [ "$status" -eq 0 ]

  ctx=$(echo "$output" | jq -r '.additional_context')
  [[ "$ctx" == *"SPEAR"* ]]
}

@test "Cursor branch (both roots set): output is valid JSON" {
  run_cursor_hook_both_set
  [ "$status" -eq 0 ]

  echo "$output" | jq . > /dev/null
  [ $? -eq 0 ]
}

@test "Cursor branch (only Cursor root set): output is valid JSON" {
  run_cursor_hook_only
  [ "$status" -eq 0 ]

  echo "$output" | jq . > /dev/null
  [ $? -eq 0 ]
}

# ── Rigor tests (additional coverage for TDD-16) ─────────────────────────────

@test "Cursor branch (both roots set): is single-key object with additional_context" {
  run_cursor_hook_both_set
  [ "$status" -eq 0 ]

  # The root object must have exactly one key: "additional_context"
  key_count=$(echo "$output" | jq 'keys | length')
  [ "$key_count" -eq 1 ]

  # That key must be "additional_context"
  has_key=$(echo "$output" | jq 'has("additional_context")')
  [ "$has_key" = "true" ]
}

@test "Cursor branch (both roots set): additional_context contains SPEAR cycle phrase" {
  run_cursor_hook_both_set
  [ "$status" -eq 0 ]

  ctx=$(echo "$output" | jq -r '.additional_context')
  # Must contain all five SPEAR cycle steps in some order (greedy pattern)
  [[ "$ctx" =~ SPEC ]]
  [[ "$ctx" =~ PROVE ]]
  [[ "$ctx" =~ ENGINE ]]
  [[ "$ctx" =~ ARCH ]]
  [[ "$ctx" =~ REFINE ]]
}

@test "Cursor branch (only Cursor root set): is single-key object with additional_context" {
  run_cursor_hook_only
  [ "$status" -eq 0 ]

  # The root object must have exactly one key: "additional_context"
  key_count=$(echo "$output" | jq 'keys | length')
  [ "$key_count" -eq 1 ]

  # That key must be "additional_context"
  has_key=$(echo "$output" | jq 'has("additional_context")')
  [ "$has_key" = "true" ]
}

# ── TDD-19 / REQ-021: probe results integrated into payload ─────────────────

@test "payload integration: additionalContext includes Tool probe section (Claude Code)" {
  SPEAR_PROBE_CONTEXT7=1 SPEAR_PROBE_MGREP=0 SPEAR_PROBE_SEMGREP=0 \
    CLAUDE_PLUGIN_ROOT=/fake CURSOR_PLUGIN_ROOT= run bash "$HOOK_BIN"
  [ "$status" -eq 0 ]
  ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"## Tool probe"* ]]
  [[ "$ctx" == *"context7: available"* ]]
  [[ "$ctx" == *"mgrep: unavailable"* ]]
}

@test "payload integration: additional_context includes Tool probe section (Cursor)" {
  SPEAR_PROBE_CONTEXT7=0 SPEAR_PROBE_MGREP=1 SPEAR_PROBE_SEMGREP=0 \
    CURSOR_PLUGIN_ROOT=/fake run bash "$HOOK_BIN"
  [ "$status" -eq 0 ]
  ctx=$(echo "$output" | jq -r '.additional_context')
  [[ "$ctx" == *"## Tool probe"* ]]
  [[ "$ctx" == *"mgrep: available"* ]]
}
