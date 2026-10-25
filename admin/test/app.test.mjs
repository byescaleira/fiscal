import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createPrivateKey, createPublicKey } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';
import { createBridge } from '../src/bridge.mjs';
import { createCloudKit } from '../src/cloudkit.mjs';
import { handleInternal, resetConfig, config as bridgeConfig } from '../../bridge/server.mjs';
import { ORIGIN, PASSWORD, RP_ID, SoftAuthenticator, TEST_KEY, client, fakeCloudKit, listen, tempDir } from './helpers.mjs';

const BRIDGE_TOKEN = 'b'.repeat(48);
const publicKeyPem = createPublicKey(createPrivateKey(TEST_KEY)).export({ type: 'spki', format: 'pem' });

let clock;
let logs;
let servers;
let fake;
let app;
let base;
let secretsDir;
let dataDir;

async function boot() {
  const cloudServer = await listen(fake.handler);
  const bridgeServer = await listen((request, response) => handleInternal(request, response, { token: BRIDGE_TOKEN }));
  app = createApp({
    secretsDir,
    dataDir,
    origin: ORIGIN,
    rpID: RP_ID,
    now: () => clock,
    log: (line) => logs.push(line),
    cloudkit: createCloudKit({ keyID: 'KEY123', privateKeyPem: TEST_KEY, baseURL: cloudServer.url }),
    bridge: createBridge({ url: bridgeServer.url, token: BRIDGE_TOKEN }),
  });
  const adminServer = await listen(app.handle);
  servers.push(cloudServer, bridgeServer, adminServer);
  base = adminServer.url;
}

async function setUp(browser, authenticator) {
  const code = logs.join('\n').match(/setup code: (\S+)/)[1];
  const start = await browser.call('POST', '/admin/setup/start', { json: { code, password: PASSWORD } });
  assert.equal(start.status, 200);
  const finish = await browser.call('POST', '/admin/setup/finish', { json: { token: start.body.token, response: authenticator.create(start.body.options) } });
  assert.equal(finish.status, 200);
  return finish;
}

async function signIn(browser, authenticator, { password = PASSWORD, ip } = {}) {
  const start = await browser.call('POST', '/admin/login/start', { json: {}, ip });
  if (start.status !== 200) return start;
  return browser.call('POST', '/admin/login/finish', { json: { token: start.body.token, password, response: authenticator.get(start.body.options) }, ip });
}

beforeEach(async () => {
  clock = Date.parse('2026-10-18T12:00:00Z');
  logs = [];
  servers = [];
  fake = fakeCloudKit({ publicKeyPem });
  secretsDir = tempDir('admin-secrets-');
  dataDir = tempDir('admin-data-');
  resetConfig();
  await boot();
});

afterEach(async () => {
  await Promise.all(servers.map((server) => server.close()));
});

test('setup code is printed once and works only once', async () => {
  const printed = logs.filter((line) => line.includes('setup code'));
  assert.equal(printed.length, 1);
  assert.match(printed[0], /[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}/);
  const browser = client(base);
  assert.equal((await browser.call('GET', '/admin')).headers.get('location'), '/admin/setup');
  assert.equal((await browser.call('GET', '/admin/setup')).status, 200);
  const authenticator = new SoftAuthenticator();
  const finish = await setUp(browser, authenticator);
  assert.match(finish.setCookie, /^fiscal_admin=/);
  const stored = JSON.parse(readFileSync(join(secretsDir, 'auth.json'), 'utf8'));
  assert.equal(stored.password.algorithm, 'scrypt');
  assert.ok(!JSON.stringify(stored).includes(PASSWORD));
  assert.equal(stored.credentials.length, 1);
  assert.equal(statSync(join(secretsDir, 'auth.json')).mode & 0o777, 0o600);
  assert.equal((await browser.call('GET', '/admin/setup')).status, 404);
  const code = printed[0].match(/setup code: (\S+)/)[1];
  const again = await client(base).call('POST', '/admin/setup/start', { json: { code, password: PASSWORD } });
  assert.equal(again.status, 404);
  assert.equal(app.setupCode, null);
});

test('setup rejects a wrong code, a short password and an expired code', async () => {
  const browser = client(base);
  const code = app.setupCode;
  assert.equal((await browser.call('POST', '/admin/setup/start', { json: { code: 'AAAA-AAAA-AAAA-AAAA', password: PASSWORD } })).status, 401);
  assert.equal((await browser.call('POST', '/admin/setup/start', { json: { code, password: 'short' } })).status, 400);
  assert.equal((await browser.call('POST', '/admin/setup/start', { json: { code: code.toLowerCase().replace(/-/g, ''), password: PASSWORD } })).status, 200);
  clock += 31 * 60 * 1000;
  assert.equal((await browser.call('POST', '/admin/setup/start', { json: { code, password: PASSWORD } })).status, 401);
  assert.match((await browser.call('GET', '/admin/setup')).body, /Código expirado/);
});

