/**
* Usage:
* bun eas_build.js --platform android --profile production

* The script temporarily injects values from:
*   ~/.gradle/gradle.properties
*
* into:
*   android/app/build.gradle
*
* After EAS CLI exits, the original build.gradle is restored.
* 
*/

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';

const PROJECT_ROOT = process.cwd();

const GRADLE_PROPERTIES = path.join(
  os.homedir(),
  '.gradle',
  'gradle.properties',
);

const BUILD_GRADLE = path.join(PROJECT_ROOT, 'android', 'app', 'build.gradle');

let originalContent = null;
let modified = false;
let restoring = false;

// Gradle properties parser

function parseGradleProperties(content) {
  const result = {};

  // Handle Java/Gradle property line continuations.
  const physicalLines = content.replace(/\r\n/g, '\n').split('\n');
  const logicalLines = [];

  let current = '';

  for (const line of physicalLines) {
    if (current.length > 0) {
      current += line;
    } else {
      current = line;
    }

    // Count trailing unescaped backslashes.
    let slashCount = 0;

    for (let i = current.length - 1; i >= 0 && current[i] === '\\'; i--) {
      slashCount++;
    }

    const continued = slashCount % 2 === 1;

    if (!continued) {
      logicalLines.push(current);
      current = '';
    } else {
      // Remove one continuation slash.
      current = current.slice(0, -1);
    }
  }

  if (current.length > 0) {
    logicalLines.push(current);
  }

  for (let line of logicalLines) {
    line = line.trim();

    if (!line || line.startsWith('#') || line.startsWith('!')) {
      continue;
    }

    // Find the first unescaped '=', ':' or whitespace.
    let separatorIndex = -1;

    for (let i = 0; i < line.length; i++) {
      const char = line[i];

      if (char === '\\' && i + 1 < line.length) {
        i++;
        continue;
      }

      if (char === '=' || char === ':' || char === ' ' || char === '\t') {
        separatorIndex = i;
        break;
      }
    }

    let key;
    let value;

    if (separatorIndex === -1) {
      key = line;
      value = '';
    } else {
      key = line.slice(0, separatorIndex);

      let valueStart = separatorIndex;

      while (
        valueStart < line.length &&
        (line[valueStart] === '=' ||
          line[valueStart] === ':' ||
          line[valueStart] === ' ' ||
          line[valueStart] === '\t')
      ) {
        valueStart++;
      }

      value = line.slice(valueStart);
    }

    key = unescapeJavaProperty(key.trim());
    value = unescapeJavaProperty(value);

    result[key] = value;
  }

  return result;
}

function unescapeJavaProperty(value) {
  return value
    .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) =>
      String.fromCharCode(parseInt(hex, 16)),
    )
    .replace(/\\t/g, '\t')
    .replace(/\\r/g, '\r')
    .replace(/\\n/g, '\n')
    .replace(/\\f/g, '\f')
    .replace(/\\(.)/g, '$1');
}

// Groovy string handling
function groovySingleQuoted(value) {
  return `'${String(value)
    .replaceAll('\\\\', '\\\\\\\\')
    .replaceAll("'", "\\\\'")
    .replace(/\r/g, '\\r')
    .replace(/\n/g, '\\n')}'`;
}

function escapeForQuotedString(value, quote) {
  let output = String(value);

  output = output.replaceAll('\\', '\\\\');

  if (quote === '"') {
    output = output.replaceAll('"', '\\"');
  } else {
    output = output.replaceAll("'", "\\'");
  }

  output = output.replace(/\r/g, '\\r').replace(/\n/g, '\\n');

  return output;
}

