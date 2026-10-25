import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { handle, handleInternal, store, rateBuckets, config, configure, resetConfig, resetStats, stats } from './server.mjs';

const ID = 'ABEiM0RVZneImaq7zN3u_w';
const OWNER = 'o'.repeat(43);
const PACKAGE = JSON.parse(readFileSync(new URL('../docs/web-test-vector-v2.json', import.meta.url), 'utf8')).package;
const FITS = Math.ceil((JSON.stringify(PACKAGE).length + 1) / 1024) * 1024;

let clock = 1_000_000;

const TOKEN = 't'.repeat(40);

async function request(method, path, { body, headers = {}, internal = false } = {}) {
  const server = createServer((req, res) => (internal ? handleInternal(req, res, { token: TOKEN, now: clock }) : handle(req, res, clock)));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await response.text();
  server.closeAllConnections();
  server.close();
  return { status: response.status, headers: response.headers, json: text ? JSON.parse(text) : null };
}

const auth = (token = OWNER) => ({ Authorization: `Bearer ${token}` });

beforeEach(() => {
  store.clear();
  rateBuckets.clear();
  resetConfig();
  resetStats();
  clock = 1_000_000;
});

test('health', async () => {
  const response = await request('GET', '/bridge/health');
  assert.equal(response.status, 200);
  assert.deepEqual(response.json, { ok: true });
});

test('create, read with etag and not modified', async () => {
  const created = await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() });
  assert.equal(created.status, 201);
  const read = await request('GET', `/bridge/v1/snapshots/${ID}`);
  assert.equal(read.status, 200);
  assert.equal(read.json.ciphertext, PACKAGE.ciphertext);
  const etag = read.headers.get('etag');
  const again = await request('GET', `/bridge/v1/snapshots/${ID}`, { headers: { 'If-None-Match': etag } });
  assert.equal(again.status, 304);
});

test('update needs the same owner and keeps expiry', async () => {
  await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() });
  const expiresAt = store.get(ID).expiresAt;
  clock += 60_000;
  const stranger = await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth('x'.repeat(43)) });
  assert.equal(stranger.status, 403);
  const updated = await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: { ...PACKAGE, nonce: 'AAAAAAAAAAAAAAAA' }, headers: auth() });
  assert.equal(updated.status, 200);
  assert.equal(store.get(ID).expiresAt, expiresAt);
});

test('write without owner is rejected', async () => {
  const response = await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE });
  assert.equal(response.status, 401);
});

test('invalid package and id', async () => {
  assert.equal((await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: { v: 2 }, headers: auth() })).status, 400);
  assert.equal((await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: { ...PACKAGE, v: 1 }, headers: auth() })).status, 400);
  assert.equal((await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: { ...PACKAGE, appKey: 'AAAA' }, headers: auth() })).status, 400);
  assert.equal((await request('GET', '/bridge/v1/snapshots/not-an-id')).status, 404);
});

test('expires after 24 hours', async () => {
  await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() });
  clock += 24 * 60 * 60 * 1000 + 1;
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 404);
});

test('delete by owner', async () => {
  await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() });
  assert.equal((await request('DELETE', `/bridge/v1/snapshots/${ID}`, { headers: auth('x'.repeat(43)) })).status, 403);
  assert.equal((await request('DELETE', `/bridge/v1/snapshots/${ID}`, { headers: auth() })).status, 204);
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 404);
});

test('waiting for the scan stays under the read limit and floods are limited', async () => {
  const waiting = 'b'.repeat(22);
  for (let index = 0; index < 30; index += 1) assert.equal((await request('GET', `/bridge/v1/snapshots/${waiting}`)).status, 404);
  let last;
  for (let index = 0; index < 91; index += 1) last = await request('GET', `/bridge/v1/snapshots/${waiting}`);
  assert.equal(last.status, 429);
});