test('sign in needs both the password and the passkey', async () => {
  const authenticator = new SoftAuthenticator();
  await setUp(client(base), authenticator);
  const wrongPassword = await signIn(client(base), authenticator, { password: 'wrong password here!' });
  assert.equal(wrongPassword.status, 401);
  assert.equal(wrongPassword.setCookie, null);
  const otherKey = await signIn(client(base), new SoftAuthenticator());
  assert.equal(otherKey.status, 401);
  const browser = client(base);
  const start = await browser.call('POST', '/admin/login/start', { json: {} });
  const noPasskey = await browser.call('POST', '/admin/login/finish', { json: { token: start.body.token, password: PASSWORD } });
  assert.equal(noPasskey.status, 401);
  const replay = await browser.call('POST', '/admin/login/finish', { json: { token: start.body.token, password: PASSWORD, response: authenticator.get(start.body.options) } });
  assert.equal(replay.status, 401);
  const noUV = await browser.call('POST', '/admin/login/start', { json: {} });
  const unverified = await browser.call('POST', '/admin/login/finish', { json: { token: noUV.body.token, password: PASSWORD, response: authenticator.get(noUV.body.options, { userVerified: false }) }, ip: '198.51.100.1' });
  assert.equal(unverified.status, 401);
  const ok = await signIn(browser, authenticator, { ip: '198.51.100.2' });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.redirect, '/admin/overview');
  assert.equal((await browser.call('GET', '/admin/overview')).status, 200);
  const audit = readFileSync(join(dataDir, 'audit.log'), 'utf8');
  assert.match(audit, /"action":"login"/);
  assert.match(audit, /"reason":"password"/);
  assert.match(audit, /"reason":"passkey"/);
});

test('five failures from one ip lock it for 15 minutes', async () => {
  const authenticator = new SoftAuthenticator();
  await setUp(client(base), authenticator);
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const response = await signIn(client(base), authenticator, { password: `wrong password ${attempt}!` });
    assert.equal(response.status, attempt < 4 ? 401 : 429);
  }
  const locked = await signIn(client(base), authenticator);
  assert.equal(locked.status, 429);
  assert.equal((await signIn(client(base), authenticator, { ip: '192.0.2.50' })).status, 200);
  clock += 15 * 60 * 1000 + 1;
  assert.equal((await signIn(client(base), authenticator)).status, 200);
  assert.match(readFileSync(join(dataDir, 'audit.log'), 'utf8'), /"action":"lockout"/);
});

test('session cookie flags, renewal, expiry and logout', async () => {
  const authenticator = new SoftAuthenticator();
  const browser = client(base);
  const finish = await setUp(browser, authenticator);
  for (const flag of ['HttpOnly', 'Secure', 'SameSite=Strict', 'Path=/admin', 'Max-Age=43200']) assert.ok(finish.setCookie.includes(flag), flag);
  clock += 11 * 60 * 60 * 1000;
  const page = await browser.call('GET', '/admin/audit');
  assert.equal(page.status, 200);
  assert.match(page.setCookie, /Max-Age=43200/);
  clock += 11 * 60 * 60 * 1000;
  assert.equal((await browser.call('GET', '/admin/audit')).status, 200);
  clock += 12 * 60 * 60 * 1000 + 1;
  const expired = await browser.call('GET', '/admin/audit');
  assert.equal(expired.status, 303);
  assert.equal(expired.headers.get('location'), '/admin/login');
  assert.equal((await signIn(browser, authenticator)).status, 200);
  const logout = await browser.call('POST', '/admin/logout');
  assert.equal(logout.status, 303);
  assert.match(logout.setCookie, /Max-Age=0/);
  const stolen = client(base);
  stolen.cookie = 'forged-token';
  assert.equal((await stolen.call('GET', '/admin/overview')).status, 303);
});

