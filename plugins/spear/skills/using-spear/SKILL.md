---
name: spear:using-spear
description: SPEAR session-start context; auto-loaded by the session-start hook, never invoked via slash command.
---

# SPEAR — Session Start Context

SPEAR = Spec-Proven Engineering with Architectural Requirements. Hybrid of Spec-Driven (EARS), TDD, and Hexagonal Architecture. This text is injected at every session start. Read it before acting.

## Cycle rules (NEVER TRUNCATED)

Five phases, executed in order, one task at a time:

1. `spec`    — Read/author the EARS requirement (`docs/requirements.md`) the task references.
2. `prove`   — Write a failing test that verifies the requirement (red). TDD tasks only.
3. `engine`  — Write minimum code to pass the test (green). TDD tasks only.
4. `arch`    — Enforce layer boundaries (domain <- application <- infrastructure) and framework-annotation denylist in `domain/**`.
5. `refine`  — Refactor, re-run full suite, mark task `[x]`, reset state to `idle`.

**Linear gating.** Each `/spear:<skill>` refuses to run unless the current phase equals its documented predecessor. Error form: `spear:<skill> requires phase=<expected>; current phase=<actual>`. Phases carry a `-done` suffix on completion (e.g. `prove-done`) — that is what the successor gate checks.

**DOC/INFRA tasks skip prove/engine.** Path: `idle -> spec -> spec-done -> arch -> arch-done -> refine -> idle`. TDD path runs all five.

## Trigger matrix

| Skill | Predecessor phase | Fires when |
|---|---|---|
| `/spear:init`   | — (idempotent)    | Bootstrapping a new SPEAR project |
| `/spear:spec`   | `idle`            | Authoring/revising a REQ-, drafting tasks |
| `/spear:prove`  | `spec-done` (TDD) | Writing the failing test |
| `/spear:engine` | `prove-done`      | Writing minimum code to green |
| `/spear:arch`   | `engine-done` (TDD) or `spec-done` (DOC/INFRA) | Layer + annotation check |
| `/spear:refine` | `arch-done`       | Refactor, close task, reset to idle |

## Principles

**Verify, don't guess.** Before writing/planning any code, verify every external fact. Evidence source order: `context7` MCP → on-disk sources (`node_modules`, `~/.gradle/caches`, site-packages) → `WebFetch` of official docs → project codebase via `mgrep`/`Read`/`Glob`. Every task's `Evidence:` block must cite sources consulted; unmatched imports vs. evidence block hard-fail `prove`/`engine`/`arch`.

**Briefing contract (subagent dispatch).** Every `Agent` dispatch MUST include: exact file paths; exact function/class signatures (pre-verified); the failing test (verbatim or file:name); acceptance criteria ("test X green; no other files changed"); forbidden actions ("no error handling not asserted by the test"); the task's `Evidence:` block.

**Task sizing.** Any task whose full briefing exceeds ~1500 tokens MUST be decomposed by `/spear:spec` before dispatch.

## Dynamic context (injected by session-start hook)

Probe results: {{PROBE_RESULTS}}
Current task: {{CURRENT_TASK}}
Current phase: {{CURRENT_PHASE}}

## Deferral list

Defer the following to `superpowers` (no SPEAR replacement):

- `superpowers:brainstorming` — pre-init ideation
- `superpowers:writing-plans` — plan authoring
- `superpowers:executing-plans` — plan execution shell
- `superpowers:systematic-debugging` — bug diagnosis

Inside SPEAR projects, `/spear:prove` supersedes `superpowers:test-driven-development`.

## Truncation order (hook contract)

When this payload approaches 4096 bytes, the hook truncates in this order:

1. Full `tasks.md` body (replaced by count + current-task summary).
2. Historical probe results.
3. The deferral list above.

Cycle rules and the Current phase line below SHALL NEVER be truncated.

## Current phase (NEVER TRUNCATED)

Current phase: {{CURRENT_PHASE}}
