#!/usr/bin/env bash
#
# plugins/spear/hooks/lib/detect.sh — SPEAR project detection helper.
#
# Provides:
#   is_spear_project <dir>
#     Returns 0 (true) iff BOTH docs/requirements.md AND docs/tasks.md exist
#     inside <dir>.  Returns 1 otherwise.
#
# REQ-084 / REQ-091: Both marker files must be present for SPEAR mode.

is_spear_project() {
  local dir="${1:-.}"
  [ -f "${dir}/docs/requirements.md" ] && [ -f "${dir}/docs/tasks.md" ]
}