test('writes without the site origin are refused', async () => {
  const authenticator = new SoftAuthenticator();
  const browser = client(base);
  await setUp(browser, authenticator);
  for (const origin of [null, 'https://evil.example', 'http://fiscal.byescaleira.com']) {
    const response = await browser.call('POST', '/admin/bridge', { form: { enabledField: '1' }, origin });
    assert.equal(response.status, 403);
  }
  assert.equal(bridgeConfig.enabled, true);
  assert.equal((await client(base).call('POST', '/admin/login/start', { json: {}, origin: 'https://evil.example' })).status, 403);
  assert.equal((await client(base).call('POST', '/admin/bridge', { form: { enabledField: '1' } })).status, 401);
  const page = await browser.call('GET', '/admin/overview');
  assert.match(page.headers.get('content-security-policy'), /frame-ancestors 'none'/);
});

test('flags screen reads and writes CloudKit per environment', async () => {
  const browser = client(base);
  await setUp(browser, new SoftAuthenticator());
  const empty = await browser.call('GET', '/admin/flags?env=development');
  assert.equal(empty.status, 200);
  assert.match(empty.body, /Sem valor remoto/);
  assert.match(empty.body, /Guias/);
  const saved = await browser.call('POST', '/admin/flags', { form: { env: 'production', name: 'guides', isOn: 'on', rollout: '40', action: 'save' } });
  assert.equal(saved.status, 303);
  assert.equal(saved.headers.get('location'), '/admin/flags?env=production&ok=saved');
  assert.equal(fake.environments.production.get('guides').fields.rollout.value, 40);
  assert.equal(fake.environments.development.size, 0);
  const off = await browser.call('POST', '/admin/flags', { form: { env: 'development', name: 'guides', rollout: '100', action: 'save' } });
  assert.equal(off.status, 303);
  assert.equal(fake.environments.development.get('guides').fields.isOn.value, 0);
  const production = await browser.call('GET', '/admin/flags?env=production');
  assert.match(production.body, /Remoto: ligado em 40%/);
  const reset = await browser.call('POST', '/admin/flags', { form: { env: 'production', name: 'guides', action: 'reset' } });
  assert.equal(reset.headers.get('location'), '/admin/flags?env=production&ok=reset');
  assert.equal(fake.environments.production.size, 0);
  assert.match((await browser.call('POST', '/admin/flags', { form: { env: 'production', name: 'nope', rollout: '1' } })).headers.get('location'), /error=unknown_flag/);
  assert.match((await browser.call('POST', '/admin/flags', { form: { env: 'production', name: 'guides', rollout: '101' } })).headers.get('location'), /error=invalid_rollout/);
  const audit = readFileSync(join(dataDir, 'audit.log'), 'utf8');
  assert.match(audit, /"action":"flag_save","ip":"203.0.113.7","environment":"production","flag":"guides","isOn":true,"rollout":40/);
  assert.match(audit, /"action":"flag_reset"/);
});