test('cors only for the site origin', async () => {
  await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() });
  const site = await request('GET', `/bridge/v1/snapshots/${ID}`, { headers: { Origin: 'https://fiscal.byescaleira.com' } });
  assert.equal(site.headers.get('access-control-allow-origin'), 'https://fiscal.byescaleira.com');
  const other = await request('GET', `/bridge/v1/snapshots/${ID}`, { headers: { Origin: 'https://evil.example' } });
  assert.equal(other.headers.get('access-control-allow-origin'), null);
});

test('body over the limit is rejected', async () => {
  const big = { ...PACKAGE, ciphertext: 'A'.repeat(1024 * 1024 + 10) };
  const response = await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: big, headers: auth() });
  assert.ok(response.status === 413 || response.status === 400);
});

const admin = (token = TOKEN) => ({ Authorization: `Bearer ${token}` });

test('pause answers 503 on reads and writes while health stays up', async () => {
  await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() });
  configure({ enabled: false }, { persist: false });
  for (const method of ['GET', 'PUT', 'DELETE']) {
    const response = await request(method, `/bridge/v1/snapshots/${ID}`, { body: method === 'PUT' ? PACKAGE : undefined, headers: auth() });
    assert.equal(response.status, 503);
    assert.deepEqual(response.json, { error: 'paused' });
  }
  const health = await request('GET', '/bridge/health');
  assert.equal(health.status, 200);
  assert.deepEqual(health.json, { ok: true, paused: true });
  configure({ enabled: true }, { persist: false });
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 200);
});

test('config changes apply live', async () => {
  configure({ readPerMinute: 2, writePerMinute: 1, maxSnapshots: 1, maxBody: FITS, ttlHours: 1 }, { persist: false });
  assert.equal((await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() })).status, 201);
  assert.equal((await request('PUT', `/bridge/v1/snapshots/${'c'.repeat(22)}`, { body: PACKAGE, headers: auth() })).status, 429);
  rateBuckets.clear();
  assert.equal((await request('PUT', `/bridge/v1/snapshots/${'c'.repeat(22)}`, { body: PACKAGE, headers: auth() })).status, 503);
  rateBuckets.clear();
  const big = { ...PACKAGE, ciphertext: 'A'.repeat(FITS * 2) };
  assert.equal((await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: big, headers: auth() })).status, 413);
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 200);
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 200);
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 429);
  rateBuckets.clear();
  clock += 60 * 60 * 1000 + 1;
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 404);
});

test('invalid config is rejected', () => {
  assert.equal(configure({ ttlHours: 25 }, { persist: false }).error, 'invalid_value');
  assert.equal(configure({ readPerMinute: 1.5 }, { persist: false }).error, 'invalid_value');
  assert.equal(configure({ maxBody: 10 }, { persist: false }).error, 'invalid_value');
  assert.equal(configure({ enabled: 'no' }, { persist: false }).error, 'invalid_value');
  assert.equal(configure({ other: 1 }, { persist: false }).error, 'unknown_field');
  assert.equal(config.ttlHours, 24);
});

test('internal endpoints need the admin token', async () => {
  assert.equal((await request('GET', '/internal/stats', { internal: true })).status, 401);
  assert.equal((await request('GET', '/internal/stats', { internal: true, headers: admin('x'.repeat(40)) })).status, 401);
  assert.equal((await request('PUT', '/internal/config', { internal: true, body: { enabled: false } })).status, 401);
  assert.equal(config.enabled, true);
  const read = await request('GET', '/internal/config', { internal: true, headers: admin() });
  assert.equal(read.status, 200);
  assert.deepEqual(read.json, { enabled: true, maxSnapshots: 5000, readPerMinute: 120, writePerMinute: 60, maxBody: 1048576, ttlHours: 24 });
});

test('internal config update pauses the public api', async () => {
  const updated = await request('PUT', '/internal/config', { internal: true, headers: admin(), body: { enabled: false, readPerMinute: 30 } });
  assert.equal(updated.status, 200);
  assert.equal(updated.json.enabled, false);
  assert.equal(updated.json.readPerMinute, 30);
  assert.equal((await request('GET', `/bridge/v1/snapshots/${ID}`)).status, 503);
  const invalid = await request('PUT', '/internal/config', { internal: true, headers: admin(), body: { ttlHours: 48 } });
  assert.equal(invalid.status, 400);
  assert.deepEqual(invalid.json, { error: 'invalid_value', field: 'ttlHours' });
});

