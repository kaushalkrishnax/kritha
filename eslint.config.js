import js from '@eslint/js';
import expo from 'eslint-config-expo/flat.js';
import globals from 'globals';

export default [
  js.configs.recommended,
  ...expo,
  {
    rules: {
      'import/order': [
        'error',
        {
          groups: [
            'builtin',
            'external',
            'internal',
            ['parent', 'sibling'],
            'index',
            'object',
            'type',
          ],
          'newlines-between': 'always',
          alphabetize: {
            order: 'asc',
            caseInsensitive: true,
          },
        },
      ],
    },
    settings: {
      'import/resolver': {
        typescript: {
          alwaysTryTypes: true,
        },
        node: true,
      },
    },
  },
  // Node.js CommonJS files (Metro config, Expo config plugins).
  {
    files: ['metro.config.js', 'modules/**/*.js'],
    languageOptions: {
      sourceType: 'commonjs',
      globals: {
        ...globals.node,
      },
    },
  },
  // Node.js ESM scripts.
  {
    files: ['scripts/**/*.js'],
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
  },
  // Cloudflare Workers runtime (fetch, Request, Response, URL, Headers).
  {
    files: ['workers/**/*.js'],
    languageOptions: {
      globals: {
        ...globals.worker,
        ...globals.serviceworker,
        Headers: 'readonly',
        Request: 'readonly',
        Response: 'readonly',
        URL: 'readonly',
        console: 'readonly',
        fetch: 'readonly',
      },
    },
  },
];
