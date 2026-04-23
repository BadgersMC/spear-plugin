import { test } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import { withTempProject, runStateSh } from './helpers.mjs';

test('state_set_phase: writes valid JSON with version:1', async () => {
  await withTempProject({}, async (dir) => {
    const r = runStateSh(dir, 'state_set_phase', 'spec-done');
    assert.equal(r.status, 0, r.stderr);
    const json = JSON.parse(
      fs.readFileSync(path.join(dir, '.claude/spear-state.json'), 'utf8'),
    );
    assert.equal(json.version, 1);
    assert.equal(json.phase, 'spec-done');
    assert.match(json.lastUpdated, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
  });
});

test('state_set_phase: preserves other keys on existing state', async () => {
  await withTempProject({ phase: 'idle', testStatus: 'green', testFile: 'Foo.kt' }, async (dir) => {
    const r = runStateSh(dir, 'state_set_phase', 'engine');
    assert.equal(r.status, 0, r.stderr);
    const json = JSON.parse(
      fs.readFileSync(path.join(dir, '.claude/spear-state.json'), 'utf8'),
    );
    assert.equal(json.phase, 'engine');
    assert.equal(json.testStatus, 'green');
    assert.equal(json.testFile, 'Foo.kt');
  });
});

test('state_set_phase: atomic via tmp+mv (no partial reads)', async () => {
  await withTempProject({}, async (dir) => {
    const file = path.join(dir, '.claude/spear-state.json');
    for (let i = 0; i < 50; i++) {
      const r = runStateSh(dir, 'state_set_phase', i % 2 ? 'spec' : 'idle');
      assert.equal(r.status, 0, r.stderr);
      const raw = fs.readFileSync(file, 'utf8');
      JSON.parse(raw);
    }
  });
});

test('state_set_phase: creates .claude dir if missing', async () => {
  await withTempProject({}, async (dir) => {
    fs.rmSync(path.join(dir, '.claude'), { recursive: true, force: true });
    const r = runStateSh(dir, 'state_set_phase', 'spec');
    assert.equal(r.status, 0, r.stderr);
    assert.ok(fs.existsSync(path.join(dir, '.claude/spear-state.json')));
  });
});
