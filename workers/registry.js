function json(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2) + '\n', {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store, max-age=0',
      'x-content-type-options': 'nosniff',
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
      'access-control-allow-headers': 'Content-Type',
    },
  });
}

function isNewerVersion(latest, current) {
  const l = latest.split('.').map(Number);
  const c = current.split('.').map(Number);

  for (let i = 0; i < l.length; i++) {
    if ((l[i] || 0) > (c[i] || 0)) return true;
    if ((l[i] || 0) < (c[i] || 0)) return false;
  }
  return false;
}

async function fetchGitHubRelease(env) {
  const repo = env.GITHUB_REPO || 'kaushalkrishnax/kritha';
  const token = env.GITHUB_TOKEN;

  const headers = {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'Kritha Registry',
  };

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(
    `https://api.github.com/repos/${repo}/releases/latest`,
    { headers },
  );

  if (!res.ok) {
    const text = await res.text();
    console.error('GitHub API failed:', res.status, text);
    throw new Error(`GitHub API failed: ${res.status}`);
  }

  return res.json();
}

function parseChangelog(body) {
  const sections = {};
  let currentSection = '';

  for (const line of (body || '').split('\n')) {
    const heading = line.match(/^\*\*(.+)\*\*$/);
    if (heading) {
      currentSection = heading[1].trim();
      sections[currentSection] = [];
    } else if (currentSection && line.startsWith('*')) {
      sections[currentSection].push(line.replace(/^\*\s*/, '').trim());
    }
  }

  return sections;
}

function formatBytes(bytes) {
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(1)} MB`;
}

async function handleCheck(request, env) {
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        allow: 'POST, OPTIONS',
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'POST, OPTIONS',
        'access-control-allow-headers': 'Content-Type',
      },
    });
  }

  if (request.method !== 'POST') {
    return json({ error: 'method_not_allowed', message: 'Use POST' }, 405);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'invalid_json', message: 'Invalid JSON body' }, 400);
  }

  const { version, arch, platform } = body;

  if (!version) {
    return json(
      { error: 'version_required', message: 'Version is required' },
      400,
    );
  }

  try {
    const data = await fetchGitHubRelease(env);

    if (!data.tag_name || !data.assets) {
      return json(
        {
          error: 'invalid_release',
          message: 'Invalid release data from GitHub',
        },
        500,
      );
    }

    const latestVersion = data.tag_name.replace(/^v/, '');
    const hasUpdate = isNewerVersion(latestVersion, version);

    // High severity for exact vX.X.X stable releases
    const isStable = /^\d+\.\d+\.\d+$/.test(latestVersion);
    const severity = isStable ? 'high' : 'low';

    const apkAsset = data.assets.find((a) => a.name.endsWith('.apk'));

    const releaseInfo = {
      version: latestVersion,
      latestVersion,
      name: data.name,
      publishedAt: data.published_at,
      releaseUrl: data.html_url,
      changelog: parseChangelog(data.body),
      severity,
      apkUrl: apkAsset?.browser_download_url ?? null,
      apk: apkAsset
        ? {
            url: apkAsset.browser_download_url,
            name: apkAsset.name,
            size: apkAsset.size,
            sizeFormatted: formatBytes(apkAsset.size),
            digest: apkAsset.digest,
            downloadCount: apkAsset.download_count,
            createdAt: apkAsset.created_at,
          }
        : null,
    };

    return json({
      updateAvailable: hasUpdate,
      ...releaseInfo,
    });
  } catch (e) {
    console.error('Update check failed:', e);
    return json({ error: 'check_failed', message: 'Update check failed' }, 500);
  }
}

async function handleExtensions(request, env) {
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        allow: 'GET, OPTIONS',
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, OPTIONS',
        'access-control-allow-headers': 'Content-Type',
      },
    });
  }

  if (request.method !== 'GET') {
    return json({ error: 'method_not_allowed', message: 'Use GET' }, 405);
  }

  const extensions = [];

  return json({ extensions });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json({ status: 'ok', service: 'kritha-registry' });
    }

    if (url.pathname === '/check') {
      return handleCheck(request, env);
    }

    if (url.pathname === '/extensions') {
      return handleExtensions(request, env);
    }

    if (url.pathname === '/manifest') {
      return json({
        service: 'kritha-registry',
        version: '1.0.0',
        endpoints: {
          check: '/check (POST)',
          extensions: '/extensions (GET)',
        },
      });
    }

    return json({
      service: 'kritha-registry',
      version: '1.0.0',
      endpoints: {
        check: '/check (POST) - Check for app updates',
        extensions: '/extensions (GET) - List available extensions',
        manifest: '/manifest (GET) - This manifest',
      },
    });
  },
};