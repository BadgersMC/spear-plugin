# SPEAR Plugin — Design Spec

**Date:** 2026-04-23
**Status:** Draft — pending review
**Owner:** BadgersMC

## 1. Purpose

Package the SPEAR methodology (Spec-Proven Engineering with Architectural Requirements) as a reusable Claude Code plugin installable across any BadgersMC project. The plugin must both **enforce** the SPEAR cycle order (blocking implementation before a failing test, blocking progression past a layer-boundary violation) and **automate** the boilerplate (scaffolding the four SPEAR docs, assigning REQ-IDs, managing task state).

It must compose cleanly with the existing `superpowers` plugin rather than replace it: SPEAR governs *what* to build and in what order; superpowers' process skills (`brainstorming`, `writing-plans`, `executing-plans`, `systematic-debugging`) remain the preferred vehicles for their phases. SPEAR adds the SPEAR-specific gates on top.

## 2. Scope

**In scope**

- A standalone plugin distributed via a self-hosted Claude Code marketplace repo.
- Six workflow skills covering the SPEAR cycle plus one context skill injected at session start.
- A session-start hook that reconciles state and injects the context skill.
- A per-project state file (`.claude/spear-state.json`) tracking the current task phase.
- Doc templates and a Konsist architecture test template for JVM projects.
- Tests for the plugin's mechanical components (hook output, state transitions, template emission).

**Out of scope**

- Submission to `anthropics/claude-plugins-official` (tracked as a follow-up after real-world validation).
- Verifying adherence of the LLM to skill instructions (fundamentally unverifiable).
- Architecture test templates for non-JVM stacks (opt-in future work).

## 3. Distribution & Install

The repo `BadgersMC/spear-plugin` doubles as a Claude Code plugin marketplace.

### 3.1 Repo layout

```
spear-plugin/
├── .claude-plugin/
│   └── marketplace.json                # marketplace manifest
├── plugins/
│   └── spear/
│       ├── .claude-plugin/
│       │   └── plugin.json             # plugin manifest
│       ├── skills/
│       │   ├── using-spear/SKILL.md
│       │   ├── init/SKILL.md
│       │   ├── spec/SKILL.md
│       │   ├── prove/SKILL.md
│       │   ├── engine/SKILL.md
│       │   ├── arch/SKILL.md
│       │   └── refine/SKILL.md
│       ├── hooks/
│       │   ├── session-start.sh        # POSIX hook
│       │   └── session-start.ps1       # Windows hook
│       ├── templates/
│       │   ├── tech-stack.md
│       │   ├── requirements.md
│       │   ├── implementation.md
│       │   ├── tasks.md
│       │   └── LayerRulesTest.kt       # Konsist template
│       └── migrations/                 # state-file schema migrations
├── tests/
│   ├── hooks/                          # hook integration fixtures
│   ├── skills/                         # skill-content lint
│   └── state/                          # state-machine tests
├── .github/workflows/ci.yml
├── README.md
├── CONTRIBUTING.md
└── TESTING.md                          # manual E2E checklist
```

### 3.2 Install flow

```
/plugin marketplace add BadgersMC/spear-plugin
/plugin install spear@BadgersMC-spear-plugin
/plugin reload-plugins
```

Claude Code caches the plugin at `~/.claude/plugins/cache/BadgersMC-spear-plugin/spear/<version>/`.

### 3.3 Versioning

Semver. The state-file schema carries its own `version` field; each breaking change ships a migration script in `migrations/`. **Migrations run in the session-start hook, not inside a skill** — skills are LLM prose and must not be relied on for deterministic schema migration. The hook invokes the appropriate migration binary/script before emitting its stdout.

## 4. Skills

Seven skills total. Six are workflow skills invoked via `/spear:<name>`; `using-spear` is loaded automatically via the session-start hook and never invoked directly.

### 4.1 `using-spear` — session-start context

Terse, under a **hard ceiling of 4 KB / ~1000 tokens** emitted to stdout. Emitted by the session-start hook, which Claude Code injects into the session context. Contains:

