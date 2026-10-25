import { createServer } from 'node:http';
import { createHash, timingSafeEqual } from 'node:crypto';
import { readFileSync, writeFileSync, renameSync } from 'node:fs';

const PORT = Number(process.env.PORT ?? 3110);
const HOST = process.env.HOST ?? '127.0.0.1';
const INTERNAL_PORT = Number(process.env.INTERNAL_PORT ?? 3111);
const INTERNAL_HOST = process.env.INTERNAL_HOST ?? '127.0.0.1';
const ADMIN_TOKEN = process.env.BRIDGE_ADMIN_TOKEN ?? '';
const CONFIG_FILE = process.env.CONFIG_FILE ?? '';
const ORIGIN = process.env.ALLOWED_ORIGIN ?? 'https://fiscal.byescaleira.com';
const PREFIX = '/bridge';
const MINUTE = 60_000;
const STARTED = Date.now();

export const DEFAULTS = Object.freeze({
  enabled: true,
  maxSnapshots: Number(process.env.MAX_SNAPSHOTS ?? 5000),
  readPerMinute: 120,
  writePerMinute: 60,
  maxBody: Number(process.env.MAX_BODY ?? 1024 * 1024),
  ttlHours: process.env.TTL_MS ? Number(process.env.TTL_MS) / 3_600_000 : 24,
});

const RULES = {
  enabled: (value) => typeof value === 'boolean',
  maxSnapshots: (value) => Number.isInteger(value) && value >= 0 && value <= 100_000,
  readPerMinute: (value) => Number.isInteger(value) && value >= 1 && value <= 100_000,
  writePerMinute: (value) => Number.isInteger(value) && value >= 1 && value <= 100_000,
  maxBody: (value) => Number.isInteger(value) && value >= 1024 && value <= 4 * 1024 * 1024,
  ttlHours: (value) => typeof value === 'number' && Number.isFinite(value) && value > 0 && value <= 24,
};

export const config = { ...DEFAULTS };
const snapshots = new Map();
const buckets = new Map();
const minutes = Array.from({ length: 60 }, () => ({ minute: null }));
const COUNTERS = ['reads', 'writes', 'deletes', 'notFound', 'rateLimited', 'unavailable'];
let lastSweep = -Infinity;

export function validateConfig(changes) {
  if (!changes || typeof changes !== 'object' || Array.isArray(changes)) return { error: 'invalid_config' };
  for (const [key, value] of Object.entries(changes)) {
    if (!(key in RULES)) return { error: 'unknown_field', field: key };
    if (!RULES[key](value)) return { error: 'invalid_value', field: key };
  }
  return { value: { ...config, ...changes } };
}

export function configure(changes, { persist = true } = {}) {
  const result = validateConfig(changes);
  if (result.error) return result;
  Object.assign(config, result.value);
  if (persist && CONFIG_FILE) {
    writeFileSync(`${CONFIG_FILE}.tmp`, JSON.stringify(config, null, 2));
    renameSync(`${CONFIG_FILE}.tmp`, CONFIG_FILE);
  }
  return { value: { ...config } };
}

export function resetConfig() {
  Object.assign(config, DEFAULTS);
}

function loadConfig() {
  if (!CONFIG_FILE) return;
  try {
    const saved = JSON.parse(readFileSync(CONFIG_FILE, 'utf8'));
    const known = Object.fromEntries(Object.entries(saved).filter(([key]) => key in RULES));
    const result = configure(known, { persist: false });
    if (result.error) console.log(`ignored saved config: ${result.error} ${result.field ?? ''}`);
  } catch (error) {
    if (error.code !== 'ENOENT') console.log(`ignored saved config: ${error.message}`);
  }
}

const sha256 = (value) => createHash('sha256').update(value).digest();
const isID = (value) => /^[A-Za-z0-9_-]{22}$/.test(value);
const ttlMs = () => config.ttlHours * 3_600_000;
const expiryOf = (entry) => Math.min(entry.expiresAt, entry.createdAt + ttlMs());
const clientIP = (request) =>
  (request.headers['x-forwarded-for'] ?? '').split(',')[0].trim() || request.socket.remoteAddress || 'unknown';

function count(name, now) {
  const minute = Math.floor(now / MINUTE);
  const slot = minutes[minute % 60];
  if (slot.minute !== minute) {
    slot.minute = minute;
    for (const key of COUNTERS) slot[key] = 0;
  }
  slot[name] += 1;
}

export function resetStats() {
  for (const slot of minutes) slot.minute = null;
}

