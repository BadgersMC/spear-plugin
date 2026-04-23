#!/usr/bin/env bash
#
# SPEAR state machine helper — shelled out from skills and hooks.
#
# Usage: state.sh <fn> [args...]
#   fn: state_assert_phase <expected>
#       state_set_phase <new_phase>
#
# Environment:
#   SPEAR_STATE_FILE  — path to state JSON (default: .claude/spear-state.json)
#   SPEAR_INVOKER     — caller identifier used in diagnostic messages (default: spear)
set -euo pipefail

STATE_FILE="${SPEAR_STATE_FILE:-.claude/spear-state.json}"
INVOKER="${SPEAR_INVOKER:-spear}"

cmd_state_assert_phase() {
  local expected="$1"
  local actual
  actual=$(jq -r '.phase // "idle"' "$STATE_FILE" 2>/dev/null || echo "idle")
  if [ "$actual" != "$expected" ]; then
    echo "${INVOKER} requires phase=${expected}; current phase=${actual}" >&2
    exit 1
  fi
}

cmd_state_set_phase() {
  local new_phase="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  local existing="{}"
  [ -f "$STATE_FILE" ] && existing=$(cat "$STATE_FILE")
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "$existing" \
    | jq --arg p "$new_phase" --arg t "$now" \
        '. + {version: 1, phase: $p, lastUpdated: $t}' \
    > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

main() {
  if [ $# -lt 1 ]; then
    echo "state.sh: missing fn" >&2
    exit 2
  fi
  local fn="$1"; shift
  case "$fn" in
    state_assert_phase) cmd_state_assert_phase "$@" ;;
    state_set_phase)    cmd_state_set_phase "$@" ;;
    *) echo "state.sh: unknown fn: $fn" >&2; exit 2 ;;
  esac
}

main "$@"
