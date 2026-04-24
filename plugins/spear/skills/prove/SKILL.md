---
name: spear:prove
description: Write a failing test that proves the current REQ is unsatisfied, confirm red, and gate on Evidence before advancing state.
---

## Overview

`spear:prove` enters from phase `spec-done` and exits to phase `prove-done`. It is the red half of the red-green-refactor cycle. For DOC and INFRA tasks this skill is skipped entirely — those tasks flow `spec-done → arch` directly.

Outside a SPEAR project, defer to `superpowers:test-driven-development`.

---

## Procedure

### Step 1 — SPEAR-project detection (REQ-091, REQ-092)

Check whether both `docs/requirements.md` and `docs/tasks.md` exist in the project root.

If either file is absent, print:

```
not a SPEAR project; use superpowers:test-driven-development
```

Stop immediately. Do NOT mutate any state.

### Step 2 — Assert predecessor phase (REQ-043)

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_assert_phase spec-done`. On non-zero exit, surface the printed message and stop — do NOT proceed.

### Step 3 — Set phase to `prove`

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_set_phase prove`.

### Step 4 — Evidence gate (REQ-030)

Read the `Evidence:` block for the current task in `docs/tasks.md`. If the block contains only whitespace or a single placeholder space, refuse to proceed:

```
Evidence block is empty for task <taskId>. Populate Evidence: before invoking spear:prove.
```

Do NOT call `state_set_phase` beyond `prove`. The task must be re-specced with real evidence before continuing.

### Step 5 — Write the failing test (REQ-046)

Identify the REQ-ID referenced by the current task. Write a test file that:

- Targets the exact behaviour the requirement specifies (not an approximation).
- Uses the idiomatic test framework for the detected language:
  - **JVM (Kotlin):** Kotest or JUnit 5
  - **Node:** `node --test`, Vitest, or Jest (match the project's existing choice)
  - **Python:** pytest
  - Other stacks: use the project's declared test framework from `docs/tech-stack.md`.
- Asserts the described behaviour so that it fails today because the implementation does not exist.
- Contains no stub implementations that make it pass trivially.

### Step 6 — Run the test; confirm red (REQ-046)

Execute the test and capture its output. The test MUST fail because the behaviour under test does not yet exist — not for an unrelated reason.

If the test passes, fix it and re-run. Do NOT advance state with a bogus red. If it errors for an unrelated reason (e.g. a compile error), fix that first so the failure is meaningful.

### Step 7 — Import-diff gate (REQ-031, REQ-032)

Compute the set of new third-party and internal import paths introduced by the test file relative to the project baseline (files that existed before this task began).

For each new import, check whether it appears as a substring in any line of the current task's `Evidence:` block. If any import is not covered, print:

```
Add evidence for: <import>, <import> …
```

Do NOT call `state_record_test` or `state_set_phase prove-done`. The agent must update `Evidence:` in `docs/tasks.md` and then re-invoke `spear:prove` from Step 7.

### Step 8 — Record red (REQ-046)

Shell out to:

```
${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_record_test <testFile> <testName> red
```

Where `<testFile>` is the path to the test file and `<testName>` is the individual test or spec name that is failing.

### Step 9 — Set phase to `prove-done`

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_set_phase prove-done`.

---

## Phase transitions

```
spec-done  →  [spear:prove]  →  prove-done
                                    ↓
                             spear:engine
```

DOC / INFRA tasks skip prove entirely:

```
spec-done  →  spear:arch  (no prove/engine)
```

---

## Reference sources

- `docs/requirements.md` REQ-030, REQ-031, REQ-032, REQ-046, REQ-091, REQ-092
- `docs/implementation.md` §3.6 (state helpers), §4.2 (TDD cycle), §5 (briefing contract)
- `plugins/spear/hooks/lib/state.sh`
