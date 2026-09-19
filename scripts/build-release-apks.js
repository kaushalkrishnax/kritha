#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const root = path.resolve(__dirname, '..');
const androidDir = path.join(root, 'android');
const gradle = process.platform === 'win32' ? 'gradlew.bat' : './gradlew';
const architectures = ['arm64-v8a', 'x86_64'];
const outputDir = path.join(root, 'dist', 'release-apks');
const apkOutputDir = path.join(
  androidDir,
  'app',
  'build',
  'outputs',
  'apk',
  'release',
);
const archivedApks = [];
const generatedBuildDirs = [
  path.join(androidDir, 'app', 'build'),
  path.join(androidDir, 'app', '.cxx'),
  path.join(root, 'modules', 'kritha', 'android', 'build'),
  path.join(root, 'modules', 'kritha', 'android', '.cxx'),
  path.join(root, 'modules', 'kritha', 'android', 'feature_litert', 'build'),
  path.join(root, 'modules', 'kritha', 'android', 'feature_litert', '.cxx'),
  path.join(root, 'modules', 'kritha', 'android', 'feature_litertlm', 'build'),
  path.join(root, 'modules', 'kritha', 'android', 'feature_litertlm', '.cxx'),
  path.join(root, 'modules', 'kritha', 'android', 'feature_onnx', 'build'),
  path.join(root, 'modules', 'kritha', 'android', 'feature_onnx', '.cxx'),
];

fs.rmSync(outputDir, { recursive: true, force: true });
fs.mkdirSync(outputDir, { recursive: true });

for (const architecture of architectures) {
  for (const generatedBuildDir of generatedBuildDirs) {
    fs.rmSync(generatedBuildDir, { recursive: true, force: true });
  }

  const result = spawnSync(
    gradle,
    ['assembleRelease', `-PreactNativeArchitectures=${architecture}`],
    {
      cwd: androidDir,
      env: process.env,
      stdio: 'inherit',
      shell: process.platform === 'win32',
    },
  );

  if (result.error) {
    console.error(
      `Failed to start Gradle for ${architecture}: ${result.error.message}`,
    );
    process.exit(1);
  }

  if (result.status !== 0) {
    console.error(`Release APK build failed for ${architecture}.`);
    process.exit(result.status ?? 1);
  }

  const builtApkNames = fs
    .readdirSync(apkOutputDir)
    .filter(
      (name) =>
        name.endsWith(`-${architecture}.apk`) && name.startsWith('Kritha-'),
    );

  if (builtApkNames.length === 0) {
    console.error(
      `Expected APK for ${architecture} was not generated in ${apkOutputDir}`,
    );
    process.exit(1);
  }

  for (const builtApkName of builtApkNames) {
    const builtApk = path.join(apkOutputDir, builtApkName);
    const archivedApk = path.join(outputDir, builtApkName);

    fs.copyFileSync(builtApk, archivedApk);
    archivedApks.push(path.relative(root, archivedApk));
  }
}

console.log('\nRelease APKs:');
for (const archivedApk of archivedApks) {
  console.log(archivedApk);
}
