#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ROOT = path.resolve(__dirname, '..');
const ANDROID_DIR = path.join(ROOT, 'android');
const APP_DIR = path.join(ANDROID_DIR, 'app');
const GRADLEW = path.join(
  ANDROID_DIR,
  process.platform === 'win32' ? 'gradlew.bat' : 'gradlew',
);

const VARIANT = (process.env.GD_VARIANT || 'release').trim();
const VARIANT_CAP = VARIANT.charAt(0).toUpperCase() + VARIANT.slice(1);

const OUTPUT_DIR = path.join(ROOT, 'dist', 'globally-dynamic', VARIANT);

const BUNDLETOOL_VERSION = process.env.BUNDLETOOL_VERSION || '1.18.3';

const BUNDLETOOL_DIR = path.join(ROOT, 'tools');

const BUNDLETOOL_JAR =
  process.env.BUNDLETOOL_JAR ||
  path.join(BUNDLETOOL_DIR, `bundletool-all-${BUNDLETOOL_VERSION}.jar`);

const DEFAULT_ABIS = ['arm64-v8a', 'x86_64'];

const ABIS = (process.env.GD_ABIS || DEFAULT_ABIS.join(','))
  .split(',')
  .map((x) => x.trim())
  .filter(Boolean);

const SCREEN_DENSITY = Number(process.env.GD_SCREEN_DENSITY || 420);

const SDK_VERSION = Number(process.env.GD_SDK_VERSION || 35);

// Bundletool requires at least one supported locale.
const LOCALES = (process.env.GD_LOCALES || 'en-US')
  .split(',')
  .map((x) => x.trim())
  .filter(Boolean);

if (!LOCALES.length) {
  fail('GD_LOCALES must contain at least one locale.');
}

function readGradleProperties(file) {
  if (!fs.existsSync(file)) {
    return {};
  }

  const result = {};

  for (const rawLine of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();

    if (!line || line.startsWith('#') || line.startsWith('!')) {
      continue;
    }

    const index = line.search(/[=:]/);

    if (index === -1) {
      continue;
    }

    const key = line.slice(0, index).trim();
    const value = line.slice(index + 1).trim();

    result[key] = value;
  }

  return result;
}

function loadGradleProperties() {
  return {
    ...readGradleProperties(
      path.join(os.homedir(), '.gradle', 'gradle.properties'),
    ),
    ...readGradleProperties(path.join(ANDROID_DIR, 'gradle.properties')),
  };
}

const gradleProps = loadGradleProperties();

function property(name, envName = name) {
  return (process.env[envName] ?? gradleProps[name] ?? '').trim();
}

const STORE_FILE = property('KRITHA_RELEASE_STORE_FILE');

const STORE_PASSWORD = property('KRITHA_RELEASE_STORE_PASSWORD');

const KEY_ALIAS = property('KRITHA_RELEASE_KEY_ALIAS');

const KEY_PASSWORD = property('KRITHA_RELEASE_KEY_PASSWORD');

function fail(message) {
  console.error(`\nERROR: ${message}\n`);
  process.exit(1);
}

function run(command, args, options = {}) {
  console.log(`\n> ${command} ${args.join(' ')}`);

  const result = spawnSync(command, args, {
    stdio: 'inherit',
    cwd: options.cwd || ROOT,
    shell: false,
    env: process.env,
  });

  if (result.error) {
    fail(`Failed to start ${command}: ${result.error.message}`);
  }

  if (result.status !== 0) {
    fail(`Command failed with exit code ${result.status}`);
  }
}

function runGradle(args) {
  if (process.platform === 'win32') {
    run(GRADLEW, args, {
      cwd: ANDROID_DIR,
    });
  } else {
    run('bash', [GRADLEW, ...args], {
      cwd: ANDROID_DIR,
    });
  }
}

function bundletool(args) {
  const result = spawnSync('java', ['-jar', BUNDLETOOL_JAR, ...args], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
  });

  if (result.error) {
    fail(`Failed to start Java/bundletool: ${result.error.message}`);
  }

  if (result.status !== 0) {
    console.error(result.stdout || '');
    console.error(result.stderr || '');
    fail('bundletool command failed');
  }

  return result.stdout.trim();
}

