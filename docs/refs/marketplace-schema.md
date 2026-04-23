# marketplace.json — Schema Reference

**Captured:** 2026-04-23 from context7 `/websites/code_claude_en_plugins-reference` and verified against `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/.claude-plugin/marketplace.json`.

## Location

`.claude-plugin/marketplace.json` at the repo root of a self-hosted marketplace.

## Purpose

Declares a marketplace and one-or-more plugins installable via `claude plugin install <name>@<marketplace>` or `/plugin install <name>@<marketplace>`.

## Required Fields

| Field        | Type   | Description                                                                      |
| :----------- | :----- | :------------------------------------------------------------------------------- |
| `name`       | string | Marketplace identifier (kebab-case). Used in `@<marketplace>` refs.              |
| `owner`      | object | Marketplace owner. Must contain `name`; `email` recommended.                     |
| `plugins`    | array  | Plugin entries offered by this marketplace. Must be non-empty.                   |

## Plugin Entry Fields

Each entry in `plugins[]`:

| Field         | Type   | Required | Description                                                                                                   |
| :------------ | :----- | :------- | :------------------------------------------------------------------------------------------------------------ |
| `name`        | string | yes      | Plugin identifier. Must match the plugin's `plugin.json#name` and appear as `@<name>` in install commands.    |
| `source`      | string | yes      | Relative path to the plugin root (directory containing `.claude-plugin/plugin.json`). Superpowers uses `./`.  |
| `version`     | string | yes*     | SemVer. Can live in `plugin.json` instead — only ONE of the two needs it; `plugin.json` wins if both present. |
| `description` | string | no       | One-line plugin description. Shown in `/plugin marketplace list`.                                             |
| `author`      | object | no       | Plugin author (can differ from marketplace owner).                                                            |

## Optional Marketplace Fields

| Field         | Type   | Description                                                            |
| :------------ | :----- | :--------------------------------------------------------------------- |
| `description` | string | Shown in `/plugin marketplace` listings.                               |
| `homepage`    | string | Documentation / landing URL.                                           |

## Canonical Example (superpowers@5.0.4)

```json
{
  "name": "superpowers-dev",
  "description": "Development marketplace for Superpowers core skills library",
  "owner": {
    "name": "Jesse Vincent",
    "email": "jesse@fsck.com"
  },
  "plugins": [
    {
      "name": "superpowers",
      "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques",
      "version": "5.0.4",
      "source": "./",
      "author": {
        "name": "Jesse Vincent",
        "email": "jesse@fsck.com"
      }
    }
  ]
}
```

## Install Flow

1. User adds marketplace: `/plugin marketplace add https://github.com/<owner>/<repo>`
2. Claude Code clones the repo, reads `.claude-plugin/marketplace.json`.
3. User installs a plugin: `/plugin install <name>@<marketplace-name>`
4. Plugin's `source` path is resolved relative to the marketplace root; plugin manifest is read from `<source>/.claude-plugin/plugin.json`.

## Validation

Run `claude plugin validate` at the marketplace root. Checks for:
- Valid JSON syntax.
- Required fields present.
- Each `plugins[].source` exists and contains `plugin.json`.
- `plugins[].name` matches the referenced `plugin.json#name`.