// Source transformation
function replaceGradleVariables(source, properties) {
  let output = '';
  let i = 0;

  while (i < source.length) {
    const char = source[i];
    const next = source[i + 1];

    // Line comment.
    if (char === '/' && next === '/') {
      const end = source.indexOf('\n', i);

      if (end === -1) {
        output += source.slice(i);
        break;
      }

      output += source.slice(i, end + 1);
      i = end + 1;
      continue;
    }

    // Block comment.
    if (char === '/' && next === '*') {
      const end = source.indexOf('*/', i + 2);

      if (end === -1) {
        output += source.slice(i);
        break;
      }

      output += source.slice(i, end + 2);
      i = end + 2;
      continue;
    }

    if (char === "'" || char === '"') {
      const quote = char;

      // Triple quoted Groovy string.
      if (source[i + 1] === quote && source[i + 2] === quote) {
        const delimiter = quote.repeat(3);
        const end = source.indexOf(delimiter, i + 3);

        if (end === -1) {
          output += source.slice(i);
          break;
        }

        const body = source.slice(i + 3, end);

        output += delimiter;

        for (const key of Object.keys(properties)) {
          const value = escapeForQuotedString(properties[key], quote);

          const dollarBrace = new RegExp(`\\$\\{${escapeRegExp(key)}\\}`, 'g');

          const dollarBare = new RegExp(`\\$${escapeRegExp(key)}\\b`, 'g');

          output += body.replace(dollarBrace, value).replace(dollarBare, value);
        }

        output += delimiter;

        i = end + 3;
        continue;
      }

      let end = i + 1;

      while (end < source.length) {
        if (source[end] === '\\') {
          end += 2;
          continue;
        }

        if (source[end] === quote) {
          break;
        }

        end++;
      }

      const body = source.slice(i + 1, end);

      let replacedBody = body;

      for (const key of Object.keys(properties)) {
        const value = escapeForQuotedString(properties[key], quote);

        const dollarBrace = new RegExp(`\\$\\{${escapeRegExp(key)}\\}`, 'g');

        const dollarBare = new RegExp(`\\$${escapeRegExp(key)}\\b`, 'g');

        replacedBody = replacedBody
          .replace(dollarBrace, value)
          .replace(dollarBare, value);
      }

      output += quote + replacedBody;

      if (end < source.length) {
        output += quote;
        i = end + 1;
      } else {
        i = end;
      }

      continue;
    }

    let matched = false;

    for (const [key, value] of Object.entries(properties)) {
      const escapedKey = escapeRegExp(key);

      const patterns = [
        new RegExp(
          `project\\.findProperty\\(\\s*["']${escapedKey}["']\\s*\\)`,
          'g',
        ),
        new RegExp(`findProperty\\(\\s*["']${escapedKey}["']\\s*\\)`, 'g'),
        new RegExp(
          `providers\\.gradleProperty\\(\\s*["']${escapedKey}["']\\s*\\)`,
          'g',
        ),
        new RegExp(
          `providers\\.gradleProperty\\(\\s*["']${escapedKey}["']\\s*\\)\\.get\\(\\)`,
          'g',
        ),
      ];

      for (const pattern of patterns) {
        const updated = source
          .slice(i)
          .replace(pattern, groovySingleQuoted(value));

        if (updated !== source.slice(i)) {
          output += updated.slice(0, updated.length - (source.length - i));
          matched = true;
          break;
        }
      }

      if (matched) {
        break;
      }
    }

    if (matched) {
      break;
    }

    output += char;
    i++;
  }

  return transformSimpleExpressions(output, properties);
}

