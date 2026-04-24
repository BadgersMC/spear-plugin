---
name: spear:spec
description: Add or revise an EARS requirement in requirements.md and derive tagged tasks in tasks.md.
---

## Overview

`spear:spec` enters from phase `idle` and exits to phase `spec-done`. TDD tasks flow next to `spear:prove`; DOC and INFRA tasks flow directly to `spear:arch`.

---

## Procedure

### Step 1 — Assert predecessor phase

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_assert_phase idle`.

If the command exits non-zero it will print:

```
spear:spec requires phase=idle; current phase=<actual>
```

Stop immediately and surface that message to the user. Do NOT proceed.

### Step 2 — Set phase to `spec`

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_set_phase spec`.

### Step 3 — Read `docs/requirements.md` and determine next REQ-ID

Scan every `REQ-\d+` ID present in the file. The next ID is `max + 1`, zero-padded to three digits (e.g. `REQ-074`). Never reuse or renumber an existing ID.

### Step 4 — Draft the REQ entry (REQ-072)

The new entry must match exactly one of the four EARS patterns:

| Pattern | Form |
|---|---|
| Ubiquitous | `THE SYSTEM SHALL <response>` |
| Event-driven | `WHEN <event> THE SYSTEM SHALL <response>` |
| State-driven | `WHILE <state> THE SYSTEM SHALL <response>` |
| Unwanted | `IF <unwanted> THEN THE SYSTEM SHALL <response>` |

Optional `WHERE …` qualifier is accepted without validation.

Draft the entry in the relevant section of `docs/requirements.md`, assigning the next free REQ-ID (Step 3).

### Step 5 — Validate via EARS CLI shim (REQ-072)

Shell out to:

```
node ${CLAUDE_PLUGIN_ROOT}/hooks/lib/ears.mjs docs/requirements.md
```

If validation fails, fix the entry and re-run. Do NOT bypass or skip this step.

### Step 6 — Derive tasks in `docs/tasks.md` (REQ-073, REQ-074)

For each new capability implied by the REQ entry, append a task entry to `docs/tasks.md`. Every task MUST have:

- **Tag** — exactly one of `TDD`, `DOC`, or `INFRA`.
- **References** — a `References:` line citing the relevant REQ-IDs and `docs/implementation.md` sections.
- **Evidence block** — an `Evidence:` line containing only a single space (` `) on first draft. Per REQ-030, downstream skills refuse to advance until this block has real content.

Task routing after `spec-done`:
- `TDD` tasks → `spear:prove` (red-green cycle required)
- `DOC` / `INFRA` tasks → `spear:arch` (no prove/engine phase)

### Step 7 — Set phase to `spec-done`

Shell out to `${CLAUDE_PLUGIN_ROOT}/hooks/lib/state.sh state_set_phase spec-done`.

### Step 8 — Evidence gate reminder (REQ-030)

Inform the user that no downstream skill (`spear:prove`, `spear:arch`, etc.) will run until the `Evidence:` block for each new task contains actual source citations. Prompt the user to fill in evidence before invoking the next skill.

---

## Phase transitions

```
idle  →  [spear:spec]  →  spec-done
                               ↓
              TDD tasks → spear:prove
              DOC/INFRA tasks → spear:arch
```

---

## Reference sources

- `docs/requirements.md` REQ-030, REQ-072, REQ-073, REQ-074
- `docs/implementation.md` §3.6 (state helpers), §4.2 (TDD cycle)
- `plugins/spear/hooks/lib/state.sh`
- `plugins/spear/hooks/lib/ears.mjs`