async function ensureBundletool() {
  if (fs.existsSync(BUNDLETOOL_JAR)) {
    return;
  }

  fs.mkdirSync(BUNDLETOOL_DIR, {
    recursive: true,
  });

  const url =
    'https://github.com/google/bundletool/releases/download/' +
    `${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar`;

  console.log(`\nDownloading bundletool ${BUNDLETOOL_VERSION}...`);

  console.log(url);

  const response = await fetch(url);

  if (!response.ok) {
    fail(`Failed to download bundletool: HTTP ${response.status}`);
  }

  const buffer = Buffer.from(await response.arrayBuffer());

  fs.writeFileSync(BUNDLETOOL_JAR, buffer);

  console.log(`Saved ${path.relative(ROOT, BUNDLETOOL_JAR)}`);
}

function readDynamicFeatures() {
  const buildGradlePath = path.join(APP_DIR, 'build.gradle');

  if (!fs.existsSync(buildGradlePath)) {
    fail(`android/app/build.gradle not found:\n${buildGradlePath}`);
  }

  const buildGradle = fs.readFileSync(buildGradlePath, 'utf8');

  const match = buildGradle.match(/dynamicFeatures\s*\+=\s*\[([\s\S]*?)\]/m);

  if (!match) {
    fail('Could not find dynamicFeatures in android/app/build.gradle');
  }

  const features = [...match[1].matchAll(/['"]:([^'"]+)['"]/g)].map(
    (match) => match[1],
  );

  if (!features.length) {
    fail('No dynamic feature modules found in android/app/build.gradle');
  }

  return features;
}

function combinations(values) {
  const result = [];

  for (let mask = 1; mask < 1 << values.length; mask++) {
    const combo = [];

    for (let i = 0; i < values.length; i++) {
      if (mask & (1 << i)) {
        combo.push(values[i]);
      }
    }

    result.push(combo);
  }

  return result;
}

function findAab() {
  const bundleDir = path.join(APP_DIR, 'build', 'outputs', 'bundle', VARIANT);

  if (!fs.existsSync(bundleDir)) {
    fail(`Bundle output directory does not exist: ${bundleDir}`);
  }

  const candidates = fs
    .readdirSync(bundleDir)
    .filter((name) => name.endsWith('.aab'))
    .map((name) => path.join(bundleDir, name));

  if (!candidates.length) {
    fail(`No .aab found in ${bundleDir}`);
  }

  candidates.sort();

  if (candidates.length > 1) {
    console.log('\nMultiple AABs found; using the first one alphabetically:');

    console.log(candidates.map((x) => `  ${path.basename(x)}`).join('\n'));
  }

  return candidates[0];
}

function readBundleMetadata(aabPath) {
  const applicationId = bundletool([
    'dump',
    'manifest',
    `--bundle=${aabPath}`,
    '--xpath=/manifest/@package',
  ]);

  const versionCodeRaw = bundletool([
    'dump',
    'manifest',
    `--bundle=${aabPath}`,
    '--xpath=/manifest/@android:versionCode',
  ]);

  const versionName = bundletool([
    'dump',
    'manifest',
    `--bundle=${aabPath}`,
    '--xpath=/manifest/@android:versionName',
  ]);

  const versionCode = Number(versionCodeRaw);

  if (!applicationId) {
    fail('Could not read applicationId from AAB');
  }

  if (!Number.isInteger(versionCode)) {
    fail(`Invalid versionCode returned by bundletool: ${versionCodeRaw}`);
  }

  return {
    applicationId,
    versionCode,
    versionName,
  };
}

function resolveStoreFile() {
  if (!STORE_FILE) {
    fail(
      'KRITHA_RELEASE_STORE_FILE was not found in environment ' +
        'or android/gradle.properties',
    );
  }

  const candidate = path.isAbsolute(STORE_FILE)
    ? STORE_FILE
    : path.resolve(ANDROID_DIR, STORE_FILE);

  if (!fs.existsSync(candidate)) {
    fail(`Release keystore does not exist:\n${candidate}`);
  }

  if (!STORE_PASSWORD) {
    fail('KRITHA_RELEASE_STORE_PASSWORD is missing');
  }

  if (!KEY_ALIAS) {
    fail('KRITHA_RELEASE_KEY_ALIAS is missing');
  }

  return candidate;
}