- SPEAR cycle rules (the five phases, their order, the gating principle).
- Trigger matrix (which skill fires when).
- The top-level principles from §5 (Verify Don't Guess, Tool Preference Probing, Orchestrator/Worker Split).
- Announcement of probe results (see §5.2).
- Current SPEAR state summary if `.claude/spear-state.json` exists.
- Explicit note deferring to superpowers for `brainstorming`, `writing-plans`, `executing-plans`, and `systematic-debugging`.

**Truncation order** (when the payload nears the ceiling): full `tasks.md` contents are truncated first (replaced by a count + current-task summary), then historical probe results, then the deferral list. The cycle rules and current phase are never truncated.

Full skill bodies remain in their respective `SKILL.md` files and load on-demand via the `Skill` tool, keeping the session-start payload small.

### 4.2 Workflow skills

| Skill | Trigger | Behavior |
|---|---|---|
| `spear:init` | User requests SPEAR scaffolding | Detects language/framework from build files; interactively drafts `tech-stack.md`, `requirements.md`, `implementation.md`, `tasks.md` from templates; emits Konsist `LayerRulesTest.kt` on JVM; commits `chore(spear): initialize SPEAR docs`. |
| `spear:spec` | Adding or revising a requirement; user references a REQ-ID | Reads `requirements.md`, validates EARS format, assigns next REQ-ID, drafts or updates tasks with `References:` and `Evidence:` blocks. |
| `spear:prove` | Before implementation for any task tagged `TDD` | Enters `phase: prove`; writes a failing test referencing the REQ-ID; runs it; verifies red; records `testStatus: red` and exits to `phase: prove-done` awaiting `engine`. |
| `spear:engine` | When `phase === prove-done` | Enters `phase: engine`; writes minimum code to flip red→green; runs the test; verifies green; records `testStatus: green` and exits to `phase: engine-done`. Forbids behavior not required by the failing test. |
| `spear:arch` | When `phase === engine-done` (TDD) or `phase === spec-done` (non-TDD) | Enters `phase: arch`; scans imports in changed files against the layer map in `implementation.md`; checks framework-annotation denylist (§6.4) in `domain/**`; blocks on violations; exits to `phase: arch-done`. |
| `spear:refine` | When `phase === arch-done` | Enters `phase: refine`; refactor pass; reruns full test suite; confirms green; marks the task `[x]` in `tasks.md`; clears state to `phase: idle`. |

`phase` names the **active or just-completed** phase with an explicit `-done` suffix on completion; this removes the ambiguity between "in phase X" and "ready to enter phase X+1." Gates are **linear**: each skill refuses to run unless the current phase equals its documented predecessor.

**Non-TDD entry point.** Tasks tagged `DOC` or `INFRA` skip `prove`/`engine`. `spear:spec` closes such tasks with `phase: spec-done` (rather than dispatching to `prove`), which authorizes `spear:arch` to run directly. The state machine in §7.2 encodes this as an explicit `spec-done --> arch` edge.

## 5. Cross-Cutting Principles

These are emitted as part of `using-spear` so every skill and subagent inherits them.

### 5.1 Verify, don't guess

Before writing or planning ANY code, verify every external fact that could otherwise be assumed: third-party API signatures, internal module contracts, type and schema shapes, existing patterns in the codebase, test framework idioms, file locations, naming conventions.

**Evidence source order:**

1. `context7` MCP (library/API verification)
2. Library source on disk (`node_modules`, `~/.gradle/caches`, site-packages, etc.)
3. Official docs via `WebFetch`
4. Project codebase via `mgrep`/`Read`/`Glob`

**Evidence must be recorded.** Each task in `tasks.md` carries an `Evidence:` block citing the sources consulted (examples: `context7:react@19/useEffect`, `src/domain/Order.kt:42`, `docs/implementation.md#section-3`). A task without an `Evidence` block cannot advance past `spec`.

**Concrete gating mechanism.** At the start of `spear:prove`, `spear:engine`, and `spear:arch`, the skill computes the set of *new third-party import paths* and *new internal module imports* introduced by the phase's diff (imports present in the phase's changed files but absent from the task's baseline snapshot recorded by `spear:spec`). Each such import must match at least one token in the task's `Evidence:` block (substring match against the evidence lines). Unmatched imports surface a list: "Add evidence for: <import>, <import> …" and the skill refuses to proceed until the task's `Evidence` block is updated. This is a hard gate — not a reviewer prompt — because the check is mechanical (import diff vs. string match).

### 5.2 Tool preference probing

`using-spear` probes once at session start for optional tools and announces the result so downstream skills and workers know which path to use:

| Preferred tool | Purpose | Fallback |
|---|---|---|
| `context7` MCP | Library/API verification | Source-on-disk → docs WebFetch |
| `mgrep` skill | Code search | Built-in `Grep`/`Glob` |
| `semgrep` | Pattern/vulnerability scanning | `mgrep` / `Grep` |

Probe results cache in the injected reminder for the session; skills do not re-probe.

### 5.3 Orchestrator/worker split

The session-level agent (Opus) is the lead engineer: reads specs, makes architectural calls, runs reviews. Implementation work is delegated to subagents running lighter models (Sonnet/Haiku) via the `Agent` tool with an explicit `model` override.

**Opus writes code directly only when the task requires judgment no briefing can capture.** Everything else is briefed and dispatched.

**Briefing contract.** Every worker dispatch must include:

- Exact file path(s) to create or modify
- Exact function/class signatures (pre-verified per §5.1)
- The failing test (verbatim or by file path + test name)
- Acceptance criteria ("test X goes green; no other files changed")
- Forbidden actions ("do not add error handling not asserted by the test")
- The task's `Evidence:` block (so the worker inherits verified facts)

**Per-phase defaults:**

| Phase | Executor | Rationale |
|---|---|---|
| `spec` | Opus | High-judgment: EARS authoring, task decomposition |
| `prove` | Sonnet | Mechanical once test target specified |
| `engine` | Haiku/Sonnet | Tightly constrained by the failing test |
| `arch` | Opus or `code-reviewer` subagent | Architectural judgment |
| `refine` | Sonnet | Scoped refactors |

**Parallelism.** `spec` decomposes requirements into independent tasks. Opus dispatches multiple `prove`+`engine` worker pairs in parallel (one message containing multiple `Agent` tool uses, per superpowers' `dispatching-parallel-agents` skill). Opus then runs a single `arch` pass across the merged result.

**Task sizing rule.** A task is correctly sized when its full briefing fits in ~1500 tokens and the smallest model in the current Claude family could execute it without asking questions. If not, `spec` decomposes further before dispatch. This is a forcing function for good decomposition.

## 6. Architectural Enforcement (`spear:arch` in detail)

1. Reads the layer rules from `docs/implementation.md` § "Layer Dependency Rules".
2. Scans imports in every file modified since the last `arch` pass (uses `mgrep` when available, otherwise language-native tooling).
3. Validates direction:
   - `domain/**` — imports only from `domain/**` + stdlib. Any `application/` or `infrastructure/` import = FAIL.
   - `application/**` — imports only from `domain/**` + stdlib. Framework imports = FAIL.
   - `infrastructure/**` — may import anything.
4. Checks that new `domain/**` types carry no framework annotations. The default denylist covers the common JVM offenders (`org.springframework.*`, `jakarta.persistence.*`, `javax.persistence.*`, `com.fasterxml.jackson.*`, `io.micronaut.*`, `lombok.*`) and can be extended per-project via a `docs/implementation.md` section `## Forbidden Domain Annotations` (YAML list). The `spear:init` template emits this section empty.
5. On violation: reports file:line:symbol, suggests the fix (move the type, introduce a port interface in domain, etc.), refuses to advance to `refine`.
6. Machine-enforced counterpart: `spear:init` drops a Konsist test on JVM projects so CI enforces the same rules.

## 7. State Machine

### 7.1 `.claude/spear-state.json`

Per-project, gitignored. Example:

```json
{
  "version": 1,
  "currentTaskId": "T-042",
  "reqId": "REQ-017",
  "phase": "engine",
  "testFile": "src/test/kotlin/.../FooTest.kt",
  "testName": "shouldRejectUnknownSymbol",
  "testStatus": "red",
  "evidenceCited": true,
  "lastUpdated": "2026-04-23T12:34:56Z"
}
```

`phase` ∈ `idle | spec | spec-done | prove | prove-done | engine | engine-done | arch | arch-done | refine`.

The `-done` suffix marks "predecessor completed, successor may run" and is what the next skill's gate checks.

### 7.2 Transitions

```
idle --/spear:spec--> spec --(task authored)--> spec-done
spec-done --/spear:prove (TDD task)--> prove --(test red)--> prove-done
prove-done --/spear:engine--> engine --(test green)--> engine-done
engine-done --/spear:arch--> arch --(no violations)--> arch-done
spec-done --/spear:arch (DOC/INFRA task)--> arch --(no violations)--> arch-done
arch-done --/spear:refine--> refine --(task [x])--> idle
```

Each skill refuses to run from a phase that isn't its valid predecessor. Violations surface a human-readable error ("spear:engine requires phase=prove-done; current phase=idle").

### 7.3 Stale-state reconciliation

On session start, `using-spear` reads `spear-state.json` (if present) and re-runs the referenced test to reconcile `testStatus`. If the observed status disagrees with the stored one, the stored value is corrected and the user is notified.

## 8. `spear:init` Flow

1. Detect project language and framework from `build.gradle.kts`, `pom.xml`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`. Pre-fill `tech-stack.md` from the detected dependency coordinates.
2. Interactively gather project purpose, users, and top-level goals. Draft `requirements.md` with initial EARS-formatted `REQ-` entries. **EARS validation covers four of the five canonical patterns**: Ubiquitous (`THE SYSTEM SHALL <response>`), Event-driven (`WHEN <event> THE SYSTEM SHALL <response>`), State-driven (`WHILE <state> THE SYSTEM SHALL <response>`), and Unwanted (`IF <unwanted> THEN THE SYSTEM SHALL <response>`). The Optional Feature pattern (`WHERE <feature-included>`) is not enforced in v1.0.0 and is accepted without validation. Validation is a regex check per line of `requirements.md` under each `REQ-` heading.
3. Gather architectural constraints (layer structure, top-level packages, initial ports/adapters). Draft `implementation.md` including the Layer Dependency Rules section in the exact shape `spear:arch` expects.
4. Derive the initial `tasks.md` from the requirements; each task tagged `TDD`, `DOC`, or `INFRA`; each carries `References:` and an empty `Evidence:` block.
5. JVM project detected → drop `src/test/kotlin/architecture/LayerRulesTest.kt` using Konsist with rules reflecting the layer map. Non-JVM → note it and skip.
6. Commit: `chore(spear): initialize SPEAR docs`.

## 9. Session-Start Hook

`hooks/session-start.sh` (POSIX) and `hooks/session-start.ps1` (Windows) are registered under `SessionStart` in `plugin.json`. Claude Code dispatches the OS-appropriate script.

Responsibilities:

1. Probe for optional tools (§5.2) and cache results.
2. Read `docs/requirements.md` and `docs/tasks.md` if present; detect whether this is a SPEAR project.
3. Read `.claude/spear-state.json` if present; perform stale-state reconciliation.
4. Emit to stdout the `using-spear` text plus dynamic sections (probe results, current task, current phase). Claude Code injects this output into session context as "SessionStart hook additional context" — the same mechanism `superpowers` uses.
5. Exit 0 even when nothing SPEAR-relevant is present; outside a SPEAR project the emitted text is a short no-op notice.

## 10. Composition with `superpowers`

Both plugins inject at session start. SPEAR's reminder defers explicitly:

- `superpowers:brainstorming` → still used before SPEAR `init` on greenfield work.
- `superpowers:writing-plans` / `executing-plans` → still govern plan creation and execution; SPEAR skills run *within* an executing plan.
- `superpowers:test-driven-development` → superseded by `spear:prove` **only when a SPEAR project is detected** (both `docs/requirements.md` and `docs/tasks.md` present). Outside SPEAR projects, `spear:prove` is disabled — invoking it prints a one-line notice ("not a SPEAR project; use superpowers:test-driven-development") and exits without touching the state file. This does not conflict with §7.2 phase-gating, which only applies *inside* SPEAR projects.
- `superpowers:systematic-debugging`, `superpowers:dispatching-parallel-agents` → used as-is.

## 11. Testing Strategy

**(a) Skill-content lint.** Small Node/Bash script. Asserts required frontmatter (`name`, `description`), body length under ceiling, no broken internal links.

**(b) Hook integration tests.** Fixture-based. Set up a temp dir with a scripted `tasks.md` + `spear-state.json`; run `session-start.sh`/`.ps1`; assert the emitted stdout contains the expected sections. One fixture per state (`idle`, mid-`prove`, mid-`engine`, stale-state). The `stale-state` fixture ships with a real JUnit test file and a Gradle wrapper invocation stubbed via a tiny fake `gradle` on `$PATH` that deterministically returns red or green. This makes the reconciliation path (§7.3) actually executed, not just mocked.

**(c) State-machine tests.** A small script simulates skill invocations mutating `spear-state.json`. Asserts linear gating (e.g. `engine` refuses unless `phase === "prove" && testStatus === "red"`), refine-clears-to-idle, etc.

**(d) End-to-end smoke test.** Manual checklist in `TESTING.md`: fresh repo → `/spear:init` → one full task cycle → verify commits, state transitions, Konsist file present. Run before each release.

LLM adherence to skill prose is intentionally **not** covered by tests.

## 12. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Context bloat from session-start injection | Keep `using-spear` ≤ ~40 lines; full skill bodies load on-demand via `Skill` |
| Stale `spear-state.json` when user edits outside Claude | Stale-state reconciliation on session start (re-run referenced test) |
| Double-gating with `superpowers:test-driven-development` | `spear:prove` declares precedence only inside SPEAR projects; no-ops otherwise |
| Over-enforcement on non-TDD work | Phase gating only fires for `TDD`-tagged tasks |
| Cross-platform hook portability | Dual `.sh` + `.ps1` scripts dispatched by OS via `plugin.json` |
| Marketplace schema drift | Pin to current schema (§3); CI lint validates manifests; revisit on Claude Code breaking changes |
| Hook stdout injection is undocumented | Follow the mechanism superpowers already uses in production; watch for breakage in Claude Code release notes |

## 13. Open Questions / Follow-ups

- Non-JVM architecture-test templates (Python via `import-linter`, TS via `dependency-cruiser`, Go via `go-archtest`). Targeted for a future minor.
- Telemetry: should the plugin record anonymized state transitions for methodology tuning? Deferred pending privacy review.
- Submission to `anthropics/claude-plugins-official` after 2–3 months of in-house validation.

## 14. Acceptance Criteria

A v1.0.0 release is acceptable when:

1. `/plugin marketplace add` + `/plugin install spear` succeeds on a clean `~/.claude/`.
2. `/spear:init` in an empty repo produces all four docs, a populated initial `tasks.md`, and (on JVM) a passing Konsist test.
3. A full cycle on one `TDD` task — `spec → prove → engine → arch → refine` — runs end-to-end; the task flips to `[x]` in `tasks.md`; `spear-state.json` returns to `idle`.
4. Attempting `/spear:engine` from `phase: idle` yields a clear gating error.
5. The canonical violation fixture `tests/fixtures/layer-violation/` — a Kotlin file under `domain/` importing from `infrastructure/` — is detected by `/spear:arch`, which blocks progression with a message naming the offending file and import.
6. Session-start hook output appears as "SessionStart hook additional context" and contains the probe results, the current task, and the current phase.
7. All tests in §11 pass in CI.
