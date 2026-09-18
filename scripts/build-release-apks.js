#!/usr/bin/env node

const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const androidDir = path.join(root, 'android');
const gradle = process.platform === 'win32' ? 'gradlew.bat' : './gradlew';
const architectures = ['arm64-v8a', 'x86_64'];

for (const architecture of architectures) {
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
}

console.log('\nRelease APKs:');
for (const architecture of architectures) {
  console.log(
    `android/app/build/outputs/apk/release/Kritha-0.1.1-${architecture}.apk`,
  );
}