test('versions screen reads, validates, writes and removes AppRelease per environment', async () => {
  const browser = client(base);
  await setUp(browser, new SoftAuthenticator());
  const empty = await browser.call('GET', '/admin/versions?env=production');
  assert.equal(empty.status, 200);
  assert.match(empty.body, /aria-current="page">Versões/);
  assert.match(empty.body, /Sem política/);
  assert.match(empty.body, /Apple Vision Pro/);
  const values = { env: 'production', platform: 'ios', minimumVersion: '1.0.0', minimumBuild: '66', recommendedVersion: '1.1.0', recommendedBuild: '70', action: 'save' };
  const saved = await browser.call('POST', '/admin/versions', { form: values });
  assert.equal(saved.status, 303);
  assert.equal(saved.headers.get('location'), '/admin/versions?env=production&ok=release_saved');
  const record = fake.environments.production.get('ios');
  assert.equal(record.recordType, 'AppRelease');
  assert.deepEqual(record.fields, {
    platform: { value: 'ios', type: 'STRING' },
    minimumVersion: { value: '1.0.0', type: 'STRING' },
    minimumBuild: { value: 66, type: 'INT64' },
    recommendedVersion: { value: '1.1.0', type: 'STRING' },
    recommendedBuild: { value: 70, type: 'INT64' },
  });
  assert.equal(fake.environments.development.size, 0);
  const page = await browser.call('GET', '/admin/versions?env=production');
  assert.match(page.body, /Remoto: mínima 1\.0\.0 \(66\), recomendada 1\.1\.0 \(70\)/);
  assert.match(page.body, /value="1\.1\.0"/);
  const below = await browser.call('POST', '/admin/versions', { form: { ...values, recommendedVersion: '0.9.0' } });
  assert.match(below.headers.get('location'), /error=recommended_below_minimum&field=recommendedVersion/);
  const malformed = await browser.call('POST', '/admin/versions', { form: { ...values, minimumVersion: '1.0' } });
  assert.match(malformed.headers.get('location'), /error=invalid_version&field=minimumVersion/);
  const build = await browser.call('POST', '/admin/versions', { form: { ...values, minimumBuild: 'abc' } });
  assert.match(build.headers.get('location'), /error=invalid_build&field=minimumBuild/);
  assert.match((await browser.call('POST', '/admin/versions', { form: { ...values, platform: 'android' } })).headers.get('location'), /error=unknown_platform/);
  assert.match((await browser.call('POST', '/admin/versions', { form: { ...values, env: 'staging' } })).headers.get('location'), /error=env/);
  assert.equal(fake.environments.production.get('ios').fields.minimumVersion.value, '1.0.0');
  await browser.call('POST', '/admin/flags', { form: { env: 'production', name: 'guides', isOn: 'on', rollout: '100', action: 'save' } });
  assert.match((await browser.call('GET', '/admin/flags?env=production')).body, /Remoto: ligado em 100%/);
  assert.doesNotMatch((await browser.call('GET', '/admin/flags?env=production')).body, /AppRelease/);
  const reset = await browser.call('POST', '/admin/versions', { form: { env: 'production', platform: 'ios', action: 'reset' } });
  assert.equal(reset.headers.get('location'), '/admin/versions?env=production&ok=release_reset');
  assert.equal(fake.environments.production.has('ios'), false);
  const audit = readFileSync(join(dataDir, 'audit.log'), 'utf8');
  assert.match(audit, /"action":"release_save","ip":"203.0.113.7","environment":"production","platform":"ios","minimumVersion":"1.0.0","minimumBuild":66,"recommendedVersion":"1.1.0","recommendedBuild":70,"before":null/);
  assert.match(audit, /"action":"release_reset".*"before":\{"minimumVersion":"1.0.0"/);
  const log = await browser.call('GET', '/admin/audit');
  assert.match(log.body, /Versões de ios em Produção: mínima 1\.0\.0 \(66\), recomendada 1\.1\.0 \(70\) \(antes: sem política\)/);
  assert.match(log.body, /Versões de ios em Produção: política removida/);
});

test('bridge screens proxy stats and config to the bridge control port', async () => {
  const browser = client(base);
  await setUp(browser, new SoftAuthenticator());
  const overview = await browser.call('GET', '/admin/overview');
  assert.match(overview.body, /Ativa/);
  assert.match(overview.body, /<svg/);
  assert.match(overview.body, /0 de 5\.000/);
  const pause = await browser.call('POST', '/admin/bridge', { form: { enabledField: '1' } });
  assert.equal(pause.headers.get('location'), '/admin/bridge?ok=bridge_saved');
  assert.equal(bridgeConfig.enabled, false);
  assert.match((await browser.call('GET', '/admin/overview')).body, /Pausada/);
  const limits = await browser.call('POST', '/admin/bridge', { form: { maxSnapshots: '2000', readPerMinute: '90', writePerMinute: '30', maxBody: '512', ttlHours: '12' } });
  assert.equal(limits.status, 303);
  assert.deepEqual({ ...bridgeConfig }, { enabled: false, maxSnapshots: 2000, readPerMinute: 90, writePerMinute: 30, maxBody: 512 * 1024, ttlHours: 12 });
  const invalid = await browser.call('POST', '/admin/bridge', { form: { ttlHours: '48' } });
  assert.match(invalid.headers.get('location'), /error=invalid_value&field=ttlHours/);
  assert.equal(bridgeConfig.ttlHours, 12);
  const resume = await browser.call('POST', '/admin/bridge', { form: { enabledField: '1', enabled: 'on' } });
  assert.equal(resume.status, 303);
  assert.equal(bridgeConfig.enabled, true);
  const page = await browser.call('GET', '/admin/bridge');
  assert.match(page.body, /value="512"/);
  const audit = await browser.call('GET', '/admin/audit');
  assert.match(audit.body, /Ponte: enabled false → true/);
  assert.match(audit.body, /ttlHours 24 → 12/);
});

test('a wrong bridge token shows the bridge as unreachable', async () => {
  const bridgeServer = await listen((request, response) => handleInternal(request, response, { token: 'other'.repeat(10) }));
  servers.push(bridgeServer);
  const bridge = createBridge({ url: bridgeServer.url, token: BRIDGE_TOKEN });
  await assert.rejects(bridge.stats(), { code: 'unauthorized' });
  await assert.rejects(createBridge({ url: 'http://127.0.0.1:9', token: BRIDGE_TOKEN }).stats(), { code: 'unreachable' });
});
