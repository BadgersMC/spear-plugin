---
name: spear:refine
description: Finalize a SPEAR task — optional behavior-preserving refactor, full suite green, flip tasks.md to [x], and clear state to idle.
---

## Overview

`spear:refine` is the final step of the SPEAR cycle. It enters from `arch-done` and exits to `idle`, completing one full red-green-refactor loop for exactly one task. Scope is intentionally narrow; this is a worker-friendly (Sonnet) skill. For bulk refactors spanning multiple REQ-IDs, defer to `superpowers:executing-plans` instead.

---

## Procedure

### Step 1 — Assert predecessor phase (REQ-048)

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_assert_phase arch-done`.

If the command exits non-zero it will print:

```
spear requires phase=arch-done; current phase=<actual>
```

Stop immediately and surface that message. Do NOT proceed.

### Step 2 — Set phase to `refine`

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_set_phase refine`.

### Step 3 — Read state

Read `.claude/spear-state.json` and recover `currentTaskId`. This identifies which task entry in `docs/tasks.md` will be flipped to `[x]`.

### Step 4 — Refactor pass (optional, scoped)

Perform a behavior-preserving cleanup of code introduced during the engine phase. Rules:

- Tidy naming, extract helpers, remove dead code introduced during engine.
- Do NOT add features, expand the public API, or add new tests.
- Do NOT change behavior — the full test suite is the correctness oracle.
- If nothing needs tidying, skip this step entirely.

### Step 5 — Run the full test suite (REQ-048)

Execute the project's full test suite. If any test is red:

- Remain in `phase=refine`. Do NOT advance state.
- Record `failureReason` in `.claude/spear-state.json`.
- Fix or revert the refactor changes and retry from Step 4.

Do NOT proceed until the full suite is green.

### Step 6 — Mark task done and append Evidence (REQ-048)

In `docs/tasks.md`, locate the entry for `currentTaskId` and flip its checkbox:

- `[~]` → `[x]`
- `[ ]` → `[x]`

If new sources (libraries, docs, APIs) were consulted during the refactor that are not already cited, append a one-line Evidence entry to the task block.

### Step 7 — Clear state (REQ-048)

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_clear`.

This resets `phase` to `idle` and clears `currentTaskId`, `reqId`, `testFile`, `testName`, `testStatus`, and `evidenceCited` from `.claude/spear-state.json`.

### Step 8 — Commit

Stage the refactored files and the `docs/tasks.md` update as a single commit following the project commit convention. The task is now complete.

---

## Phase transitions

```
arch-done  →  [spear:refine]  →  idle  (cycle complete)
```

Enters from `arch-done`. On any test failure stays in `phase=refine`. On success exits to `idle`.

---

## Reference sources

- `docs/requirements.md` REQ-048
- `docs/implementation.md` §3.6 state helpers, §4.2 TDD cycle
- `plugins/spear/hooks/lib/state.sh`
