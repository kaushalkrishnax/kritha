#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ROOT = path.join(__dirname, '..');
const arg = process.argv[2];

function git(args, options = {}) {
  return execFileSync('git', args, {
    cwd: ROOT,
    encoding: 'utf8',
    ...options,
  });
}

if (!arg || !['--release', '--beta'].includes(arg)) {
  console.error('Usage: node scripts/bump.js <release|beta>');
  process.exit(1);
}

const mode = arg.slice(2);

function getCurrentVersion() {
  const pkg = JSON.parse(
    fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'),
  );
  return pkg.version;
}

function setVersion(newVersion, newVersionCode) {
  const pkgPath = path.join(ROOT, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  pkg.version = newVersion;
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');

  const appJsonPath = path.join(ROOT, 'app.json');
  const appJson = JSON.parse(fs.readFileSync(appJsonPath, 'utf8'));
  appJson.expo.version = newVersion;
  fs.writeFileSync(appJsonPath, JSON.stringify(appJson, null, 2) + '\n');

  const gradlePath = path.join(ROOT, 'android/app/build.gradle');
  let gradle = fs.readFileSync(gradlePath, 'utf8');
  gradle = gradle.replace(/versionName "[^"]+"/, `versionName "${newVersion}"`);
  gradle = gradle.replace(/versionCode \d+/, `versionCode ${newVersionCode}`);
  fs.writeFileSync(gradlePath, gradle);

  console.log(
    `Updated version to ${newVersion} (versionCode ${newVersionCode})`,
  );
}

function bumpRelease(current) {
  const parts = current
    .replace(/-beta\.\d+$/, '')
    .split('.')
    .map(Number);
  parts[2]++;
  return parts.join('.');
}

function bumpBeta(current) {
  const betaMatch = current.match(/^(.+?)-beta\.(\d+)$/);
  if (betaMatch) {
    const base = betaMatch[1];
    const num = parseInt(betaMatch[2], 10) + 1;
    return `${base}-beta.${num}`;
  }
  const parts = current.split('.').map(Number);
  parts[2]++;
  return `${parts.join('.')}-beta.1`;
}

function getVersionCode(current) {
  const parts = current
    .replace(/-beta\.\d+$/, '')
    .split('.')
    .map(Number);
  return parts[0] * 10000 + parts[1] * 100 + parts[2];
}

function ensureTag(version) {
  const tag = `v${version}`;
  const remoteTag = git([
    'ls-remote',
    '--tags',
    'origin',
    `refs/tags/${tag}`,
  ]).trim();

  if (remoteTag) {
    console.log(`Remote tag ${tag} already exists. Nothing to do.`);
    return;
  }

  let previousVersion;
  try {
    previousVersion = JSON.parse(git(['show', 'HEAD^:package.json'])).version;
  } catch {
    console.log('HEAD has no previous version to tag. Nothing to do.');
    return;
  }

  if (previousVersion === version) {
    console.log('HEAD did not bump the package version. Nothing to tag.');
    return;
  }

  const head = git(['rev-parse', 'HEAD']).trim();
  let localTagCommit;
  try {
    localTagCommit = git([
      'rev-parse',
      '--verify',
      `refs/tags/${tag}^{commit}`,
    ]).trim();
  } catch {
    git(['tag', tag]);
  }

  if (localTagCommit && localTagCommit !== head) {
    throw new Error(
      `Local tag ${tag} points to a different commit; refusing to move it.`,
    );
  }

  git(['push', 'origin', `refs/tags/${tag}`], { stdio: 'inherit' });
  console.log(`Tag ${tag} pushed.`);
}

const current = getCurrentVersion();
const uncommittedChanges = git([
  'status',
  '--porcelain',
  '--untracked-files=all',
]).trim();

if (uncommittedChanges) {
  const next = mode === 'release' ? bumpRelease(current) : bumpBeta(current);
  setVersion(next, getVersionCode(next));
  console.log(
    `Commit the version changes manually, then run this command again to push tag v${next}.`,
  );
} else {
  try {
    ensureTag(current);
  } catch (error) {
    console.error(`Failed to push version tag: ${error.message}`);
    process.exitCode = 1;
  }
}
