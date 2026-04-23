import { test } from 'node:test';
import assert from 'node:assert';
import { withTempProject, runStateSh } from './helpers.mjs';

const TDD_PATH = [
  'idle',
  'spec',
  'spec-done',
  'prove',
  'prove-done',
  'engine',
  'engine-done',
  'arch',
  'arch-done',
  'refine',
];

test('state_assert_phase: legal predecessors all pass', async () => {
  for (const phase of TDD_PATH) {
    await withTempProject({ phase }, async (dir) => {
      const r = runStateSh(dir, 'state_assert_phase', phase);
      assert.equal(r.status, 0, `expected pass for phase=${phase}; stderr=${r.stderr}`);
    });
  }
});

test('state_assert_phase: mismatch emits REQ-043 message', async () => {
  await withTempProject({ phase: 'idle' }, async (dir) => {
    const r = runStateSh(dir, 'state_assert_phase', 'prove-done');
    assert.equal(r.status, 1);
    assert.match(r.stderr, /requires phase=prove-done; current phase=idle/);
  });
});

test('state_assert_phase: missing state file defaults to idle', async () => {
  await withTempProject({}, async (dir) => {
    const ok = runStateSh(dir, 'state_assert_phase', 'idle');
    assert.equal(ok.status, 0, `expected idle default; stderr=${ok.stderr}`);
    const fail = runStateSh(dir, 'state_assert_phase', 'spec');
    assert.equal(fail.status, 1);
    assert.match(fail.stderr, /current phase=idle/);
  });
});
