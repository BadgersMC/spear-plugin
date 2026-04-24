---
name: spear:engine
description: Write the minimum implementation to flip the red test green, gate on Evidence, and advance state to engine-done.
---

## Overview

`spear:engine` enters from phase `prove-done` and exits to phase `engine-done`. It is the green half of the red-green-refactor cycle. The failing test fully constrains scope — this is intentionally worker-friendly (Sonnet/Haiku). Opus dispatches; the worker implements.

DOC and INFRA tasks skip this skill entirely — they flow `spec-done → arch` directly.

---

## Procedure

### Step 1 — Assert predecessor phase (REQ-043)

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_assert_phase prove-done`.

If the command exits non-zero it will print:

```
spear:engine requires phase=prove-done; current phase=<actual>
```

Stop immediately and surface that message to the user. Do NOT proceed.

### Step 2 — Set phase to `engine`

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_set_phase engine`.

### Step 3 — Read state

Read `.claude/spear-state.json` and recover the values of `testFile`, `testName`, `reqId`, and `currentTaskId`. These fields were written by `spear:prove` and identify exactly what must go green.

### Step 4 — Write the minimum implementation (REQ-047)

Implement only what is necessary to make the failing test pass. The following are FORBIDDEN:

- Behaviour not required by the failing test.
- Speculative features or future-proofing code.
- Error handling not asserted by the test.
- New public API not demanded by the test.

The failing test is the acceptance criterion. Do not exceed it.

### Step 5 — Run the test; confirm green (REQ-047)

Execute the test identified by `testFile` and `testName`. If the test passes, proceed to Step 6.

If the test is still red:

- Remain in `phase=engine`. Do NOT advance state.
- Record the failure reason: update `.claude/spear-state.json` with a `failureReason` field describing why the test still fails.
- Diagnose and fix the implementation, then re-run from Step 4.

Do NOT advance until the specific test is green.

### Step 6 — Import-diff gate (REQ-031, REQ-032)

Compute the set of new third-party and internal import paths introduced by the implementation diff relative to the project baseline.

For each new import, check whether it appears as a substring in any line of the current task's `Evidence:` block in `docs/tasks.md`. If any import is not covered, print:

```
Add evidence for: <import>, <import> …
```

Do NOT call `state_record_test` or `state_set_phase engine-done`. Per REQ-032 the gate is hard — state MUST NOT advance beyond recording the error reason. The agent must update `Evidence:` in `docs/tasks.md` and re-invoke `spear:engine` from Step 6.

### Step 7 — Record green (REQ-047)

Shell out to:

```
${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_record_test <testFile> <testName> green
```

Where `<testFile>` and `<testName>` are the values recovered from state in Step 3.

### Step 8 — Set phase to `engine-done`

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_set_phase engine-done`.

---

## Briefing contract for worker dispatch (§5.3)

When Opus dispatches a Sonnet or Haiku worker, the Agent prompt MUST carry:

- **Files to create/modify:** absolute paths of implementation files.
- **Pre-verified signatures:** from `docs/implementation.md` §3.6.
- **Failing test:** `testFile` and `testName` from state.
- **Acceptance criteria:** the test must pass; no other files may change.
- **Forbidden actions:** no behaviour beyond the test; no new public API; no speculative error handling.
- **Evidence block:** copied verbatim from the task entry in `docs/tasks.md`.

---

## Phase transitions

```
prove-done  →  [spear:engine]  →  engine-done
                                       ↓
                                  spear:arch
```

DOC / INFRA tasks skip engine entirely:

```
spec-done  →  spear:arch  (no prove/engine)
```

---

## Reference sources

- `docs/requirements.md` REQ-031, REQ-032, REQ-047
- `docs/implementation.md` §3.6 (state helpers), §4.2 (TDD cycle), §5 (briefing contract)
- `plugins/spear/hooks/lib/state.sh`
