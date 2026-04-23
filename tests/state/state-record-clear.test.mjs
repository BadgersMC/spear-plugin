import { test } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import { withTempProject, runStateSh } from './helpers.mjs';

function readState(dir) {
  return JSON.parse(
    fs.readFileSync(path.join(dir, '.claude/spear-state.json'), 'utf8'),
  );
}

test('state_record_test: writes testFile, testName, testStatus', async () => {
  await withTempProject({ phase: 'prove' }, async (dir) => {
    const r = runStateSh(
      dir,
      'state_record_test',
      'src/test/kotlin/FooTest.kt',
      'FooTest.should_fail_initially',
      'red',
    );
    assert.equal(r.status, 0, r.stderr);
    const json = readState(dir);
    assert.equal(json.testFile, 'src/test/kotlin/FooTest.kt');
    assert.equal(json.testName, 'FooTest.should_fail_initially');
    assert.equal(json.testStatus, 'red');
    assert.equal(json.phase, 'prove');
    assert.equal(json.version, 1);
  });
});

test('state_record_test: atomic via tmp+mv', async () => {
  await withTempProject({ phase: 'prove' }, async (dir) => {
    const file = path.join(dir, '.claude/spear-state.json');
    for (let i = 0; i < 25; i++) {
      const r = runStateSh(dir, 'state_record_test', 'F.kt', 'F.t', i % 2 ? 'red' : 'green');
      assert.equal(r.status, 0, r.stderr);
      JSON.parse(fs.readFileSync(file, 'utf8'));
    }
  });
});

test('state_clear: resets to idle and removes other keys', async () => {
  await withTempProject(
    { phase: 'engine', testFile: 'Foo.kt', testName: 'F.t', testStatus: 'green' },
    async (dir) => {
      const r = runStateSh(dir, 'state_clear');
      assert.equal(r.status, 0, r.stderr);
      const json = readState(dir);
      assert.deepEqual(Object.keys(json).sort(), ['lastUpdated', 'phase', 'version']);
      assert.equal(json.phase, 'idle');
      assert.equal(json.version, 1);
      assert.match(json.lastUpdated, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    },
  );
});

test('state_clear: works when state file is missing', async () => {
  await withTempProject({}, async (dir) => {
    fs.rmSync(path.join(dir, '.claude'), { recursive: true, force: true });
    const r = runStateSh(dir, 'state_clear');
    assert.equal(r.status, 0, r.stderr);
    const json = readState(dir);
    assert.equal(json.phase, 'idle');
    assert.equal(json.version, 1);
  });
});
