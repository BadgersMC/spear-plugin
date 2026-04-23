# hooks.json — Schema Reference (SessionStart focus)

**Captured:** 2026-04-23 from context7 `/websites/code_claude_en_plugins-reference`.

## Location

Per `plugin.json#hooks` — default `hooks/hooks.json` at plugin root. Can also be inlined as an object under `plugin.json#hooks`.

## Top-Level Shape

```json
{
  "hooks": {
    "<EventName>": [
      {
        "matcher": "<regex-like pattern>",
        "hooks": [
          { "type": "command|http|prompt|agent", "command": "..." }
        ]
      }
    ]
  }
}
```

## Event Names

Case-sensitive. Relevant events for this plugin:

| Event             | Fires on                                                                  |
| :---------------- | :------------------------------------------------------------------------ |
| `SessionStart`    | Each new Claude Code session: `startup`, `clear`, or `compact` sub-reasons |
| `PostToolUse`     | After any tool invocation                                                  |
| `PreToolUse`      | Before any tool invocation                                                 |
| `PostCompact`     | After context compaction                                                   |
| `Elicitation`     | MCP server requests user input during a tool call                          |
| `SessionEnd`      | Session terminates                                                         |

## Matcher

For `SessionStart`, the matcher filters by sub-reason. The canonical pattern that fires on every session start is:

```
"matcher": "startup|clear|compact"
```

For `PostToolUse`/`PreToolUse`, the matcher filters by tool name (e.g. `"Write|Edit"`).

## Hook Types

| Type       | Behavior                                                                                     |
| :--------- | :------------------------------------------------------------------------------------------- |
| `command`  | Execute a shell command or script. Most common.                                              |
| `http`     | POST the event JSON to the specified URL.                                                    |
| `prompt`   | Send a prompt to an LLM. Uses `$ARGUMENTS` for event context.                                |
| `agent`    | Run an agentic verifier with tools.                                                          |

## Command Hook Fields

```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd session-start",
  "async": false
}
```

- `command` (required) — the shell/executable invocation. Reference plugin files via `${CLAUDE_PLUGIN_ROOT}`.
- `async` (optional) — when `true`, Claude does not wait for the command to finish. Default behavior is synchronous. For `SessionStart` context injection, set `async: false`.

## SessionStart Stdout Contract

A SessionStart `command` hook can inject context by writing JSON to stdout:

**Claude Code:**
```json
{ "hookSpecificOutput": { "additionalContext": "<text to inject>" } }
```

**Cursor:**
```json
{ "additional_context": "<text to inject>" }
```

Claude Code ignores a non-JSON stdout (it is treated as log output). The hook MUST exit 0 to avoid blocking the session; non-zero exit aborts session start.

## Canonical SessionStart Example (mirrored from superpowers@5.0.4)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

## Environment Variables Available in Hooks

| Var                     | Value                                                              |
| :---------------------- | :----------------------------------------------------------------- |
| `CLAUDE_PLUGIN_ROOT`    | Absolute path to plugin root (Claude Code).                        |
| `CURSOR_PLUGIN_ROOT`    | Same, but set by Cursor instead of Claude Code.                    |
| `CLAUDE_PLUGIN_DATA`    | Plugin-writable data directory (per-user persistent).              |
| `CLAUDE_PLUGIN_OPTION_<KEY>` | Resolved `userConfig` value for `<KEY>`.                       |

## Script Requirements

- **Shebang:** `#!/usr/bin/env bash` (or equivalent).
- **Executable:** `chmod +x` in repo. On Windows, polyglot `.cmd` wrapper handles the executable bit.
- **Non-blocking:** never exit non-zero on internal errors during session start; prefer logging + `exit 0` to keep the session usable.
- **Bounded output:** Claude Code truncates very large `additionalContext` payloads (~4 KB soft ceiling).

## Validation

`claude plugin validate` verifies the `hooks.json` schema and event-name casing. Manual smoke test:

```bash
./hooks/run-hook.cmd session-start
```
