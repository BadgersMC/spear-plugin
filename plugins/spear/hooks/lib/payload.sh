#!/usr/bin/env bash
#
# plugins/spear/hooks/lib/payload.sh — SPEAR session-start payload builder.
#
# Provides:
#   build_payload
#     Writes the SPEAR context text to stdout with tiered truncation.
#     Total output is kept under SPEAR_PAYLOAD_BUDGET bytes (default 4096).
#
# REQ-013: Session-start payload size ceiling (4096 bytes).
# REQ-014: Truncation order — tasks first, then probe, then deferral. Cycle
#          rules and current phase are NEVER truncated.
# REQ-082: Claude Code JSON output shape.
# REQ-021/022: probe results announced inline (delegated to probe.sh).
#
# Truncation tiers (applied in order when budget exceeded):
#   TIER 1 — Replace full tasks.md body with summary line.
#   TIER 2 — Drop probe detail; emit "probe: see prior session".
#   TIER 3 — Drop deferral section entirely.
#   FROZEN — Cycle rules + current phase: never truncated.

# Source probe.sh from same directory if not already loaded.
if ! declare -F probe_tools >/dev/null 2>&1; then
  # shellcheck source=./probe.sh
  source "$(dirname "${BASH_SOURCE[0]}")/probe.sh"
fi

# ── Section builders ─────────────────────────────────────────────────────────

# _build_cycle_section
# Emits the frozen SPEAR cycle rules block. Never truncated.
_build_cycle_section() {
  cat <<'CYCLE'
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
CYCLE
}

# _build_notice_section
# Emits a reconciliation notice if $SPEAR_RECONCILE_NOTICE is non-empty.
# FROZEN tier — never truncated (reconciliation notices must reach the user).
_build_notice_section() {
  if [ -n "${SPEAR_RECONCILE_NOTICE:-}" ]; then
    printf '## Notice\n%s\n' "$SPEAR_RECONCILE_NOTICE"
  fi
}

# _build_phase_section
# Emits the current phase line from .claude/spear-state.json (if present).
# Frozen — never truncated.
_build_phase_section() {
  local state_file=".claude/spear-state.json"
  if [ -f "$state_file" ]; then
    local phase task_id
    phase=$(jq -r '.phase // "idle"' "$state_file" 2>/dev/null || echo "idle")
    task_id=$(jq -r '.currentTaskId // ""' "$state_file" 2>/dev/null || echo "")
    if [ -n "$task_id" ]; then
      echo "## Current phase: ${phase} (task: ${task_id})"
    else
      echo "## Current phase: ${phase}"
    fi
  fi
}

# _build_tasks_section FULL|SUMMARY
# FULL    — embeds the entire docs/tasks.md content (Tier 1 — truncatable).
# SUMMARY — emits a one-line summary: "tasks: N total, current: <id>".
_build_tasks_section() {
  local mode="${1:-FULL}"
  local tasks_file="docs/tasks.md"

  if [ ! -f "$tasks_file" ]; then
    return 0
  fi

  if [ "$mode" = "SUMMARY" ]; then
    # Count total tasks (lines with checkboxes)
    local total done_count current_id current_line
    total=$(grep -c '^\s*-\s*\[' "$tasks_file" 2>/dev/null || echo 0)
    done_count=$(grep -c '^\s*-\s*\[x\]' "$tasks_file" 2>/dev/null || echo 0)

    # Determine current task ID
    current_id=""
    # Check spear-state.json first
    local state_file=".claude/spear-state.json"
    if [ -f "$state_file" ]; then
      current_id=$(jq -r '.currentTaskId // ""' "$state_file" 2>/dev/null || echo "")
    fi
    # Fall back to first un-done task line
    if [ -z "$current_id" ]; then
      current_line=$(grep -m 1 '^\s*-\s*\[ \]' "$tasks_file" 2>/dev/null || echo "")
      if [ -n "$current_line" ]; then
        # Extract first token after "- [ ]" as task ID (e.g. TDD-014)
        current_id=$(echo "$current_line" | sed 's/^\s*-\s*\[ \]\s*//' | awk '{print $1}')
      fi
    fi

    if [ -n "$current_id" ]; then
      echo "## Current task"
      echo "tasks: ${total} total (${done_count} done), current: ${current_id}"
    else
      echo "## Current task"
      echo "tasks: ${total} total (${done_count} done)"
    fi
  else
    # FULL mode: embed entire tasks.md
    echo "## Current task"
    cat "$tasks_file"
  fi
}

