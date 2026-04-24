#!/usr/bin/env bash
#
# plugins/spear/hooks/lib/payload.sh — SPEAR session-start payload builder.
#
# Provides:
#   build_payload
#     Writes the SPEAR context text to stdout, including probe results.
#     Task 2.5 (TDD-14) will layer truncation and dynamic doc injection on top.
#
# REQ-082: Claude Code JSON output shape.
# REQ-021/022: probe results announced inline (delegated to probe.sh).

# Source probe.sh from same directory if not already loaded.
if ! declare -F probe_tools >/dev/null 2>&1; then
  # shellcheck source=./probe.sh
  source "$(dirname "${BASH_SOURCE[0]}")/probe.sh"
fi

build_payload() {
  cat <<'PAYLOAD'
# SPEAR — Spec-Proven Engineering with Architectural Requirements

You are operating inside a SPEAR project. Follow the SPEAR cycle for every
task. The cycle is non-negotiable: never skip or reorder steps.

## The SPEAR Cycle

1. SPEC    — Read the EARS requirement the task references (requirements.md).
2. PROVE   — Write a failing test that verifies the requirement (red).
3. ENGINE  — Write the minimum code to pass the test (green).
4. ARCH    — Ensure code respects layer boundaries:
             domain <- application <- infrastructure
5. REFINE  — Refactor if needed, re-run tests, confirm green.

## Rules

- Never write implementation before a failing test (domain + application).
- Never violate layer boundaries (check implementation.md § Layer Dependency).
- Requirements are the source of truth. Every feature maps to a REQ- ID.
- If it is not in requirements.md, do not build it.
- If the spec is wrong, update the spec first.
- Tasks are self-contained; read only the referenced doc sections.
PAYLOAD
  echo
  probe_tools
}