function allow(ip, kind, now) {
  const key = `${kind}:${ip}`;
  const bucket = buckets.get(key);
  if (!bucket || now - bucket.start >= MINUTE) {
    buckets.set(key, { start: now, count: 1 });
    return true;
  }
  bucket.count += 1;
  return bucket.count <= (kind === 'read' ? config.readPerMinute : config.writePerMinute);
}

function sweep(now) {
  if (Math.abs(now - lastSweep) < 1000) return;
  lastSweep = now;
  for (const [id, entry] of snapshots) if (expiryOf(entry) <= now) snapshots.delete(id);
  for (const [key, bucket] of buckets) if (now - bucket.start >= MINUTE) buckets.delete(key);
}

function live(id, now) {
  const entry = snapshots.get(id);
  if (entry && expiryOf(entry) <= now) {
    snapshots.delete(id);
    return undefined;
  }
  return entry;
}

function cors(request, response) {
  if (request.headers.origin === ORIGIN) {
    response.setHeader('Access-Control-Allow-Origin', ORIGIN);
    response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'If-None-Match');
    response.setHeader('Access-Control-Expose-Headers', 'ETag');
    response.setHeader('Vary', 'Origin');
  }
}

function send(response, status, body, headers = {}) {
  response.writeHead(status, { 'Cache-Control': 'no-store', ...headers, ...(body ? { 'Content-Type': 'application/json' } : {}) });
  response.end(body ? JSON.stringify(body) : undefined);
}

function readBody(request, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size <= limit) chunks.push(chunk);
    });
    request.on('end', () => {
      if (size > limit) reject(Object.assign(new Error('too large'), { status: 413 }));
      else resolve(Buffer.concat(chunks).toString('utf8'));
    });
    request.on('error', reject);
  });
}

function validPackage(value) {
  const base64 = (text, min, max) => typeof text === 'string' && /^[A-Za-z0-9+/]+={0,2}$/.test(text) && text.length >= min && text.length <= max;
  return value && value.v === 2 && base64(value.appKey, 88, 88) && base64(value.nonce, 16, 16) && base64(value.ciphertext, 24, config.maxBody);
}

function owner(request) {
  const header = request.headers.authorization ?? '';
  const match = header.match(/^Bearer ([A-Za-z0-9_-]{32,128})$/);
  return match ? sha256(match[1]) : null;
}

export function handle(request, response, now = Date.now()) {
  sweep(now);
  const url = new URL(request.url, 'http://bridge');
  const path = url.pathname.startsWith(PREFIX) ? url.pathname.slice(PREFIX.length) : url.pathname;
  const ip = clientIP(request);
  cors(request, response);
  const reply = (status, body, headers) => {
    if (status === 404) count('notFound', now);
    if (status === 429) count('rateLimited', now);
    if (status === 503) count('unavailable', now);
    return send(response, status, body, headers);
  };

  if (path === '/health') return send(response, 200, config.enabled ? { ok: true } : { ok: true, paused: true });
  if (request.method === 'OPTIONS') return send(response, 204);

  const match = path.match(/^\/v1\/snapshots\/([^/]+)$/);
  if (!match || !isID(match[1])) return reply(404, { error: 'not_found' });
  const id = match[1];

  if (request.method === 'GET') count('reads', now);
  else if (request.method === 'PUT') count('writes', now);
  else if (request.method === 'DELETE') count('deletes', now);
  else return send(response, 405, { error: 'method_not_allowed' });

  if (!config.enabled) {
    request.resume();
    return reply(503, { error: 'paused' }, { 'Retry-After': '60' });
  }

  const entry = live(id, now);

  if (request.method === 'GET') {
    if (!allow(ip, 'read', now)) return reply(429, { error: 'rate_limited' });
    if (!entry) return reply(404, { error: 'not_found' });
    if (request.headers['if-none-match'] === entry.etag) return send(response, 304, null, { ETag: entry.etag });
    return send(response, 200, { ...entry.payload, updatedAt: new Date(entry.updatedAt).toISOString(), expiresAt: new Date(expiryOf(entry)).toISOString() }, { ETag: entry.etag });
  }

  if (!allow(ip, 'write', now)) {
    request.resume();
    return reply(429, { error: 'rate_limited' });
  }
  const ownerHash = owner(request);
  if (!ownerHash) return reply(401, { error: 'unauthorized' });
  if (entry && !timingSafeEqual(entry.ownerHash, ownerHash)) return reply(403, { error: 'forbidden' });

  if (request.method === 'DELETE') {
    snapshots.delete(id);
    return send(response, 204);
  }

  const limit = config.maxBody;
  if (Number(request.headers['content-length'] ?? 0) > limit) {
    request.resume();
    return reply(413, { error: 'too_large' });
  }
  return readBody(request, limit)
    .then((text) => {
      let payload;
      try {
        payload = JSON.parse(text);
      } catch {
        return reply(400, { error: 'invalid_json' });
      }
      if (!validPackage(payload)) return reply(400, { error: 'invalid_package' });
      if (!entry && snapshots.size >= config.maxSnapshots) return reply(503, { error: 'full' });
      const clean = { v: 2, appKey: payload.appKey, nonce: payload.nonce, ciphertext: payload.ciphertext };
      const etag = `"${sha256(JSON.stringify(clean)).toString('hex').slice(0, 32)}"`;
      const createdAt = entry ? entry.createdAt : now;
      const expiresAt = entry ? entry.expiresAt : now + ttlMs();
      const stored = { ownerHash, payload: clean, etag, createdAt, updatedAt: now, expiresAt, size: text.length };
      snapshots.set(id, stored);
      console.log(`${new Date(now).toISOString()} ${entry ? 'update' : 'create'} ${id.slice(0, 6)} ${text.length}B`);
      return send(response, entry ? 200 : 201, { expiresAt: new Date(expiryOf(stored)).toISOString() }, { ETag: etag });
    })
    .catch((error) => reply(error.status ?? 400, { error: error.status === 413 ? 'too_large' : 'invalid_body' }));
}

