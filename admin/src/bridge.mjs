export class BridgeError extends Error {
  constructor(code, detail = '') {
    super(detail ? `${code}: ${detail}` : code);
    this.code = code;
    this.detail = detail;
  }
}

const FIELDS = {
  enabled: 'boolean',
  maxSnapshots: [0, 100_000],
  readPerMinute: [1, 100_000],
  writePerMinute: [1, 100_000],
  maxBody: [1024, 4 * 1024 * 1024],
  ttlHours: [1, 24],
};

export function parseBridgeForm(form) {
  const changes = {};
  for (const [key, rule] of Object.entries(FIELDS)) {
    if (rule === 'boolean') {
      if (form.has('enabledField')) changes.enabled = form.get('enabled') === 'on';
      continue;
    }
    if (!form.has(key)) continue;
    const raw = form.get(key).trim();
    const value = key === 'maxBody' ? Number(raw) * 1024 : Number(raw);
    if (raw === '' || !Number.isInteger(value) || value < rule[0] || value > rule[1]) return { error: 'invalid_value', field: key };
    changes[key] = value;
  }
  return { value: changes };
}

export function createBridge({ url, token, fetch = globalThis.fetch }) {
  async function call(method, path, body) {
    if (!url || !token) throw new BridgeError('not_configured');
    let response;
    try {
      response = await fetch(`${url}${path}`, {
        method,
        headers: { Authorization: `Bearer ${token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(5000),
      });
    } catch (error) {
      throw new BridgeError('unreachable', error.message);
    }
    const json = await response.json().catch(() => ({}));
    if (!response.ok) throw new BridgeError(json.error ?? `http_${response.status}`, json.field ?? '');
    return json;
  }

  return {
    stats: () => call('GET', '/internal/stats'),
    config: () => call('GET', '/internal/config'),
    update: (changes) => call('PUT', '/internal/config', changes),
  };
}
