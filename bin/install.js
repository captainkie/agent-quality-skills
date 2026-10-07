#!/usr/bin/env node
// Install the quality-gate skill, and Cloudflare's security-audit skill beside it.
// Same behaviour as install.sh, for machines that have Node.
//
//   npx agent-quality-skills                # both, into ~/.claude/skills
//   npx agent-quality-skills --gate-only    # just the gate, no network needed
//   npx agent-quality-skills --project      # into ./.claude/skills
//   npx agent-quality-skills --dir <path>   # somewhere explicit
//
// Idempotent: re-running updates in place. Nothing outside the chosen skills
// directory is written.
'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SKILLS_SRC = path.join(__dirname, '..', 'skills');
const AUDIT_REPO = 'https://github.com/cloudflare/security-audit-skill';
const AUDIT_SKILL_PATH = path.join('skills', 'security-audit');

function usage() {
  console.log(`usage: npx agent-quality-skills [--gate-only] [--project | --dir <path>]

  (default)      quality-gate + security-audit into ~/.claude/skills (honours CLAUDE_CONFIG_DIR)
  --gate-only    skip the security-audit fetch (no network or git needed)
  --project      install into ./.claude/skills
  --dir <path>   install into <path>`);
}

let dest = null;
let gateOnly = false;
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--gate-only') gateOnly = true;
  else if (a === '--project') dest = path.join(process.cwd(), '.claude', 'skills');
  else if (a === '--dir') {
    if (!args[i + 1]) { console.error('error: --dir needs a path'); process.exit(2); }
    dest = path.resolve(args[++i]);
  } else if (a === '-h' || a === '--help') { usage(); process.exit(0); }
  else { console.error(`unknown option: ${a}`); usage(); process.exit(2); }
}
if (!dest) {
  const base = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
  dest = path.join(base, 'skills');
}

function replaceDir(from, to) {
  fs.rmSync(to, { recursive: true, force: true });
  fs.cpSync(from, to, { recursive: true });
}

fs.mkdirSync(dest, { recursive: true });

// ── 1. the quality gate, from this package ──────────────────────────────────
replaceDir(path.join(SKILLS_SRC, 'quality-gate'), path.join(dest, 'quality-gate'));
console.log('→ quality-gate');

// ── 2. Cloudflare's security-audit skill, fetched from upstream ─────────────
// Fetched rather than vendored, so it stays current and its MIT licence and
// attribution travel with its own files. Announced only after it lands.
if (!gateOnly) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'aqs-'));
  try {
    const clone = spawnSync('git', ['clone', '--depth', '1', '--quiet', AUDIT_REPO, path.join(tmp, 'audit')], { stdio: 'ignore' });
    if (clone.error) {
      console.log('!  git not found — skipped security-audit. Install git, or use --gate-only.');
    } else if (clone.status !== 0) {
      console.log(`!  could not reach ${AUDIT_REPO} — skipped.`);
      console.log('   The gate works without it; its security axis just loses the domain references.');
    } else {
      const src = path.join(tmp, 'audit', AUDIT_SKILL_PATH);
      if (fs.existsSync(src)) {
        replaceDir(src, path.join(dest, 'security-audit'));
        const lic = path.join(tmp, 'audit', 'LICENSE');
        if (fs.existsSync(lic)) fs.copyFileSync(lic, path.join(dest, 'security-audit', 'LICENSE'));
        console.log(`→ security-audit  (${AUDIT_REPO}, MIT)`);
      } else {
        console.log(`!  upstream layout changed — '${AUDIT_SKILL_PATH}' not found. Skipped.`);
      }
    }
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

console.log(`\ninstalled into: ${dest}`);
console.log('\nNext (optional): put the per-project config template in your repo root:');
console.log('  curl -fsSL https://raw.githubusercontent.com/captainkie/agent-quality-skills/main/templates/QUALITY-GATE.md -o QUALITY-GATE.md');