export function stats(now = Date.now()) {
  sweep(now);
  let bytes = 0;
  for (const entry of snapshots.values()) bytes += entry.size ?? 0;
  const current = Math.floor(now / MINUTE);
  const series = [];
  for (let minute = current - 59; minute <= current; minute += 1) {
    const slot = minutes[((minute % 60) + 60) % 60];
    const values = Object.fromEntries(COUNTERS.map((key) => [key, slot.minute === minute ? slot[key] : 0]));
    series.push({ minute: new Date(minute * MINUTE).toISOString(), ...values });
  }
  const totals = Object.fromEntries(COUNTERS.map((key) => [key, series.reduce((sum, item) => sum + item[key], 0)]));
  const memory = process.memoryUsage();
  return {
    now: new Date(now).toISOString(),
    uptimeSeconds: Math.round((now - STARTED) / 1000),
    config: { ...config },
    snapshots: { count: snapshots.size, bytes },
    memory: { rss: memory.rss, heapUsed: memory.heapUsed, heapTotal: memory.heapTotal },
    totals,
    minutes: series,
  };
}

function authorized(request, token) {
  const header = request.headers.authorization ?? '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match || !token) return false;
  return timingSafeEqual(sha256(match[1]), sha256(token));
}

export function handleInternal(request, response, { token = ADMIN_TOKEN, now = Date.now() } = {}) {
  const { pathname } = new URL(request.url, 'http://internal');
  if (!authorized(request, token)) {
    request.resume();
    return send(response, 401, { error: 'unauthorized' });
  }
  if (pathname === '/internal/stats' && request.method === 'GET') return send(response, 200, stats(now));
  if (pathname === '/internal/config' && request.method === 'GET') return send(response, 200, { ...config });
  if (pathname === '/internal/config' && request.method === 'PUT') {
    return readBody(request, 16 * 1024)
      .then((text) => {
        let changes;
        try {
          changes = JSON.parse(text);
        } catch {
          return send(response, 400, { error: 'invalid_json' });
        }
        const before = { ...config };
        const result = configure(changes);
        if (result.error) return send(response, 400, result);
        const changed = Object.keys(changes).filter((key) => before[key] !== result.value[key]);
        if (changed.length) console.log(`${new Date(now).toISOString()} config ${changed.map((key) => `${key}=${result.value[key]}`).join(' ')}`);
        return send(response, 200, result.value);
      })
      .catch(() => send(response, 413, { error: 'too_large' }));
  }
  request.resume();
  return send(response, 404, { error: 'not_found' });
}

export const store = snapshots;
export const rateBuckets = buckets;

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  loadConfig();
  const server = createServer((request, response) => handle(request, response)).listen(PORT, HOST, () => {
    console.log(`fiscal bridge on ${HOST}:${server.address().port}${config.enabled ? '' : ' (paused)'}`);
  });
  if (ADMIN_TOKEN.length >= 32) {
    const control = createServer((request, response) => handleInternal(request, response)).listen(INTERNAL_PORT, INTERNAL_HOST, () => {
      console.log(`fiscal bridge control on ${INTERNAL_HOST}:${control.address().port}`);
    });
  } else {
    console.log('control server off: BRIDGE_ADMIN_TOKEN missing or shorter than 32 characters');
  }
}