# _build_probe_section FULL|SHORT
# FULL  — full probe results via probe_tools() (Tier 2 — truncatable).
# SHORT — one-line fallback: "probe: see prior session".
_build_probe_section() {
  local mode="${1:-FULL}"
  if [ "$mode" = "SHORT" ]; then
    echo "probe: see prior session"
  else
    probe_tools
  fi
}

# _build_deferral_section
# Tier 3 — truncatable. Defers brainstorming/planning/debugging to superpowers.
_build_deferral_section() {
  cat <<'DEFER'
## Defer to superpowers

Defer brainstorming/plans/debug to superpowers:*.
- Brainstorming    → superpowers:brainstorming
- Writing plans    → superpowers:writing-plans
- Executing plans  → superpowers:executing-plans
- Debugging        → superpowers:systematic-debugging
DEFER
}

# _byte_len STRING
# Returns byte length of STRING (not character count — safe for ASCII payloads).
_byte_len() {
  printf '%s' "$1" | wc -c | tr -d ' '
}

# _assemble_with_truncation BUDGET
# Assembles all sections and drops lower-priority tiers until ≤ BUDGET bytes.
# Prints the final payload text.
_assemble_with_truncation() {
  local budget="${1:-4096}"

  # FROZEN sections (never dropped)
  local cycle_text phase_text notice_text frozen_text
  cycle_text="$(_build_cycle_section)"
  phase_text="$(_build_phase_section)"
  notice_text="$(_build_notice_section)"

  # Assemble frozen tier: cycle + phase (if any) + notice (if any)
  frozen_text="${cycle_text}"
  if [ -n "$phase_text" ]; then
    frozen_text="${frozen_text}"$'\n\n'"${phase_text}"
  fi
  if [ -n "$notice_text" ]; then
    frozen_text="${frozen_text}"$'\n\n'"${notice_text}"
  fi

  # TIER 1 — tasks (start with FULL, degrade to SUMMARY)
  local tasks_full tasks_summary
  tasks_full="$(_build_tasks_section FULL)"
  tasks_summary="$(_build_tasks_section SUMMARY)"

  # TIER 2 — probe (start with FULL, degrade to SHORT)
  local probe_full probe_short
  probe_full="$(_build_probe_section FULL)"
  probe_short="$(_build_probe_section SHORT)"

  # TIER 3 — deferral
  local deferral_text
  deferral_text="$(_build_deferral_section)"

  # ── Assembly: try from richest to leanest ────────────────────────────────

  # Helper: join non-empty sections with double newlines
  _join_sections() {
    local result=""
    local section
    for section in "$@"; do
      if [ -n "$section" ]; then
        if [ -n "$result" ]; then
          result="${result}"$'\n\n'"${section}"
        else
          result="${section}"
        fi
      fi
    done
    printf '%s' "$result"
  }

  local candidate len

  # Attempt 1: everything full
  candidate="$(_join_sections "$frozen_text" "$tasks_full" "$probe_full" "$deferral_text")"
  len="$(_byte_len "$candidate")"
  if [ "$len" -le "$budget" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  # Attempt 2: tasks → summary
  candidate="$(_join_sections "$frozen_text" "$tasks_summary" "$probe_full" "$deferral_text")"
  len="$(_byte_len "$candidate")"
  if [ "$len" -le "$budget" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  # Attempt 3: tasks → summary + probe → short
  candidate="$(_join_sections "$frozen_text" "$tasks_summary" "$probe_short" "$deferral_text")"
  len="$(_byte_len "$candidate")"
  if [ "$len" -le "$budget" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  # Attempt 4: drop deferral entirely
  candidate="$(_join_sections "$frozen_text" "$tasks_summary" "$probe_short")"
  len="$(_byte_len "$candidate")"
  if [ "$len" -le "$budget" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  # Attempt 5: frozen only + tasks summary (absolute minimum with context)
  candidate="$(_join_sections "$frozen_text" "$tasks_summary")"
  len="$(_byte_len "$candidate")"
  if [ "$len" -le "$budget" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  # Attempt 6: frozen only
  candidate="$frozen_text"
  len="$(_byte_len "$candidate")"
  if [ "$len" -le "$budget" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  # Last resort: frozen + truncation notice (budget too small for even frozen)
  printf '%s\n[truncated: budget exceeded]' "$frozen_text"
}

# ── Public API ───────────────────────────────────────────────────────────────

build_payload() {
  local budget="${SPEAR_PAYLOAD_BUDGET:-4096}"
  _assemble_with_truncation "$budget"
}
