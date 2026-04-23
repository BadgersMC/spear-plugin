# spear-plugin

Claude Code plugin packaging the **SPEAR** methodology — Spec-Proven Engineering with Architectural Requirements — as a reusable, installable plugin.

SPEAR is a hybrid of Spec-Driven Development (EARS), Test-Driven Development (red-green-refactor), and Hexagonal Architecture. This plugin enforces the cycle (blocking implementation before a failing test, blocking progression past layer-boundary violations) and automates the boilerplate (scaffolding the four SPEAR docs, REQ-ID assignment, task state tracking).

**Status:** Design phase. See [docs/design/2026-04-23-spear-plugin-design.md](docs/design/2026-04-23-spear-plugin-design.md).

## Install (once published)

```
/plugin marketplace add BadgersMC/spear-plugin
/plugin install spear@BadgersMC-spear-plugin
```

## Composition

Designed to run alongside [`superpowers`](https://github.com/anthropics/claude-plugins-official). SPEAR defers to superpowers for `brainstorming`, `writing-plans`, `executing-plans`, and `systematic-debugging`; adds SPEAR-specific gates on top.
