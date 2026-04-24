#!/bin/bash
# probe.sh — Tool availability detection with single-invocation caching
# Probes for context7, mgrep, semgrep; caches result in session globals
# REQ-021, REQ-022

probe_tools() {
  # Return cached output if already probed
  if [[ "${_SPEAR_PROBE_DONE:-}" == "1" ]]; then
    echo "$_SPEAR_PROBE_OUTPUT"
    return 0
  fi

  # Probe each tool and build output
  local output="## Tool probe"

  # Context7 — check env var only
  if [[ "${SPEAR_PROBE_CONTEXT7:-}" == "1" ]]; then
    output+=$'\n- context7: available'
  else
    output+=$'\n- context7: unavailable'
  fi

  # mgrep — check env var only
  if [[ "${SPEAR_PROBE_MGREP:-}" == "1" ]]; then
    output+=$'\n- mgrep: available'
  else
    output+=$'\n- mgrep: unavailable'
  fi

  # semgrep — check env var, with fallback to command -v
  if [[ "${SPEAR_PROBE_SEMGREP:-}" == "1" ]]; then
    output+=$'\n- semgrep: available'
  elif command -v semgrep >/dev/null 2>&1; then
    output+=$'\n- semgrep: available'
  else
    output+=$'\n- semgrep: unavailable'
  fi

  # Cache the result
  export _SPEAR_PROBE_DONE=1
  export _SPEAR_PROBE_OUTPUT="$output"

  echo "$output"
}

# Export function for use in other scripts
export -f probe_tools