test('stats count requests per minute', async () => {
  await request('PUT', `/bridge/v1/snapshots/${ID}`, { body: PACKAGE, headers: auth() });
  await request('GET', `/bridge/v1/snapshots/${ID}`);
  await request('GET', `/bridge/v1/snapshots/${'d'.repeat(22)}`);
  clock += 60_000;
  configure({ readPerMinute: 1 }, { persist: false });
  await request('GET', `/bridge/v1/snapshots/${ID}`);
  await request('GET', `/bridge/v1/snapshots/${ID}`);
  configure({ enabled: false }, { persist: false });
  await request('DELETE', `/bridge/v1/snapshots/${ID}`, { headers: auth() });
  const response = await request('GET', '/internal/stats', { internal: true, headers: admin() });
  assert.equal(response.status, 200);
  const { minutes, totals, snapshots, config: current } = response.json;
  assert.equal(minutes.length, 60);
  assert.deepEqual(minutes.at(-2), { minute: minutes.at(-2).minute, reads: 2, writes: 1, deletes: 0, notFound: 1, rateLimited: 0, unavailable: 0 });
  assert.deepEqual(minutes.at(-1), { minute: minutes.at(-1).minute, reads: 2, writes: 0, deletes: 1, notFound: 0, rateLimited: 1, unavailable: 1 });
  assert.deepEqual(totals, { reads: 4, writes: 1, deletes: 1, notFound: 1, rateLimited: 1, unavailable: 1 });
  assert.equal(snapshots.count, 1);
  assert.ok(snapshots.bytes > 100);
  assert.equal(current.enabled, false);
  assert.ok(response.json.memory.rss > 0);
  clock += 61 * 60_000;
  assert.deepEqual(stats(clock).totals, { reads: 0, writes: 0, deletes: 0, notFound: 0, rateLimited: 0, unavailable: 0 });
});

test('config is saved to the file and loaded on start', async () => {
  const { mkdtempSync, readFileSync: read, writeFileSync: write } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { spawn } = await import('node:child_process');
  const dir = mkdtempSync(join(tmpdir(), 'bridge-'));
  const file = join(dir, 'config.json');
  write(file, JSON.stringify({ enabled: false, readPerMinute: 7 }));
  const child = spawn(process.execPath, [new URL('./server.mjs', import.meta.url).pathname], {
    env: { ...process.env, PORT: '0', INTERNAL_PORT: '0', CONFIG_FILE: file, BRIDGE_ADMIN_TOKEN: TOKEN },
  });
  let output = '';
  await new Promise((resolve) => {
    child.stdout.on('data', (chunk) => {
      output += chunk;
      if (/control on \S+:\d+/.test(output) && /bridge on \S+:\d+/.test(output)) resolve();
    });
  });
  const [, publicPort] = output.match(/bridge on \S+?:(\d+)/);
  const [, controlPort] = output.match(/control on \S+?:(\d+)/);
  assert.match(output, /\(paused\)/);
  assert.equal((await fetch(`http://127.0.0.1:${publicPort}/bridge/v1/snapshots/${ID}`)).status, 503);
  const saved = await fetch(`http://127.0.0.1:${controlPort}/internal/config`, { method: 'PUT', headers: admin(), body: JSON.stringify({ enabled: true, ttlHours: 6 }) });
  assert.equal(saved.status, 200);
  assert.equal((await fetch(`http://127.0.0.1:${publicPort}/bridge/v1/snapshots/${ID}`)).status, 404);
  child.kill();
  assert.deepEqual(JSON.parse(read(file, 'utf8')), { enabled: true, maxSnapshots: 5000, readPerMinute: 7, writePerMinute: 60, maxBody: 1048576, ttlHours: 6 });
});
