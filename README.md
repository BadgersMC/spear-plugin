# spear-plugin

Claude Code plugin packaging the **SPEAR** methodology — **S**pec-**P**roven **E**ngineering with **A**rchitectural **R**equirements — as a reusable, installable plugin.

## 30-second pitch

SPEAR is a hybrid of Spec-Driven Development (EARS), Test-Driven Development (red-green-refactor), and Hexagonal Architecture. The plugin **enforces** the cycle — blocking implementation before a failing test and blocking progression past a layer-boundary violation — and **automates** the boilerplate: scaffolding the four SPEAR docs, assigning REQ-IDs, tracking per-task phase in a gitignored state file.

The cycle:

```
spec → prove → engine → arch → refine
```

Each phase is its own `/spear:<name>` skill. A session-start hook injects the cycle rules, current phase, and tool-probe results into every Claude Code session that runs in a SPEAR project.

## Install

```
/plugin marketplace add BadgersMC/spear-plugin
/plugin install spear@BadgersMC-spear-plugin
/plugin reload-plugins
```

Claude Code caches the plugin at `~/.claude/plugins/cache/BadgersMC-spear-plugin/spear/<version>/`.

## Bootstrap a project

```
/spear:init
```

Detects language/build tool, drafts `docs/tech-stack.md`, `docs/requirements.md`, `docs/implementation.md`, `docs/tasks.md` from bundled templates, and on JVM projects drops a Konsist `LayerRulesTest.kt` wired to your top-level package. Commits the result.

## Run a task

```
/spear:spec      # draft or revise a REQ + derive tasks
/spear:prove     # write the failing test (TDD only)
/spear:engine    # minimum code to flip red → green (TDD only)
/spear:arch      # layer-rule + framework-annotation scan on the diff
/spear:refine    # refactor, confirm suite green, flip task [x], reset state
```

DOC/INFRA tasks skip `prove` and `engine` (`spec-done → arch` directly).

## Composition with `superpowers`

Designed to run alongside [`superpowers`](https://github.com/anthropics/claude-plugins-official). SPEAR defers to superpowers for `brainstorming`, `writing-plans`, `executing-plans`, and `systematic-debugging`. Inside a SPEAR project (`docs/requirements.md` + `docs/tasks.md` both present), `spear:prove` supersedes `superpowers:test-driven-development`; outside it no-ops back to the superpowers entry point.

## Documentation

- [Design spec](docs/design/2026-04-23-spear-plugin-design.md) — why it exists and what it does.
- [Requirements](docs/requirements.md) — EARS-formatted REQ-IDs.
- [Implementation](docs/implementation.md) — architecture, data flows, layer rules.
- [Tasks](docs/tasks.md) — current work.
- [Contributing](CONTRIBUTING.md) — dev workflow.
- [Testing](TESTING.md) — manual E2E checklist and CI overview.

## License

See `LICENSE`.