function writeSecretFile(directory, name, value) {
  if (!value) {
    fail(`${name} is missing`);
  }

  const file = path.join(directory, name);

  fs.writeFileSync(file, `${value}\n`, {
    mode: 0o600,
  });

  return file;
}

function buildApks(aabPath, metadata, tempDir, keystore) {
  const apksPath = path.join(
    tempDir,
    `${metadata.applicationId}_${VARIANT}_${metadata.versionCode}.apks`,
  );

  const keystorePassFile = writeSecretFile(
    tempDir,
    'keystore-password.txt',
    STORE_PASSWORD,
  );

  const keyPassFile = writeSecretFile(
    tempDir,
    'key-password.txt',
    KEY_PASSWORD || STORE_PASSWORD,
  );

  bundletool([
    'build-apks',
    `--bundle=${aabPath}`,
    `--output=${apksPath}`,
    `--ks=${keystore}`,
    `--ks-pass=file:${keystorePassFile}`,
    `--ks-key-alias=${KEY_ALIAS}`,
    `--key-pass=file:${keyPassFile}`,
    '--overwrite',
  ]);

  return apksPath;
}

function makeDeviceSpec(abi, file) {
  const spec = {
    supportedAbis: [abi],
    glExtensions: [],
    deviceFeatures: [],
    supportedLocales: LOCALES,
    screenDensity: SCREEN_DENSITY,
    sdkVersion: SDK_VERSION,
  };

  fs.writeFileSync(file, JSON.stringify(spec, null, 2));

  return spec;
}

function extractFeatureApks({ apksPath, deviceSpecPath, features, outputDir }) {
  fs.mkdirSync(outputDir, {
    recursive: true,
  });

  const result = spawnSync(
    'java',
    [
      '-jar',
      BUNDLETOOL_JAR,
      'extract-apks',
      `--apks=${apksPath}`,
      `--device-spec=${deviceSpecPath}`,
      `--output-dir=${outputDir}`,
      `--modules=${features.join(',')}`,
    ],
    {
      cwd: ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
    },
  );

  if (result.error) {
    return {
      ok: false,
      stdout: result.stdout || '',
      stderr: result.stderr || result.error.message,
    };
  }

  if (result.status !== 0) {
    return {
      ok: false,
      stdout: result.stdout || '',
      stderr: result.stderr || '',
    };
  }

  return {
    ok: true,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
  };
}

function selectFeatureApks(extractedDir, features) {
  const apkFiles = fs
    .readdirSync(extractedDir)
    .filter((name) => name.endsWith('.apk'));

  const selected = apkFiles.filter((name) =>
    features.some((feature) => name.startsWith(feature)),
  );

  selected.sort();

  return selected.map((name) => path.join(extractedDir, name));
}

function zipFiles(apkFiles, outputZip) {
  if (!apkFiles.length) {
    fail(`No APKs selected for ${path.basename(outputZip)}`);
  }

  run('zip', ['-q', '-j', outputZip, ...apkFiles], {
    cwd: ROOT,
  });
}

function assetName(features, abi) {
  return `${features.join('+')}-${abi}.zip`;
}

