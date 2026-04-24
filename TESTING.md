# Testing — spear-plugin

Two layers of testing ship with this repo: automated (CI-enforced) and a **manual end-to-end checklist** exercised before every release (REQ-103).

## Automated tests

Run all three suites locally:

```
PATH="$HOME/.local/bin:$HOME/bin:$PATH" \
  bats tests/hooks/ \
  && node --test tests/state/*.test.mjs \
  && node --test tests/skills/*.test.mjs
```

Skill-body lint only (REQ-100):

```
node tests/skills/lint.mjs .
```

| Suite | Runner | Scope | Spec |
|---|---|---|---|
| `tests/hooks/*.bats` | Bats-core 1.10+ | Session-start hook behaviour across fixture projects (idle, prove-in-progress, engine-in-progress, stale-state) | REQ-080..085, REQ-049 |
| `tests/state/*.test.mjs` | `node --test` | State-file linear gating, TDD path, DOC/INFRA path, refine-clears-to-idle | REQ-042..048 |
| `tests/skills/*.test.mjs` + `tests/skills/lint.mjs` | `node --test` + CLI | SKILL.md frontmatter, body ≤ 4096 bytes, no broken internal links; EARS four-pattern validator | REQ-100, REQ-072 |

CI job in `.github/workflows/ci.yml` runs all three on Ubuntu plus a Windows smoke test for the polyglot wrapper.

## Manual E2E checklist (REQ-103)

Run every item before cutting a release. Log outcomes in the **Release log** section below.

### Preparation

- [ ] Check out the release candidate branch.
- [ ] Remove any local plugin cache: `rm -rf ~/.claude/plugins/cache/BadgersMC-spear-plugin`.
- [ ] Create a scratch directory with an empty git repo: `mkdir /tmp/spear-e2e && cd /tmp/spear-e2e && git init`.

### 1. Install flow (REQ-120, TDD-90)

- [ ] Open a Claude Code session in the scratch directory.
- [ ] Run `/plugin marketplace add BadgersMC/spear-plugin` (or the local file path during pre-release). Expect no schema-validation errors.
- [ ] Run `/plugin install spear@BadgersMC-spear-plugin`. Expect success.
- [ ] Run `/plugin reload-plugins`.
- [ ] Verify cache path exists: `~/.claude/plugins/cache/BadgersMC-spear-plugin/spear/<version>/`.
- [ ] Close and reopen the session; confirm **SessionStart hook additional context** contains cycle rules, probe results, and a "not a SPEAR project" notice (scratch dir has no docs yet).

### 2. `/spear:init` regenerates the four docs (REQ-121, TDD-91)

- [ ] In the scratch session run `/spear:init`.
- [ ] Interactively answer prompts for project name, owner, primary language.
- [ ] Verify `docs/tech-stack.md`, `docs/requirements.md`, `docs/implementation.md`, `docs/tasks.md` are created.
- [ ] On a JVM scratch project: verify `src/test/kotlin/architecture/LayerRulesTest.kt` exists and has `__BASE_PACKAGE__` substituted with the detected package.
- [ ] On a non-JVM scratch project: verify a one-line notice names the skipped Konsist template.
- [ ] Verify the commit exists with subject `chore(spear): initialize SPEAR docs` containing exactly the four docs (+ Konsist file on JVM).
- [ ] Diff the four docs against this repo's hand-authored `docs/` — structure must match; REQ-IDs may differ.

### 3. Session-start hook emits context in a SPEAR project (REQ-124)

- [ ] Reopen the session in the scratch project.
- [ ] Verify **SessionStart hook additional context** contains:
  - [ ] Cycle rules (spec → prove → engine → arch → refine).
  - [ ] Probe results for `context7`, `mgrep`, `semgrep`.
  - [ ] Current task placeholder (empty — no task in progress).
  - [ ] Current phase: `idle`.
  - [ ] Deferral list pointing to `superpowers:brainstorming`, `writing-plans`, `executing-plans`, `systematic-debugging`.

### 4. Full TDD cycle on one task (REQ-122, v1.0.0 gate)

> Deferred to v1.0.0 acceptance — document here for completeness; skip in v0.1.0 release run.

- [ ] Pick a `TDD`-tagged task from the generated `tasks.md`.
- [ ] Run `/spear:spec` to add Evidence. Verify `.claude/spear-state.json` shows `phase: spec-done`.
- [ ] Run `/spear:prove`. Verify a failing test is created, `testStatus: red`, `phase: prove-done`.
- [ ] Run `/spear:engine`. Verify the test flips green, `phase: engine-done`.
- [ ] Run `/spear:arch`. Verify no violations, `phase: arch-done`.
- [ ] Run `/spear:refine`. Verify task flipped `[x]` in `tasks.md`, `.claude/spear-state.json` reset to `phase: idle`.

### 5. Gating errors (REQ-043)

- [ ] From `phase: idle` invoke `/spear:engine`. Expect `spear:engine requires phase=prove-done; current phase=idle`. No state mutation.

### 6. Layer violation fixture (REQ-123, v1.0.0 gate)

> Deferred to v1.0.0 acceptance.

- [ ] Run `/spear:arch` against `tests/fixtures/layer-violation/` (Kotlin file under `domain/` importing `infrastructure/`).
- [ ] Expect failure output naming the offending file and import. Expect refusal to advance to `refine`.

## Release log

Append one entry per release. Include date, version, and a checklist copy of which items passed / failed.

### v0.1.0 — (unreleased)

- [ ] Run date: ____
- [ ] Runner: ____
- [ ] Results: TDD-90 ____, TDD-91 ____

<!-- Append new entries above this line, most recent first. -->
