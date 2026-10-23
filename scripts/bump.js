#!/usr/bin/env node

// Two-phase version lifecycle helper:
//   1. With a dirty worktree, update pubspec.yaml and package.json.
//   2. Commit those changes, then re-run to create a local vX.Y.Z tag.
// Push the tag yourself after reviewing it.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const mode = process.argv[2];
if (!['--release', '--beta'].includes(mode)) {
  console.error('Usage: node scripts/bump.js <--release|--beta>');
  process.exit(2);
}

const pubspecPath = path.join(ROOT, 'pubspec.yaml');
const packagePath = path.join(ROOT, 'package.json');

function git(args) {
  return execFileSync('git', args, { cwd: ROOT, encoding: 'utf8' }).trim();
}

function parseVersion(source) {
  const match = source.match(/^version:\s*(\S+)\s*$/m);
  if (!match) throw new Error('Could not find pubspec.yaml version.');
  const [name, build = '0'] = match[1].split('+');
  if (!/^\d+\.\d+\.\d+(?:-beta\.\d+)?$/.test(name) || !/^\d+$/.test(build)) {
    throw new Error(`Unsupported version format: ${match[1]}`);
  }
  return { name, build: Number(build) };
}

function nextVersion({ name, build }) {
  if (mode === '--beta') {
    const beta = name.match(/^(\d+\.\d+\.\d+)-beta\.(\d+)$/);
    const nextName = beta
      ? `${beta[1]}-beta.${Number(beta[2]) + 1}`
      : `${name}-beta.1`;
    return { name: nextName, build: build + 1 };
  }

  const beta = name.match(/^(\d+\.\d+\.\d+)-beta\.\d+$/);
  if (beta) return { name: beta[1], build: build + 1 };

  const [major, minor, patch] = name.split('.').map(Number);
  return { name: `${major}.${minor}.${patch + 1}`, build: build + 1 };
}

function updateVersion(version) {
  const pubspec = fs.readFileSync(pubspecPath, 'utf8');
  fs.writeFileSync(
    pubspecPath,
    pubspec.replace(
      /^version:\s*\S+\s*$/m,
      `version: ${version.name}+${version.build}`,
    ),
  );

  const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
  packageJson.version = version.name;
  fs.writeFileSync(packagePath, `${JSON.stringify(packageJson, null, 2)}\n`);
}

try {
  const current = parseVersion(fs.readFileSync(pubspecPath, 'utf8'));
  if (git(['status', '--porcelain', '--untracked-files=all'])) {
    const next = nextVersion(current);
    updateVersion(next);
    console.log(`Updated version to ${next.name}+${next.build}. Commit the version change.`);
    process.exit(0);
  }

  let previous;
  try {
    previous = parseVersion(git(['show', 'HEAD^:pubspec.yaml']));
  } catch {
    throw new Error('No parent commit is available to verify the version bump.');
  }
  if (current.name === previous.name && current.build === previous.build) {
    throw new Error('HEAD does not contain a version change to tag.');
  }

  const tag = `v${current.name}`;
  try {
    git(['rev-parse', '--verify', `refs/tags/${tag}^{commit}`]);
    throw new Error(`Tag ${tag} already exists; refusing to move it.`);
  } catch (error) {
    if (error.message.includes('already exists')) throw error;
  }
  git(['tag', tag]);
  console.log(`Created local tag ${tag}. Review and push it with: git push origin ${tag}`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