async function main() {
  console.log('\n=== GloballyDynamic build-time artifact generator ===');

  if (!fs.existsSync(ANDROID_DIR)) {
    fail(`Android project not found:\n${ANDROID_DIR}`);
  }

  if (!fs.existsSync(APP_DIR)) {
    fail(`Android app module not found:\n${APP_DIR}`);
  }

  if (!fs.existsSync(GRADLEW)) {
    fail(
      `Gradle wrapper not found at:\n${GRADLEW}\n\n` +
        'Expected:\n' +
        '  android/gradlew\n' +
        '  android/app/build.gradle',
    );
  }

  await ensureBundletool();

  const features = readDynamicFeatures();

  console.log('\nAndroid project:');

  console.log(`  ${path.relative(ROOT, ANDROID_DIR) || '.'}`);

  console.log(`  Gradle wrapper: ${path.relative(ROOT, GRADLEW)}`);

  console.log('\nDynamic features:');

  for (const feature of features) {
    console.log(`  - ${feature}`);
  }

  console.log('\nABIs:');

  for (const abi of ABIS) {
    console.log(`  - ${abi}`);
  }

  console.log('\nLocales:');

  for (const locale of LOCALES) {
    console.log(`  - ${locale}`);
  }

  runGradle([`:app:bundle${VARIANT_CAP}`]);

  const aabPath = findAab();

  console.log(`\nAAB: ${path.relative(ROOT, aabPath)}`);

  const metadata = readBundleMetadata(aabPath);

  console.log('\nBundle metadata:');

  console.log(`  applicationId: ${metadata.applicationId}`);

  console.log(`  versionCode:    ${metadata.versionCode}`);

  console.log(`  versionName:    ${metadata.versionName}`);

  console.log(`  variant:        ${VARIANT}`);

  const keystore = resolveStoreFile();

  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'kritha-gd-'));

  try {
    const apksPath = buildApks(aabPath, metadata, tempRoot, keystore);

    console.log(`\nAPK set: ${apksPath}`);

    fs.mkdirSync(OUTPUT_DIR, {
      recursive: true,
    });

    const featureCombinations = combinations(features);

    const manifest = {
      applicationId: metadata.applicationId,
      versionCode: metadata.versionCode,
      versionName: metadata.versionName,
      variant: VARIANT,
      features,
      abis: [],
      locales: LOCALES,
      screenDensity: SCREEN_DENSITY,
      sdkVersion: SDK_VERSION,
      assets: [],
    };

    for (const abi of ABIS) {
      const deviceSpecPath = path.join(tempRoot, `device-spec-${abi}.json`);

      makeDeviceSpec(abi, deviceSpecPath);

      let generatedForAbi = false;

      console.log(`\n--- ABI: ${abi} ---`);

      for (const combo of featureCombinations) {
        const comboName = combo.join('+');

        const extractedDir = path.join(tempRoot, 'extracted', abi, comboName);

        fs.rmSync(extractedDir, {
          recursive: true,
          force: true,
        });

        fs.mkdirSync(extractedDir, {
          recursive: true,
        });

        console.log(`\nExtracting: ${combo.join(', ')}`);

        const extraction = extractFeatureApks({
          apksPath,
          deviceSpecPath,
          features: combo,
          outputDir: extractedDir,
        });

        if (!extraction.ok) {
          console.warn(
            `Skipping ${comboName} for ${abi}; bundletool could not ` +
              'produce a compatible split.',
          );

          if (extraction.stderr) {
            console.warn(extraction.stderr.trim());
          }

          continue;
        }

        const apkFiles = selectFeatureApks(extractedDir, combo);

        if (!apkFiles.length) {
          console.warn(
            `No matching feature APKs found for ${comboName}/${abi}; skipping.`,
          );

          continue;
        }

        const filename = assetName(combo, abi);

        const outputZip = path.join(OUTPUT_DIR, filename);

        if (fs.existsSync(outputZip)) {
          fs.unlinkSync(outputZip);
        }

        zipFiles(apkFiles, outputZip);

        const sizeBytes = fs.statSync(outputZip).size;

        console.log(`Created ${path.relative(ROOT, outputZip)}`);

        console.log(
          `  APKs: ${apkFiles.map((x) => path.basename(x)).join(', ')}`,
        );

        console.log(`  Size: ${sizeBytes} bytes`);

        manifest.assets.push({
          features: combo,
          abi,
          file: filename,
          sizeBytes,
        });

        generatedForAbi = true;
      }

      if (generatedForAbi) {
        manifest.abis.push(abi);
      }
    }

    const manifestPath = path.join(OUTPUT_DIR, 'manifest.json');

    if (manifest.assets.length === 0) {
      fail(
        'Bundletool produced no feature artifacts. ' +
          'Check GD_ABIS, GD_LOCALES, GD_SCREEN_DENSITY, and GD_SDK_VERSION.',
      );
    }

    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');

    console.log(`\nMetadata: ${path.relative(ROOT, manifestPath)}`);

    console.log(`\nGenerated ${manifest.assets.length} artifact(s).`);

    console.log('\n=== DONE ===');

    console.log(`Artifacts: ${path.relative(ROOT, OUTPUT_DIR)}`);

    console.log('\nGenerated assets:');

    for (const asset of manifest.assets) {
      console.log(`  ${asset.file}`);
    }
  } finally {
    fs.rmSync(tempRoot, {
      recursive: true,
      force: true,
    });
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
