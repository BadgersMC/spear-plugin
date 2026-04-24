# Contributing to spear-plugin

Thanks for working on SPEAR. This repo follows its own methodology — contributions go through the `spec → prove → engine → arch → refine` cycle driven by `/spear:<name>` slash commands once the plugin is installed.

## Dev environment

- **OS:** Linux, macOS, or Windows (Git Bash). CI runs on Ubuntu; Windows is smoke-tested for the `run-hook.cmd` polyglot wrapper.
- **Node.js:** 20 LTS (for lint + state-machine tests).
- **Bats-core:** 1.10+ (for hook integration tests). Install locally at `~/.local/bin/bats` or via package manager.
- **jq:** 1.6+ (for state-file I/O inside bash helpers).

Tests:

```
PATH="$HOME/.local/bin:$HOME/bin:$PATH" \
  bats tests/hooks/ \
  && node --test tests/state/*.test.mjs \
  && node --test tests/skills/*.test.mjs
```

Skill lint (REQ-100):

```
node tests/skills/lint.mjs .
```

## Repo layout

See [docs/implementation.md §1](docs/implementation.md). Briefly:

```
.claude-plugin/marketplace.json          # marketplace manifest
plugins/spear/
  .claude-plugin/plugin.json             # plugin manifest
  skills/<name>/SKILL.md                 # the seven SPEAR skills
  hooks/run-hook.cmd, session-start, lib/*.sh
  templates/*.md, LayerRulesTest.kt      # emitted by /spear:init
tests/hooks/    # Bats
tests/skills/   # Node lint + unit tests
tests/state/    # Node state-machine tests
docs/           # the four SPEAR docs + design refs
```

## How to contribute

1. **Open an issue** describing the change. If it adds or revises behaviour, state which REQ-ID it maps to (or propose a new one).
2. **Fork + branch.** Use a short descriptive branch name.
3. **Run the methodology on yourself.** Every non-trivial change is a SPEAR task:
   - Add or revise a REQ in `docs/requirements.md` (EARS format — use `/spear:spec`).
   - Add a task in `docs/tasks.md` tagged `TDD`, `DOC`, or `INFRA`, with `References:` and an empty `Evidence:` block.
   - For TDD tasks: write a failing test first (`/spear:prove`), then minimum implementation (`/spear:engine`), then `/spear:arch`, then `/spear:refine`.
4. **Keep tests green.** Do not raise the skill lint ceiling (4096 bytes/body) to fit a larger skill — trim the skill instead. The ceiling is load-bearing for the session-start payload.
5. **Commit convention.** `docs(spear):`, `test(spear):`, `feat(spear):`, `fix(spear):`, `chore(spear):`. Include a `Co-Authored-By:` trailer when AI assisted.
6. **Pull request.** Reference the REQ-IDs and tasks covered. The PR template will ask for evidence sources consulted.

## Skill-body authoring rules

- YAML frontmatter with non-empty `name:` and `description:`.
- Body ≤ 4096 bytes (UTF-8). Enforced by `tests/skills/lint.mjs`.
- No broken internal markdown links. External and anchor-only links are allowed.
- Paths to files inside the repo should be plain backticked text, not markdown link syntax — otherwise the lint resolves them on disk and fails if the target doesn't exist yet.

## Template-authoring rules

Templates under `plugins/spear/templates/` use `{{PLACEHOLDER}}` tokens that `/spear:init` substitutes from language/framework detection. The Konsist template uses `__BASE_PACKAGE__` for the consumer's detected top-level package.

## Worktree discipline

This repo uses git worktrees heavily for parallel Claude sessions. Before any commit, verify:

```
git -C <worktree> branch --show-current
```

matches the expected branch. A prior session lost a commit by running `git commit` in the wrong worktree. Prefer absolute paths and `git -C <worktree>` over relying on shell cwd.

## Releasing

Semver. Bump `plugin.json:version` and tag. Run the manual E2E checklist in [TESTING.md](TESTING.md) before each release.
