import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

// Import the linter — this will fail until lint.mjs exists (RED phase).
import { lintSkills } from './lint.mjs';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/**
 * Create a minimal temp project tree:
 *   <root>/plugins/spear/skills/<skillName>/SKILL.md
 */
function withTempSkillTree(skills, fn) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'spear-lint-'));
  try {
    for (const [skillName, content] of Object.entries(skills)) {
      const dir = path.join(root, 'plugins', 'spear', 'skills', skillName);
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, 'SKILL.md'), content, 'utf8');
    }
    fn(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

/** A fully valid SKILL.md (small body, no internal links). */
const VALID_SKILL = `---
name: Test Skill
description: A valid test skill for unit testing.
---
This is the body of the skill. It is short and valid.
`;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test('valid skill → no errors, ok: true', () => {
  withTempSkillTree({ 'test-skill': VALID_SKILL }, (root) => {
    const result = lintSkills(root);
    assert.equal(result.ok, true);
    assert.deepEqual(result.errors, []);
  });
});

test('empty plugin tree (no SKILL.md files) → ok: true', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'spear-lint-empty-'));
  try {
    // Create the skills dir but put nothing in it.
    fs.mkdirSync(path.join(root, 'plugins', 'spear', 'skills'), { recursive: true });
    const result = lintSkills(root);
    assert.equal(result.ok, true);
    assert.deepEqual(result.errors, []);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('missing description: frontmatter → reported', () => {
  const content = `---
name: No Description Skill
---
Some body text here.
`;
  withTempSkillTree({ 'no-desc': content }, (root) => {
    const result = lintSkills(root);
    assert.equal(result.ok, false);
    assert.equal(result.errors.length, 1);
    assert.match(result.errors[0].reason, /description/i);
  });
});

test('missing name: frontmatter → reported', () => {
  const content = `---
description: No name here
---
Some body text here.
`;
  withTempSkillTree({ 'no-name': content }, (root) => {
    const result = lintSkills(root);
    assert.equal(result.ok, false);
    assert.equal(result.errors.length, 1);
    assert.match(result.errors[0].reason, /name/i);
  });
});

test('missing frontmatter fences entirely → reported', () => {
  const content = `name: No Fences
description: This has no YAML fences.

Some body text here.
`;
  withTempSkillTree({ 'no-fences': content }, (root) => {
    const result = lintSkills(root);
    assert.equal(result.ok, false);
    assert.ok(result.errors.length >= 1);
    assert.match(result.errors[0].reason, /frontmatter/i);
  });
});

test('body exceeding ceiling → reported', () => {
  const longBody = 'x'.repeat(100); // 100 chars > 64-byte ceiling
  const content = `---
name: Huge Body Skill
description: This skill has a body that is too long.
---
${longBody}
`;
  withTempSkillTree({ 'huge-body': content }, (root) => {
    const result = lintSkills(root, { bodyCeilingBytes: 64 });
    assert.equal(result.ok, false);
    assert.equal(result.errors.length, 1);
    assert.match(result.errors[0].reason, /body|ceiling|length/i);
  });
});

test('broken internal link → reported with link target in reason', () => {
  const content = `---
name: Broken Link Skill
description: This skill has a broken internal link.
---
See [missing file](./does-not-exist.md) for details.
`;
  withTempSkillTree({ 'broken-link': content }, (root) => {
    const result = lintSkills(root);
    assert.equal(result.ok, false);
    assert.equal(result.errors.length, 1);
    assert.match(result.errors[0].reason, /does-not-exist\.md/);
  });
});

test('valid internal link resolves correctly → no errors', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'spear-lint-links-'));
  try {
    const skillDir = path.join(root, 'plugins', 'spear', 'skills', 'linked-skill');
    fs.mkdirSync(skillDir, { recursive: true });
    // Create the linked file in the same directory.
    fs.writeFileSync(path.join(skillDir, 'reference.md'), '# Reference\n', 'utf8');
    const content = `---
name: Linked Skill
description: This skill has a valid internal link.
---
See [reference](./reference.md) for details.
`;
    fs.writeFileSync(path.join(skillDir, 'SKILL.md'), content, 'utf8');
    const result = lintSkills(root);
    assert.equal(result.ok, true);
    assert.deepEqual(result.errors, []);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('anchor-only link (#section) is not validated → no errors', () => {
  const content = `---
name: Anchor Link Skill
description: This skill uses an anchor-only link.
---
See [section](#some-section) for details.
`;
  withTempSkillTree({ 'anchor-link': content }, (root) => {
    const result = lintSkills(root);
    assert.equal(result.ok, true);
    assert.deepEqual(result.errors, []);
  });
});

test('external links are not validated → no errors', () => {
  const content = `---
name: External Link Skill
description: This skill uses external links.
---
See [example](https://example.com) and [mailto](mailto:foo@bar.com) for details.
`;
  withTempSkillTree({ 'external-link': content }, (root) => {
    const result = lintSkills(root);
    assert.equal(result.ok, true);
    assert.deepEqual(result.errors, []);
  });
});
