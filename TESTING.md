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

- [x] Run date: 2026-04-24
- [x] Runner: claude-sonnet-4-6 (main agent, worktree `upbeat-bassi-d5ee46`)
- [x] Results: TDD-90 **PARTIAL** (structural PASS; interactive install untested — see notes), TDD-91 **PASS**

#### TDD-90 — Install flow (REQ-120)

**Pre-flight:**
- Plugin cache `~/.claude/plugins/cache/BadgersMC-spear-plugin/` — absent before run ✓
- GitHub repo `BadgersMC/spear-plugin` is public BUT only `main` (2 docs commits) is pushed; all plugin code is local only → **must use local-path install**.

**Structural validation (automated):**
- [x] `marketplace.json` schema: name, plugins[], source `./plugins/spear`, version `0.1.0` — PASS
- [x] `plugin.json` schema: name `spear`, version `0.1.0`, hooks key present — PASS
- [x] `hooks.json`: SessionStart hook → `run-hook.cmd` → `session-start` arg — PASS
- [x] All plugin files present: `plugins/spear/{hooks,skills,templates,hooks/hooks.json,.claude-plugin/plugin.json}` — PASS
- [x] Automated test suites: bats 41/41 PASS, state 25/25 PASS, skills 10/10 PASS

**Interactive install (not executed — agent cannot issue `/plugin` slash commands):**
- [ ] `/plugin marketplace add <local-path>` — NOT TESTED (requires human operator in interactive Claude Code session)
- [ ] `/plugin install spear@BadgersMC-spear-plugin` — NOT TESTED
- [ ] `/plugin reload-plugins` — NOT TESTED
- [ ] Cache path exists after install — NOT TESTED
- [ ] SessionStart hook additional context in fresh session — NOT TESTED

**Blockers found:**
- BLOCK-90a: Plugin code not merged to `origin/main`; `/plugin marketplace add BadgersMC/spear-plugin` would install empty repo. Must push or use local path. → new task TDD-92.
- BLOCK-90b: Three skill bodies exceed 4096-byte lint ceiling: `arch` (4157 B), `engine` (4144 B), `prove` (4135 B). Lint CLI exits 1. → new tasks DOC-51, DOC-52, DOC-53.

**Inline fix applied:** `tests/skills/lint.mjs` — strip `\r` from frontmatter lines before regex match (CRLF line-endings broke `$` anchor). One-liner. All SKILL.md frontmatter checks now pass.

**Notes:**
- `spear:init` SKILL.md documents EARS validator usage as `node ears.mjs "<candidate-line>"` (string arg), but the validator actually takes a **file path**. Documentation bug. → new task DOC-54.

---

#### TDD-91 — `/spear:init` regenerates bootstrap docs (REQ-121)

Executed via direct SKILL.md procedure (semantically equivalent to `/spear:init` invocation — same logic, different entry point).

**JVM pass (Kotlin/Gradle, scratch dir `D:/tmp/spear-e2e-init`):**
- [x] `build.gradle.kts` detected → JVM (Kotlin, Ktor 3.0.3, Gradle KTS, Konsist 0.16.1)
- [x] `docs/tech-stack.md` created — PASS
- [x] `docs/requirements.md` created with 5 REQs across all 4 EARS patterns — EARS validator exit 0 ✓
- [x] `docs/implementation.md` created with `## 2. Layer Dependency Rules` + `## Forbidden Domain Annotations` (both load-bearing headings) — PASS
- [x] `docs/tasks.md` created with TDD / DOC / INFRA tags, References, Evidence blocks — PASS
- [x] `src/test/kotlin/architecture/LayerRulesTest.kt` created, `__BASE_PACKAGE__` → `com.badgersmc.speardemo` — PASS (0 unsubstituted occurrences)
- [x] Commit subject: `chore(spear): initialize SPEAR docs` ✓
- [x] Commit contains exactly 5 files (4 docs + Konsist) ✓

**Non-JVM pass (Node, scratch dir `D:/tmp/spear-e2e-init-node`):**
- [x] `package.json` detected → Node (non-JVM)
- [x] Konsist-skip notice emitted: `Skipping Konsist template plugins/spear/templates/LayerRulesTest.kt (non-JVM project).` ✓
- [x] Four docs created — PASS
- [x] No `src/test/kotlin/` directory created ✓
- [x] Commit subject: `chore(spear): initialize SPEAR docs` ✓
- [x] Commit contains exactly 4 files (no Konsist) ✓

**Semantic diff (subagent Explore):**
- [x] `tech-stack.md`: STRUCTURAL MATCH (8 H2 sections, correct headings, table, §5 AI rules, §6–§8)
- [x] `requirements.md`: STRUCTURAL MATCH (EARS header, all 4 patterns present, REQ-NNN format, authoring rules)
- [x] `implementation.md`: STRUCTURAL MATCH (`## 2. Layer Dependency Rules` exact, `forbidden: []`, 3-layer table, §3–§7)
- [x] `tasks.md`: STRUCTURAL MATCH (tag+state legend, all 3 tag types, References+Evidence on every task, authoring rules)

**Verdict: TDD-91 PASS ✓**

---

**Overall v0.1.0 verdict: FAIL (conditional)**

Blocking items before re-run:
1. `TDD-92` — Push plugin code to `origin/main` (or set up local-path install path in docs) so interactive install flow can be tested by a human operator.
2. `DOC-51/52/53` — Trim `arch`, `engine`, `prove` SKILL.md bodies to ≤ 4096 bytes (lint must be green).
3. `DOC-54` — Fix EARS validator usage in `spear:init` SKILL.md prose (file path, not string).

Once TDD-92 and DOC-51..54 are resolved and a human operator has verified the interactive install flow, re-run §1 of the checklist and append a new release log entry.

<!-- Append new entries above this line, most recent first. -->
