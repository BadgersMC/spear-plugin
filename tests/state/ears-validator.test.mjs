import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const EARS_MJS = path.join(REPO_ROOT, 'plugins', 'spear', 'hooks', 'lib', 'ears.mjs');

async function validate(text) {
  // Dynamic import with file:// URL on Windows
  const fileUrl = new URL(`file:///${EARS_MJS.replace(/\\/g, '/')}`);
  const { validate: validateFn } = await import(fileUrl.href + `?t=${Date.now()}`);
  return validateFn(text, 'test-requirements.md');
}

test('EARS validator: accepts Ubiquitous pattern', async () => {
  const content = `### REQ-001 — Test
THE SYSTEM SHALL validate requirements.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts Event-driven pattern', async () => {
  const content = `### REQ-002 — Test
WHEN a user submits a form THE SYSTEM SHALL validate all fields.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts State-driven pattern', async () => {
  const content = `### REQ-003 — Test
WHILE the system is running THE SYSTEM SHALL monitor performance.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts Unwanted pattern', async () => {
  const content = `### REQ-004 — Test
IF a critical error occurs THEN THE SYSTEM SHALL alert the administrator.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts Feature pattern without validation', async () => {
  const content = `### REQ-005 — Test
**Feature.** WHERE user preferences allow THE SYSTEM SHALL customize the interface.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts WHERE clause without pattern label', async () => {
  const content = `### REQ-006 — Test
WHERE user has admin role THE SYSTEM SHALL grant full access.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: rejects malformed entry missing THE SYSTEM SHALL', async () => {
  const content = `### REQ-007 — Test
WHEN a user logs in they are authenticated.`;

  const result = await validate(content);
  assert.equal(result.ok, false);
  assert.equal(result.errors.length, 1);
  assert.equal(result.errors[0].id, 'REQ-007');
  assert.match(result.errors[0].reason, /missing|invalid|pattern/i);
});

test('EARS validator: rejects incomplete Event-driven pattern', async () => {
  const content = `### REQ-008 — Test
WHEN a user submits a form.`;

  const result = await validate(content);
  assert.equal(result.ok, false);
  assert.equal(result.errors.length, 1);
  assert.equal(result.errors[0].id, 'REQ-008');
});

test('EARS validator: mixed file with good and bad entries', async () => {
  const content = `### REQ-010 — Good Ubiquitous
THE SYSTEM SHALL validate requirements.

### REQ-011 — Bad Entry
WHEN something happens it does something.

### REQ-012 — Good Event
WHEN a user logs in THE SYSTEM SHALL authenticate.

### REQ-013 — Another Bad
THE SYSTEM SHOULD validate (should, not shall).`;

  const result = await validate(content);
  assert.equal(result.ok, false);
  assert.equal(result.errors.length, 2);
  const badIds = result.errors.map((e) => e.id).sort();
  assert.deepEqual(badIds, ['REQ-011', 'REQ-013']);
});

test('EARS validator: accepts pattern label prefix (Ubiquitous, Event-driven, etc)', async () => {
  const content = `### REQ-014 — Test
**Ubiquitous.** THE SYSTEM SHALL perform validation.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts pattern label prefix for Event-driven', async () => {
  const content = `### REQ-015 — Test
**Event-driven.** WHEN an event occurs THE SYSTEM SHALL respond.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts pattern label prefix for State-driven', async () => {
  const content = `### REQ-016 — Test
**State-driven.** WHILE a condition holds THE SYSTEM SHALL act.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: accepts pattern label prefix for Unwanted', async () => {
  const content = `### REQ-017 — Test
**Unwanted.** IF bad thing happens THEN THE SYSTEM SHALL mitigate.`;

  const result = await validate(content);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('EARS validator: rejects multiple bad entries and reports all', async () => {
  const content = `### REQ-020 — Bad 1
Invalid clause here.

### REQ-021 — Bad 2
Another invalid one.

### REQ-022 — Good
THE SYSTEM SHALL work.`;

  const result = await validate(content);
  assert.equal(result.ok, false);
  assert.equal(result.errors.length, 2);
  const badIds = result.errors.map((e) => e.id).sort();
  assert.deepEqual(badIds, ['REQ-020', 'REQ-021']);
});
