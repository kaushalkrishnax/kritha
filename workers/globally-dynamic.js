let manifestPromise = null;

function json(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2) + '\n', {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
  });
}

function normalizeFeature(value) {
  return value.trim().replaceAll('-', '_');
}

function getCsvParams(url, name) {
  return url.searchParams
    .getAll(name)
    .flatMap((value) => value.split(','))
    .map((value) => value.trim())
    .filter(Boolean);
}

function canonicalFeatures(features, manifest) {
  const order = new Map(
    manifest.features.map((feature, index) => [
      normalizeFeature(feature),
      index,
    ]),
  );

  return [...new Set(features.map(normalizeFeature))].sort(
    (a, b) =>
      (order.get(a) ?? Number.MAX_SAFE_INTEGER) -
      (order.get(b) ?? Number.MAX_SAFE_INTEGER),
  );
}

function sameArray(a, b) {
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

async function loadManifest(env, request) {
  if (!manifestPromise) {
    manifestPromise = (async () => {
      const url = new URL('/manifest.json', request.url);

      const response = await env.ASSETS.fetch(
        new Request(url, {
          method: 'GET',
        }),
      );

      if (!response.ok) {
        throw new Error(`manifest.json unavailable: HTTP ${response.status}`);
      }

      const manifest = await response.json();

      if (
        !manifest ||
        typeof manifest !== 'object' ||
        !manifest.applicationId ||
        !Number.isInteger(manifest.versionCode) ||
        !manifest.variant ||
        !Array.isArray(manifest.features) ||
        !Array.isArray(manifest.abis) ||
        !Array.isArray(manifest.assets)
      ) {
        throw new Error('Invalid GloballyDynamic manifest');
      }

      return manifest;
    })();
  }

  try {
    return await manifestPromise;
  } catch (error) {
    manifestPromise = null;
    throw error;
  }
}

async function serveDownload(request, env) {
  const url = new URL(request.url);
  const manifest = await loadManifest(env, request);

  const applicationId = url.searchParams.get('application-id')?.trim() || '';

  const version = url.searchParams.get('version')?.trim() || '';

  const variant = url.searchParams.get('variant')?.trim() || '';

  const signature = url.searchParams.get('signature')?.trim() || '';

  const requestedFeatures = getCsvParams(url, 'features');

  const requestedLanguages = getCsvParams(url, 'languages');

  if (!applicationId) {
    return json(
      {
        error: 'missing_application_id',
        message: 'application-id is required',
      },
      400,
    );
  }

  if (!version) {
    return json(
      {
        error: 'missing_version',
        message: 'version is required',
      },
      400,
    );
  }

  if (!variant) {
    return json(
      {
        error: 'missing_variant',
        message: 'variant is required',
      },
      400,
    );
  }

  if (!signature) {
    return json(
      {
        error: 'missing_signature',
        message: 'signature is required',
      },
      400,
    );
  }

  if (!requestedFeatures.length) {
    return json(
      {
        error: 'missing_features',
        message: 'At least one feature is required',
      },
      400,
    );
  }

  if (applicationId !== manifest.applicationId) {
    return json(
      {
        error: 'application_id_mismatch',
        message: 'Unsupported application-id',
      },
      404,
    );
  }

  if (String(manifest.versionCode) !== version) {
    return json(
      {
        error: 'version_mismatch',
        message: `Requested version ${version} is not available`,
        availableVersion: manifest.versionCode,
      },
      404,
    );
  }

  if (variant !== manifest.variant) {
    return json(
      {
        error: 'variant_mismatch',
        message: 'Requested variant is not available',
      },
      404,
    );
  }

  if (
    manifest.signature &&
    signature.toUpperCase() !== String(manifest.signature).toUpperCase()
  ) {
    return json(
      {
        error: 'signature_mismatch',
        message: 'Signing certificate does not match',
      },
      403,
    );
  }

  const normalizedRequested = canonicalFeatures(requestedFeatures, manifest);

  const knownFeatures = new Set(manifest.features.map(normalizeFeature));

  const unknownFeatures = normalizedRequested.filter(
    (feature) => !knownFeatures.has(feature),
  );

  if (unknownFeatures.length) {
    return json(
      {
        error: 'unknown_feature',
        message: 'One or more requested features are unknown',
        features: unknownFeatures,
      },
      400,
    );
  }

  let deviceSpec;

  try {
    deviceSpec = await request.json();
  } catch {
    return json(
      {
        error: 'invalid_device_spec',
        message: 'Request body must be valid JSON',
      },
      400,
    );
  }

  if (!deviceSpec || typeof deviceSpec !== 'object') {
    return json(
      {
        error: 'invalid_device_spec',
        message: 'Request body must be a valid device spec',
      },
      400,
    );
  }

  if (
    !Array.isArray(deviceSpec.supportedAbis) ||
    deviceSpec.supportedAbis.length === 0
  ) {
    return json(
      {
        error: 'missing_abis',
        message: 'Device spec must contain supportedAbis',
      },
      400,
    );
  }

  const abi = deviceSpec.supportedAbis.find((candidate) =>
    manifest.abis.includes(candidate),
  );

  if (!abi) {
    return json(
      {
        error: 'unsupported_abi',
        message: 'No compatible prebuilt artifact exists for this device',
        requestedAbis: deviceSpec.supportedAbis,
        supportedAbis: manifest.abis,
      },
      404,
    );
  }

  const asset = manifest.assets.find((candidate) => {
    const candidateFeatures = canonicalFeatures(candidate.features, manifest);

    return (
      candidate.abi === abi && sameArray(candidateFeatures, normalizedRequested)
    );
  });

  if (!asset) {
    return json(
      {
        error: 'artifact_not_found',
        message: 'No compatible prebuilt feature artifact exists',
        features: normalizedRequested,
        abi,
        languages: requestedLanguages,
      },
      404,
    );
  }

  const assetUrl = new URL(`/${encodeURIComponent(asset.file)}`, request.url);

  const assetResponse = await env.ASSETS.fetch(
    new Request(assetUrl, {
      method: 'GET',
    }),
  );

  if (!assetResponse.ok) {
    return json(
      {
        error: 'asset_unavailable',
        message: `Configured asset could not be loaded: HTTP ${assetResponse.status}`,
        asset: asset.file,
      },
      500,
    );
  }

  const headers = new Headers(assetResponse.headers);

  headers.set('content-type', 'application/zip');

  headers.set('content-disposition', 'attachment; filename="splits.zip"');

  headers.set('cache-control', 'no-store');

  headers.set('x-content-type-options', 'nosniff');

  headers.set('x-globally-dynamic-asset', asset.file);

  return new Response(assetResponse.body, {
    status: 200,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      try {
        const manifest = await loadManifest(env, request);

        return json({
          status: 'ok',
          service: 'globally-dynamic',
          applicationId: manifest.applicationId,
          versionCode: manifest.versionCode,
          versionName: manifest.versionName ?? null,
          variant: manifest.variant,
          features: manifest.features,
          abis: manifest.abis,
        });
      } catch (error) {
        return json(
          {
            status: 'error',
            service: 'globally-dynamic',
            message:
              error instanceof Error
                ? error.message
                : 'Failed to load manifest',
          },
          500,
        );
      }
    }

    if (url.pathname === '/') {
      return json({
        service: 'globally-dynamic',
        endpoint: '/download',
        method: 'POST',
        status: 'ok',
      });
    }

    if (url.pathname === '/download') {
      if (request.method === 'OPTIONS') {
        return new Response(null, {
          status: 204,
          headers: {
            allow: 'POST, OPTIONS',
          },
        });
      }

      if (request.method !== 'POST') {
        return json(
          {
            error: 'method_not_allowed',
            message: 'The /download endpoint requires POST',
          },
          405,
        );
      }

      try {
        return await serveDownload(request, env);
      } catch (error) {
        console.error('GloballyDynamic download error', error);

        return json(
          {
            error: 'internal_error',
            message:
              error instanceof Error ? error.message : 'Internal server error',
          },
          500,
        );
      }
    }

    return new Response('Not Found', {
      status: 404,
      headers: {
        'content-type': 'text/plain; charset=utf-8',
      },
    });
  },
};
