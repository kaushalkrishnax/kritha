#!/usr/bin/env node

// Build and archive the signed Kritha release artifacts.
//
//   node scripts/build-release.js --platform android  # split APKs: arm64 + x64
//   node scripts/build-release.js --platform aab       # one store bundle
//   node scripts/build-release.js --platform ios       # unsigned arm64 device + host-arch simulator .apps
//   node scripts/build-release.js --platform app       # App Store Connect IPA
//   node scripts/build-release.js --platform macos     # separate arm64 + x86_64 .apps
//   node scripts/build-release.js --platform windows   # x86_64 signed release zip

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const platforms = new Set(['android', 'aab', 'app', 'ios', 'macos', 'windows']);
const platform = process.argv[3];

if (process.argv[2] !== '--platform' || !platforms.has(platform)) {
  console.error(
    'Usage: node scripts/build-release.js --platform <android|aab|app|ios|macos|windows>',
  );
  process.exit(2);
}

const flutter = process.platform === 'win32' ? 'flutter.bat' : 'flutter';

function run(command, args, { shell = process.platform === 'win32' } = {}) {
  const result = spawnSync(command, args, {
    cwd: ROOT,
    env: process.env,
    stdio: 'inherit',
    shell,
  });
  if (result.error) throw new Error(`Could not start ${command}: ${result.error.message}`);
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(' ')} failed with status ${result.status ?? 'unknown'}.`);
  }
}

function flutterBuild(args) {
  run(flutter, ['build', ...args]);
}

function buildMacosArchitecture(arch) {
  flutterBuild(['macos', '--release', '--config-only']);
  const buildDirectory = path.join(ROOT, 'build', 'macos');
  run('xcodebuild', [
    '-workspace',
    'macos/Runner.xcworkspace',
    '-scheme',
    'Runner',
    '-configuration',
    'Release',
    '-derivedDataPath',
    buildDirectory,
    '-destination',
    'platform=macOS',
    `ARCHS=${arch}`,
    'ONLY_ACTIVE_ARCH=NO',
    `OBJROOT=${path.join(buildDirectory, 'Build', 'Intermediates.noindex')}`,
    `SYMROOT=${path.join(buildDirectory, 'Build', 'Products')}`,
    'COMPILER_INDEX_STORE_ENABLE=NO',
  ], { shell: false });
}

function readVersion() {
  const pubspec = fs.readFileSync(path.join(ROOT, 'pubspec.yaml'), 'utf8');
  const match = pubspec.match(/^version:\s*([^+\s]+)(?:\+\d+)?\s*$/m);
  if (!match) throw new Error('Could not read version from pubspec.yaml.');
  return match[1];
}

function requireLocalSigningFile(relativePath, description) {
  const file = path.join(ROOT, relativePath);
  if (!fs.existsSync(file)) {
    throw new Error(
      `Missing ${relativePath}. Copy the adjacent .example template, configure it locally, and retry (${description}).`,
    );
  }
  const contents = fs.readFileSync(file, 'utf8');
  if (/YOUR_TEAM_ID|REPLACE_WITH/.test(contents)) {
    throw new Error(`${relativePath} still contains template placeholders.`);
  }
  return file;
}

function copyFile(source, destination) {
  if (!fs.existsSync(source)) throw new Error(`Expected release output not found: ${source}`);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
  console.log(`Created ${path.relative(ROOT, destination)}`);
}

function copyBundle(source, destination) {
  if (!fs.existsSync(source)) throw new Error(`Expected release output not found: ${source}`);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.rmSync(destination, { recursive: true, force: true });
  fs.cpSync(source, destination, { recursive: true });
  console.log(`Created ${path.relative(ROOT, destination)}`);
}

function verifyArchitectures(binary, expected) {
  const result = spawnSync('lipo', ['-info', binary], { encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(`Could not inspect binary architectures: ${binary}`);
  }
  const info = `${result.stdout}\n${result.stderr}`;
  const architectureMatch = info.match(/are:\s*(.+)/) ?? info.match(/architecture:\s*(.+)/);
  const actual = architectureMatch?.[1].trim().split(/\s+/).sort() ?? [];
  const wanted = [...expected].sort();
  if (actual.join(',') !== wanted.join(',')) {
    throw new Error(
      `Expected exactly ${wanted.join(', ')} in ${binary}; lipo reported: ${info.trim()}`,
    );
  }
}

function verifySignedBundle(bundle, { allowAdHoc = false } = {}) {
  run('codesign', ['--verify', '--deep', '--strict', bundle]);
  const result = spawnSync('codesign', ['-dv', '--verbose=2', bundle], {
    encoding: 'utf8',
  });
  const details = `${result.stdout}\n${result.stderr}`;
  if (result.status !== 0 || (!allowAdHoc && !details.includes('Authority='))) {
    throw new Error(`Expected a Developer ID/Distribution signature on ${bundle}; ad-hoc signing is not a release signature.`);
  }
  if (allowAdHoc && !details.includes('Authority=')) {
    console.log(`Verified local ad-hoc signature on ${path.relative(ROOT, bundle)}; distribution signing is still required.`);
  }
}

function verifyIosIpa(ipa) {
  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'kritha-ipa-'));
  try {
    run('ditto', ['-x', '-k', ipa, temporaryDirectory]);
    const payload = path.join(temporaryDirectory, 'Payload');
    const appName = fs.readdirSync(payload).find((name) => name.endsWith('.app'));
    if (!appName) throw new Error('The exported IPA contains no Payload/*.app bundle.');
    const app = path.join(payload, appName);
    verifyArchitectures(path.join(app, 'Runner'), ['arm64']);
    verifySignedBundle(app);
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

function requireAndroidSigning() {
  const properties = path.join(ROOT, 'android', 'key.properties');
  if (!fs.existsSync(properties)) {
    throw new Error(
      'Missing android/key.properties. Copy android/key.example.properties and configure your private keystore first.',
    );
  }
}

function buildAndroidApks(version) {
  requireAndroidSigning();
  flutterBuild([
    'apk',
    '--release',
    '--split-per-abi',
    '--target-platform=android-arm64,android-x64',
  ]);

  const output = path.join(ROOT, 'build', 'app', 'outputs', 'flutter-apk');
  const dist = path.join(ROOT, 'dist', 'android');
  for (const abi of ['arm64-v8a', 'x86_64']) {
    const source = path.join(output, `app-${abi}-release.apk`);
    copyFile(source, path.join(dist, `Kritha-${version}-${abi}-RELEASE.apk`));
  }
}

function buildAndroidBundle(version) {
  requireAndroidSigning();
  flutterBuild([
    'appbundle',
    '--release',
    '--target-platform=android-arm64,android-x64',
  ]);
  copyFile(
    path.join(ROOT, 'build', 'app', 'outputs', 'bundle', 'release', 'app-release.aab'),
    path.join(ROOT, 'dist', 'android', `Kritha-${version}-universal-RELEASE.aab`),
  );
}

function buildIosApp(version, ipa) {
  requireLocalSigningFile(
    'ios/Flutter/Signing.xcconfig',
    'Apple team and Xcode signing configuration',
  );

  if (ipa) {
    const exportOptions = requireLocalSigningFile(
      'ios/ExportOptions.plist',
      'App Store Connect IPA export settings',
    );
    flutterBuild(['ipa', '--release', `--export-options-plist=${exportOptions}`]);
    const ipaDirectory = path.join(ROOT, 'build', 'ios', 'ipa');
    const candidates = fs.existsSync(ipaDirectory)
      ? fs.readdirSync(ipaDirectory)
          .filter((name) => name.endsWith('.ipa'))
          .map((name) => path.join(ipaDirectory, name))
          .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)
      : [];
    if (candidates.length === 0) throw new Error('Flutter did not produce an IPA.');
    const destination = path.join(
      ROOT,
      'dist',
      'ios',
      `Kritha-${version}-arm64-RELEASE.ipa`,
    );
    verifyIosIpa(candidates[0]);
    copyFile(candidates[0], destination);
    return;
  }

  flutterBuild(['ios', '--release', '--no-codesign']);
  const deviceApp = path.join(ROOT, 'build', 'ios', 'iphoneos', 'Runner.app');
  verifyArchitectures(path.join(deviceApp, 'Runner'), ['arm64']);
  console.log('Verified unsigned local iOS device build; distribution signing is still required.');
  copyBundle(
    deviceApp,
    path.join(ROOT, 'dist', 'ios', `Kritha-${version}-arm64-RELEASE.app`),
  );

  flutterBuild(['ios', '--release', '--no-codesign', '--simulator']);
  const simulatorArch = process.arch === 'arm64' ? 'arm64' : 'x86_64';
  const simApp = path.join(ROOT, 'build', 'ios', 'iphonesimulator', 'Runner.app');
  if (!fs.existsSync(simApp)) {
    throw new Error(`Flutter did not produce the iOS simulator app at ${simApp}.`);
  }
  verifyArchitectures(path.join(simApp, 'Runner'), [simulatorArch]);
  console.log(`Verified unsigned local iOS ${simulatorArch} simulator build.`);
  copyBundle(
    simApp,
    path.join(ROOT, 'dist', 'ios', `Kritha-${version}-${simulatorArch}-SIMULATOR-RELEASE.app`),
  );
}

function buildMacos(version, archs) {
  const signingFile = requireLocalSigningFile(
    'macos/Runner/Configs/Signing.xcconfig',
    'Apple team and macOS signing identity',
  );
  const signingConfig = fs.readFileSync(signingFile, 'utf8');
  const allowAdHoc = /KRITHA_MACOS_SIGNING_IDENTITY\s*=\s*["']?-\s*["']?/m.test(signingConfig);
  const targets = archs ?? ['macos-arm64', 'macos-x64'];
  const apps = [];
  for (const target of targets) {
    const arch = target === 'macos-arm64' ? 'arm64' : 'x86_64';
    buildMacosArchitecture(arch);
    const app = path.join(
      ROOT,
      'build',
      'macos',
      'Build',
      'Products',
      'Release',
      'Kritha.app',
    );
    const binary = path.join(app, 'Contents', 'MacOS', 'Kritha');
    verifyArchitectures(binary, [arch]);
    verifySignedBundle(app, { allowAdHoc });
    const distApp = path.join(
      ROOT,
      'dist',
      'macos',
      `Kritha-${version}-${arch}-RELEASE.app`,
    );
    copyBundle(app, distApp);
    apps.push(distApp);
  }
  return apps;
}

function buildWindows(version) {
  if (process.platform !== 'win32') {
    throw new Error('Windows release builds must run on a Windows x64 host with Visual Studio installed.');
  }
  flutterBuild(['windows', '--release']);

  const releaseDirectory = path.join(
    ROOT,
    'build',
    'windows',
    'x64',
    'runner',
    'Release',
  );
  const executable = path.join(releaseDirectory, 'kritha.exe');
  if (!fs.existsSync(executable)) {
    throw new Error(`Expected Windows x64 executable not found: ${executable}`);
  }

  const destination = path.join(
    ROOT,
    'dist',
    'windows',
    `Kritha-${version}-x86_64-RELEASE.zip`,
  );
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  run(
    'powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      path.join(ROOT, 'scripts', 'archive-windows.ps1'),
      '-SourceDirectory',
      releaseDirectory,
      '-DestinationZip',
      destination,
    ],
    { shell: false },
  );
  if (!fs.existsSync(destination)) {
    throw new Error(`Windows release archive was not created: ${destination}`);
  }
  console.log(`Created ${path.relative(ROOT, destination)}`);
}

try {
  const version = readVersion();
  switch (platform) {
    case 'android':
      buildAndroidApks(version);
      break;
    case 'aab':
      buildAndroidBundle(version);
      break;
    case 'app':
      buildIosApp(version, true);
      break;
    case 'ios':
      buildIosApp(version, false);
      break;
    case 'macos':
      buildMacos(version);
      break;
    case 'windows':
      buildWindows(version);
      break;
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
