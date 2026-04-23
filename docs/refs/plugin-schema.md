# plugin.json — Schema Reference

**Captured:** 2026-04-23 from context7 `/websites/code_claude_en_plugins-reference`.

## Location

`.claude-plugin/plugin.json` at the plugin root.

## Required Fields

If a manifest is provided, `name` is the only required field.

| Field  | Type   | Description                               | Example              |
| :----- | :----- | :---------------------------------------- | :------------------- |
| `name` | string | Unique identifier (kebab-case, no spaces) | `"deployment-tools"` |

Used for namespacing components — e.g. agent `foo` in plugin `bar` appears as `bar:foo`.

## Metadata Fields

| Field         | Type   | Description                                                                                                                 | Example                                            |
| :------------ | :----- | :-------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------- |
| `version`     | string | Semantic version. If also set in the marketplace entry, `plugin.json` takes priority. You only need to set it in one place. | `"2.1.0"`                                          |
| `description` | string | Brief explanation of plugin purpose                                                                                         | `"Deployment automation tools"`                    |
| `author`      | object | Author information                                                                                                          | `{"name": "Dev Team", "email": "dev@company.com"}` |
| `homepage`    | string | Documentation URL                                                                                                           | `"https://docs.example.com"`                       |
| `repository`  | string | Source code URL                                                                                                             | `"https://github.com/user/plugin"`                 |
| `license`     | string | License identifier                                                                                                          | `"MIT"`, `"Apache-2.0"`                            |
| `keywords`    | array  | Discovery tags                                                                                                              | `["deployment", "ci-cd"]`                          |

## Component Path Fields

All optional; omit to accept default discovery locations.

| Field          | Type            | Default Location             | Description                                                             |
| :------------- | :-------------- | :--------------------------- | :---------------------------------------------------------------------- |
| `skills`       | string\|array   | `./skills/`                  | Directories containing `<name>/SKILL.md`.                               |
| `commands`     | string\|array   | `./commands/`                | Flat `.md` skill files (slash commands).                                |
| `agents`       | string\|array   | `./agents/`                  | Agent `.md` files with required frontmatter.                            |
| `hooks`        | string\|object  | `./hooks/hooks.json`         | Path to hooks config, or inline hooks object.                           |
| `mcpServers`   | string\|object  | `./.mcp.json`                | MCP server configs.                                                     |
| `outputStyles` | string\|array   | `./output-styles/`           | Custom output style files/directories.                                  |
| `lspServers`   | string\|object  | `./.lsp.json`                | Language server configs.                                                |
| `monitors`     | string\|array   | `./monitors.json`            | Background monitor definitions.                                         |
| `userConfig`   | object          | —                            | User-prompted config values at enable time.                             |
| `channels`     | array           | —                            | Message channel declarations (bind to MCP servers).                     |
| `dependencies` | array           | —                            | Other plugins this plugin requires.                                     |

## Directory Structure (correct layout)

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json      ← Only the manifest here
├── skills/              ← At plugin root, NOT under .claude-plugin/
├── commands/
├── agents/
├── hooks/
│   └── hooks.json
└── ...
```

> Component directories MUST live at the plugin root. Only `plugin.json` belongs inside `.claude-plugin/`.

## Canonical Example

```json
{
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"],
  "agents": "./custom/agents/",
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "monitors": "./monitors.json",
  "dependencies": [
    "helper-lib",
    { "name": "secrets-vault", "version": "~2.1.0" }
  ]
}
```

## Validation

```bash
claude plugin validate    # CLI
/plugin validate          # inside a Claude Code session
```

Checks `plugin.json` syntax/schema, skill/agent/command frontmatter, and `hooks/hooks.json`.
