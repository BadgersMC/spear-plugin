/**
 * tests/skills/lint.mjs
 *
 * SKILL.md lint script (REQ-100).
 *
 * Exported API:
 *   lintSkills(rootDir, options?) -> { ok: boolean, errors: Array<{ file, line?, reason }> }
 *
 * CLI:
 *   node tests/skills/lint.mjs <rootDir>
 *   Exits 0 (pass) or 1 (fail). Prints "path[:line]: reason" to stderr.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_BODY_CEILING_BYTES = 4096;

// ---------------------------------------------------------------------------
// File walker
// ---------------------------------------------------------------------------

/** Recursively collect all SKILL.md paths under dir. */
function findSkillFiles(dir) {
  const results = [];
  if (!fs.existsSync(dir)) return results;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findSkillFiles(full));
    } else if (entry.isFile() && entry.name === 'SKILL.md') {
      results.push(full);
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// Per-file validators
// ---------------------------------------------------------------------------

/**
 * Parse frontmatter. Returns { ok, frontmatter, bodyStart, bodyLines } where
 * bodyStart is the 1-based line number of the first line after the closing ---.
 * Returns { ok: false } when fences are missing.
 */
function parseFrontmatter(lines) {
  // First line must be '---'
  if (lines[0]?.trim() !== '---') {
    return { ok: false };
  }

  // Find closing '---'
  let closeIdx = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      closeIdx = i;
      break;
    }
  }
  if (closeIdx === -1) {
    return { ok: false };
  }

  const frontmatterLines = lines.slice(1, closeIdx);
  const bodyLines = lines.slice(closeIdx + 1);

  return {
    ok: true,
    frontmatterLines,
    bodyStartLine: closeIdx + 2, // 1-based
    bodyLines,
  };
}

/** Extract value of a key from frontmatter lines. Returns null if not found or empty. */
function getFrontmatterValue(frontmatterLines, key) {
  const re = new RegExp(`^${key}:\\s*(\\S.*)$`);
  for (const line of frontmatterLines) {
    const m = line.match(re);
    if (m) return m[1].trim();
  }
  return null;
}

/** Extract all internal markdown links from text. Returns [{href, line}]. */
function extractInternalLinks(lines) {
  const links = [];
  // Match [text](href) — capture href
  const linkRe = /\[([^\]]*)\]\(([^)]+)\)/g;

  lines.forEach((line, idx) => {
    let m;
    linkRe.lastIndex = 0;
    while ((m = linkRe.exec(line)) !== null) {
      const href = m[2];
      // Skip external and anchor-only
      if (
        href.startsWith('http://') ||
        href.startsWith('https://') ||
        href.startsWith('mailto:') ||
        href.startsWith('#')
      ) {
        continue;
      }
      links.push({ href, line: idx + 1 });
    }
  });
  return links;
}

// ---------------------------------------------------------------------------
// Main lint function
// ---------------------------------------------------------------------------

/**
 * @param {string} rootDir  Project root containing plugins/spear/skills/
 * @param {{ bodyCeilingBytes?: number }} [options]
 * @returns {{ ok: boolean, errors: Array<{ file: string, line?: number, reason: string }> }}
 */
export function lintSkills(rootDir, options = {}) {
  const ceiling = options.bodyCeilingBytes ?? DEFAULT_BODY_CEILING_BYTES;
  const skillsDir = path.join(rootDir, 'plugins', 'spear', 'skills');
  const files = findSkillFiles(skillsDir);

  const errors = [];

  for (const filePath of files) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const lines = raw.split('\n');

    // --- 1. Frontmatter fences ---
    const parsed = parseFrontmatter(lines);
    if (!parsed.ok) {
      errors.push({
        file: filePath,
        line: 1,
        reason: 'missing frontmatter: file must begin with --- ... --- YAML block',
      });
      // Cannot validate further without frontmatter
      continue;
    }

    const { frontmatterLines, bodyStartLine, bodyLines } = parsed;

    // --- 2. Required frontmatter keys ---
    const nameVal = getFrontmatterValue(frontmatterLines, 'name');
    if (!nameVal) {
      errors.push({
        file: filePath,
        line: 1,
        reason: 'missing frontmatter key: "name" must be present with a non-empty value',
      });
    }

    const descVal = getFrontmatterValue(frontmatterLines, 'description');
    if (!descVal) {
      errors.push({
        file: filePath,
        line: 1,
        reason: 'missing frontmatter key: "description" must be present with a non-empty value',
      });
    }

    // --- 3. Body length ---
    const bodyText = bodyLines.join('\n');
    const bodyBytes = Buffer.byteLength(bodyText, 'utf8');
    if (bodyBytes > ceiling) {
      errors.push({
        file: filePath,
        line: bodyStartLine,
        reason: `body length ${bodyBytes} bytes exceeds ceiling of ${ceiling} bytes`,
      });
    }

    // --- 4. Internal links ---
    const allLines = lines.map((l, i) => ({ text: l, lineNo: i + 1 }));
    const internalLinks = extractInternalLinks(lines);

    for (const { href, line } of internalLinks) {
      // Strip fragment
      const hrefNoFragment = href.replace(/#.*$/, '');
      if (!hrefNoFragment) continue; // pure fragment after strip — skip

      const resolved = path.resolve(path.dirname(filePath), hrefNoFragment);
      if (!fs.existsSync(resolved)) {
        errors.push({
          file: filePath,
          line,
          reason: `broken internal link: "${hrefNoFragment}" does not exist`,
        });
      }
    }
  }

  return { ok: errors.length === 0, errors };
}

// ---------------------------------------------------------------------------
// CLI shim
// ---------------------------------------------------------------------------

const isMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isMain) {
  const rootDir = process.argv[2];
  if (!rootDir) {
    process.stderr.write('Usage: node tests/skills/lint.mjs <rootDir>\n');
    process.exit(2);
  }

  const { ok, errors } = lintSkills(rootDir);
  for (const err of errors) {
    const loc = err.line != null ? `${err.file}:${err.line}` : err.file;
    process.stderr.write(`${loc}: ${err.reason}\n`);
  }
  process.exit(ok ? 0 : 1);
}
