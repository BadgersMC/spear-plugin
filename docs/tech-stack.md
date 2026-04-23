# Tech Stack — SPEAR Plugin

**Date:** 2026-04-23
**Status:** Bootstrap (authored by hand from `2026-04-23-spear-plugin-design.md` because `/spear:init` does not yet exist)
**Owner:** BadgersMC

## 1. What this project is

A Claude Code **plugin** distributed via a self-hosted marketplace. The repo IS the marketplace. Output artifact is prose (skill markdown), shell scripts (hooks), JSON manifests, and template files — there is no compiled binary, no service to deploy.

## 2. Runtimes & languages

| Layer | Language / Tool | Min version | Reason |
|---|---|---|---|
| Skills | Markdown + YAML frontmatter | n/a | Required by Claude Code skill format |
| Manifests | JSON | spec — Claude Code plugins reference | `marketplace.json` + `plugin.json` schema |
| Session-start hook | Bash (POSIX `sh` compatible) | 4.0+ | Polyglot wrapper requires `${var//pat/sub}` |
| Cross-platform hook dispatch | `cmd.exe` polyglot wrapper | n/a | Mirrors `superpowers/hooks/run-hook.cmd` |
| State file I/O | `jq` 1.6+ | 1.6 | JSON read/write inside hook + skill scripts |
| Hook integration tests | Bats-core | 1.10+ | Standard POSIX shell test runner |
| State-machine + lint tests | Node.js | 20 LTS | JSON manipulation, fs walk; ships in CI image |
| JVM Layer test template | Kotlin + Konsist | Konsist 0.17+ | Layer-rule enforcement at JVM CI; emitted by `spear:init` only when JVM project detected |

**Why bash + Node, not pure Node?** Hooks must execute before Claude Code reads any session context. Bash starts in <50 ms; a Node process incurs ~150 ms cold start. Bash also matches the canonical Anthropic-blessed pattern (superpowers).

**Why Bats for hook tests, Node for state-machine tests?** Hook scripts are bash → use the native shell test runner. State-file mutations are pure JSON → easier asserted in JS.

## 3. Pinned external schemas

| Schema | Source of truth | Snapshot location |
|---|---|---|
| `marketplace.json` | https://code.claude.com/docs/en/plugins-reference | `docs/refs/marketplace-schema.md` (to be captured at task INFRA-02) |
| `plugin.json` | same | `docs/refs/plugin-schema.md` (INFRA-02) |
| Hook `hooks.json` event names + `hookSpecificOutput` shape | same | `docs/refs/hook-schema.md` (INFRA-02) |

**Evidence for this section:** `context7:/websites/code_claude_en_plugins-reference` (retrieved 2026-04-23). All three schemas are authoritative; pin the field set at v1 and revisit on Claude Code minor releases.

## 4. Reference implementations consulted

| Concern | Reference | Local path |
|---|---|---|
| SessionStart hook stdout injection mechanism (undocumented detail per design §12 risk row) | `superpowers@5.0.4` | `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/hooks/session-start` |
| Cross-platform polyglot wrapper (cmd.exe + bash in one file) | `superpowers@5.0.4` | `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/hooks/run-hook.cmd` |
| Marketplace manifest layout | `superpowers@5.0.4` | `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/.claude-plugin/marketplace.json` |
| Plugin manifest minimal form | `superpowers@5.0.4` | `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/.claude-plugin/plugin.json` |
| Hook registration JSON | `superpowers@5.0.4` | `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/hooks/hooks.json` |

The design document explicitly authorises mirroring superpowers where Claude Code documentation is silent (design §5.1 evidence source order; §12 risk "Hook stdout injection is undocumented").

## 5. Spec amendments adopted at bootstrap

**§9 / §3.1 — Cross-platform hook dispatch.** Original spec specified dual `session-start.sh` + `session-start.ps1`. Verification against context7 (`/websites/code_claude_en_plugins-reference`) shows Claude Code's `hooks.json` accepts a single `command` per matcher with no documented OS-switch. The proven pattern is the `superpowers` polyglot:

- `hooks/run-hook.cmd` — single file, cmd.exe interprets the `@echo off` block (locates Git-for-Windows bash and execs the named script), bash interprets the same file (the cmd block is wrapped in a `: << 'CMDBLOCK'` no-op heredoc).
- `hooks/session-start` — extensionless POSIX bash script.
- `hooks/hooks.json` registers `${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd session-start` once.

Approved 2026-04-23 by repo owner. PowerShell variant removed from §3.1 layout.

## 6. Tools the plugin probes for at runtime

Per design §5.2 the session-start hook probes for the following and announces availability in the injected `using-spear` text. These are **not** required dependencies — fallbacks are documented:

| Probed tool | Use | Fallback |
|---|---|---|
| `context7` MCP | Library/API doc lookup | Source-on-disk → `WebFetch` |
| `mgrep` skill | Code search | `Grep` / `Glob` |
| `semgrep` | Pattern / vulnerability scanning | `mgrep` / `Grep` |

Probe is a presence check only (skill/MCP listed in session metadata). No version pinning at probe time.

## 7. CI

GitHub Actions, single workflow (`ci.yml`):

1. `skill-content lint` — Node script per design §11.a.
2. `state-machine tests` — Node, runs against `tests/state/*` fixtures per §11.c.
3. `hook integration tests` — Bats on Ubuntu runner per §11.b.
4. `manifest validate` — `claude plugin validate` invoked via the Claude Code CLI image once available; until then a JSON-schema check using a vendored copy of the plugin-reference schemas.

Windows job runs only the polyglot-wrapper smoke test (verify `run-hook.cmd` from cmd.exe locates bash and produces non-empty stdout).

## 8. Out of stack

- No web framework, no database, no message bus.
- No Python, no Go, no Rust toolchains in CI.
- Konsist Kotlin test is a **template emitted into consumer projects**; it is not built or run in this repo.