function transformSimpleExpressions(source, properties) {
  let result = source;

  for (const [key, value] of Object.entries(properties)) {
    const escapedKey = escapeRegExp(key);
    const replacement = groovySingleQuoted(value);

    result = result.replace(
      new RegExp(
        `project\\.findProperty\\(\\s*["']${escapedKey}["']\\s*\\)`,
        'g',
      ),
      replacement,
    );

    result = result.replace(
      new RegExp(`findProperty\\(\\s*["']${escapedKey}["']\\s*\\)`, 'g'),
      replacement,
    );

    result = result.replace(
      new RegExp(
        `providers\\.gradleProperty\\(\\s*["']${escapedKey}["']\\s*\\)\\.get\\(\\)`,
        'g',
      ),
      replacement,
    );

    result = result.replace(
      new RegExp(
        `providers\\.gradleProperty\\(\\s*["']${escapedKey}["']\\s*\\)`,
        'g',
      ),
      replacement,
    );

    const bareIdentifier = new RegExp(
      `(?<![.$\\w])${escapedKey}(?![\\w$])`,
      'g',
    );

    result = result.replace(bareIdentifier, (match, offset, fullString) => {
      const before = fullString.slice(0, offset);
      const after = fullString.slice(offset + key.length);

      const lineStart = before.lastIndexOf('\n') + 1;
      const lineBefore = before.slice(lineStart);

      const afterTrimmed = after.trimStart();

      // Don't replace declaration/assignment LHS.
      if (
        /\b(def|val|var)\s*$/.test(lineBefore) ||
        afterTrimmed.startsWith('=')
      ) {
        return match;
      }

      return replacement;
    });
  }

  return result;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Safety / file handling
async function restoreBuildGradle() {
  if (!modified || originalContent === null || restoring) {
    return;
  }

  restoring = true;

  try {
    await fs.promises.writeFile(BUILD_GRADLE, originalContent, 'utf8');

    modified = false;
    console.log('\n✓ Restored android/app/build.gradle');
  } catch (error) {
    console.error(
      '\n!!! FAILED TO RESTORE android/app/build.gradle !!!',
      error,
    );

    process.exitCode = 1;
  } finally {
    restoring = false;
  }
}

async function cleanupAndExit(code) {
  await restoreBuildGradle();
  process.exit(code);
}

// Main
async function main() {
  console.log('Kritha EAS build wrapper');
  console.log('----------------------------------------');

  if (!fs.existsSync(GRADLE_PROPERTIES)) {
    throw new Error(`Missing Gradle properties file:\n${GRADLE_PROPERTIES}`);
  }

  if (!fs.existsSync(BUILD_GRADLE)) {
    throw new Error(`Missing build.gradle:\n${BUILD_GRADLE}`);
  }

  const propertiesContent = await fs.promises.readFile(
    GRADLE_PROPERTIES,
    'utf8',
  );

  const properties = parseGradleProperties(propertiesContent);

  originalContent = await fs.promises.readFile(BUILD_GRADLE, 'utf8');

  const modifiedContent = replaceGradleVariables(originalContent, properties);

  if (modifiedContent === originalContent) {
    console.log(
      'No matching Gradle properties were found in app/build.gradle.',
    );
  } else {
    await fs.promises.writeFile(BUILD_GRADLE, modifiedContent, 'utf8');

    modified = true;

    console.log('✓ Temporarily injected ~/.gradle/gradle.properties values');
  }

  const easArgs = process.argv.slice(2);

  console.log(`\nRunning: eas build ${easArgs.join(' ')}`.trim());

  const child = spawn('eas', ['build', ...easArgs], {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    shell: false,
    env: {
      ...process.env,
    },
  });

  const exitCode = await new Promise((resolve) => {
    child.on('error', (error) => {
      console.error('\nFailed to start EAS CLI:', error);
      resolve(1);
    });

    child.on('exit', (code, signal) => {
      if (signal) {
        console.error(`\nEAS exited due to signal: ${signal}`);
        resolve(1);
        return;
      }

      resolve(code ?? 1);
    });
  });

  // EAS has finished its local packaging/upload command.
  // Restore before returning control to the shell.
  await restoreBuildGradle();

  process.exitCode = exitCode;
}

// Signal protection
process.on('SIGINT', async () => {
  console.log('\n\nReceived SIGINT. Restoring files...');
  await cleanupAndExit(130);
});

process.on('SIGTERM', async () => {
  console.log('\n\nReceived SIGTERM. Restoring files...');
  await cleanupAndExit(143);
});

main().catch(async (error) => {
  console.error('\nBuild wrapper failed:');
  console.error(error);

  await restoreBuildGradle();

  process.exit(1);
});
