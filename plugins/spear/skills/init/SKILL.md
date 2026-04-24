---
name: spear:init
description: Bootstrap SPEAR docs in a greenfield project — detects stack, drafts the four docs, drops Konsist template on JVM, commits.
---

# spear:init — Greenfield SPEAR Scaffolding

Invoked via `/spear:init`. Runs on a clean project (no SPEAR docs yet). Phase gating: init has no predecessor phase; it sets context so later `/spear:spec` can run from `idle`. Init itself is idempotent and does NOT require a prior phase.

Templates live under `plugins/spear/templates/` (plain text reference — not a link). The four templates are `tech-stack.md`, `requirements.md`, `implementation.md`, `tasks.md`; the JVM-only Konsist drop is `LayerRulesTest.kt`.

Opus orchestrates. Once detection is complete and placeholders are enumerated, Opus MAY dispatch a Sonnet subagent to mechanically fill template placeholders (briefing contract applies: exact paths, acceptance criteria, forbidden actions).

## Procedure

### 1. Detect language/framework (REQ-070)

Probe the project root for these files, in order, and record which exist:

- `build.gradle.kts`, `build.gradle`, `pom.xml`  -> JVM
- `package.json`                                  -> Node
- `pyproject.toml`                                -> Python
- `Cargo.toml`                                    -> Rust
- `go.mod`                                        -> Go

For each detected manifest, parse dependency coordinates and pre-fill `docs/tech-stack.md` (language, framework, versions, build tool). If none match, emit a one-line notice and proceed with a blank `tech-stack.md`.

### 2. Interactive drafting — requirements (REQ-071, REQ-072, REQ-073)

Ask the user (in this order): project purpose, primary users, top 3–5 goals. Draft `docs/requirements.md` with EARS-formatted entries.

**Validate every REQ entry BEFORE writing** by shelling out to the EARS validator:

```
node plugins/spear/hooks/lib/ears.mjs "<candidate-line>"
```

Exit 0 = valid. Non-zero = reject and re-draft. REQ-IDs are the next free integer above the max existing (padded to three digits, e.g. `REQ-001`); never re-use or renumber.

### 3. Architectural constraints (REQ-071)

Draft `docs/implementation.md` from the template. It MUST contain, verbatim in shape:

- A `## Layer Dependency Rules` section listing domain <- application <- infrastructure precedence (exact heading is required by `spear:arch`).
- An empty `## Forbidden Domain Annotations` section whose YAML body is `forbidden: []` (exact heading + key required by `spear:arch`).

These two sections are load-bearing. Do not rename, merge, or reorder them.

### 4. Derive tasks.md (REQ-074)

Generate `docs/tasks.md`. Every initial task MUST:

- Carry exactly one tag: `TDD`, `DOC`, or `INFRA`.
- Include a `References:` line listing the REQ-IDs and doc sections it implements.
- Include an empty `Evidence:` block (the task owner fills it during execution).

### 5. JVM Konsist drop (REQ-065)

IF JVM was detected in step 1:

Copy `plugins/spear/templates/LayerRulesTest.kt` to `src/test/kotlin/architecture/LayerRulesTest.kt`. Substitute `__BASE_PACKAGE__` with the detected top-level package (read from Gradle/Maven config, e.g. `group` + main source-set package). Create parent directories as needed.

### 6. Non-JVM notice (REQ-066)

IF the project is not JVM, emit one line to stdout naming the skipped template, e.g.:

```
Skipping Konsist template plugins/spear/templates/LayerRulesTest.kt (non-JVM project).
```

### 7. Commit (REQ-075)

Stage exactly the four generated docs plus the Konsist file when emitted:

```
git add docs/tech-stack.md docs/requirements.md docs/implementation.md docs/tasks.md
# plus src/test/kotlin/architecture/LayerRulesTest.kt on JVM
git commit -m "chore(spear): initialize SPEAR docs"
```

Do not include any other paths in this commit.

## Acceptance

- Four docs exist under `docs/`.
- On JVM, `LayerRulesTest.kt` exists at the required path with `__BASE_PACKAGE__` substituted.
- Every REQ in `requirements.md` passes the EARS validator.
- Every task in `tasks.md` has a tag, `References:`, and an empty `Evidence:` block.
- A single commit with the required subject contains exactly the listed files.
