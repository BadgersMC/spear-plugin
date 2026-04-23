import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const STATE_SH = path.join(REPO_ROOT, 'plugins', 'spear', 'hooks', 'lib', 'state.sh');

export async function withTempProject(seed, fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spear-state-'));
  try {
    fs.mkdirSync(path.join(dir, '.claude'), { recursive: true });
    if (seed && Object.keys(seed).length > 0) {
      const body = { version: 1, ...seed };
      fs.writeFileSync(
        path.join(dir, '.claude', 'spear-state.json'),
        JSON.stringify(body, null, 2),
      );
    }
    await fn(dir);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

export function runStateSh(dir, fn, ...args) {
  return spawnSync('bash', [STATE_SH, fn, ...args], {
    cwd: dir,
    encoding: 'utf8',
    env: {
      ...process.env,
      SPEAR_STATE_FILE: '.claude/spear-state.json',
      SPEAR_INVOKER: process.env.SPEAR_INVOKER || 'spear:test',
    },
  });
}
