import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createPrivateKey, createPublicKey, verify } from 'node:crypto';
import { createCloudKit, isoDate, signRequest } from '../src/cloudkit.mjs';
import { TEST_KEY, fakeCloudKit, listen } from './helpers.mjs';

const DATE = new Date('2026-10-18T12:34:56.789Z');
const SUBPATH = '/database/1/iCloud.fiscal/development/public/records/query';
const BODY = '{"query":{"recordType":"FeatureFlag"},"resultsLimit":200}';
const publicKeyPem = createPublicKey(createPrivateKey(TEST_KEY)).export({ type: 'spki', format: 'pem' });

test('iso date drops milliseconds', () => {
  assert.equal(isoDate(DATE), '2026-10-18T12:34:56Z');
});

test('signature covers date, body hash and subpath with the fixed key', () => {
  const { message, headers } = signRequest({ keyID: 'KEY123', privateKey: createPrivateKey(TEST_KEY), subpath: SUBPATH, body: BODY, date: DATE });
  assert.equal(message, `2026-10-18T12:34:56Z:lISxco7MhYuCOCW+Un1zcmysQMz6erLNFq15rzulQTA=:${SUBPATH}`);
  assert.equal(headers['X-Apple-CloudKit-Request-KeyID'], 'KEY123');
  assert.equal(headers['X-Apple-CloudKit-Request-ISO8601Date'], '2026-10-18T12:34:56Z');
  const signature = Buffer.from(headers['X-Apple-CloudKit-Request-SignatureV1'], 'base64');
  assert.equal(signature[0], 0x30);
  assert.ok(verify('sha256', Buffer.from(message), publicKeyPem, signature));
  assert.ok(!verify('sha256', Buffer.from(message.replace('development', 'production')), publicKeyPem, signature));
});

test('empty body hashes to the sha256 of nothing', () => {
  const { message } = signRequest({ keyID: 'K', privateKey: createPrivateKey(TEST_KEY), subpath: '/x', body: '', date: DATE });
  assert.equal(message, '2026-10-18T12:34:56Z:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=:/x');
});

test('flags read, write and reset against a fake CloudKit', async () => {
  const fake = fakeCloudKit({ publicKeyPem });
  const server = await listen(fake.handler);
  const cloudkit = createCloudKit({ keyID: 'KEY123', privateKeyPem: TEST_KEY, baseURL: server.url, now: () => DATE });
  try {
    assert.deepEqual(await cloudkit.listFlags('development', ['web']), []);
    const saved = await cloudkit.saveFlag('development', { name: 'web', isOn: true, rollout: 25 });
    assert.equal(saved.name, 'web');
    assert.deepEqual(fake.environments.development.get('web').fields, {
      name: { value: 'web', type: 'STRING' },
      isOn: { value: 1, type: 'INT64' },
      rollout: { value: 25, type: 'INT64' },
    });
    assert.equal(fake.environments.production.size, 0);
    const listed = await cloudkit.listFlags('development', ['web']);
    assert.deepEqual(listed.map(({ name, isOn, rollout }) => ({ name, isOn, rollout })), [{ name: 'web', isOn: true, rollout: 25 }]);
    fake.failQuery = true;
    const looked = await cloudkit.listFlags('development', ['web', 'pro']);
    assert.deepEqual(looked.map((flag) => flag.name), ['web']);
    await cloudkit.deleteFlag('development', 'web');
    assert.equal(fake.environments.development.size, 0);
    assert.ok(fake.requests.every((request) => request.valid && request.keyID === 'KEY123'));
    assert.deepEqual(fake.requests.map((request) => request.url.split('/public/')[1]), ['records/query', 'records/modify', 'records/query', 'records/query', 'records/lookup', 'records/modify']);
    assert.equal(fake.requests[1].body.operations[0].operationType, 'forceReplace');
  } finally {
    await server.close();
  }
});

test('app releases are looked up by platform and saved as AppRelease', async () => {
  const fake = fakeCloudKit({ publicKeyPem });
  const server = await listen(fake.handler);
  const cloudkit = createCloudKit({ keyIDs: { development: 'DEV', production: 'PROD' }, privateKeyPem: TEST_KEY, baseURL: server.url, now: () => DATE });
  try {
    assert.deepEqual(await cloudkit.listReleases('development', ['ios', 'macos']), []);
    await cloudkit.saveFlag('development', { name: 'macos', isOn: true, rollout: 100 });
    const saved = await cloudkit.saveRelease('development', { platform: 'ios', minimumVersion: '1.0.0', minimumBuild: 66, recommendedVersion: '1.10.0', recommendedBuild: 80 });
    assert.deepEqual({ ...saved, modifiedAt: undefined }, { platform: 'ios', minimumVersion: '1.0.0', minimumBuild: 66, recommendedVersion: '1.10.0', recommendedBuild: 80, modifiedAt: undefined });
    const listed = await cloudkit.listReleases('development', ['ios', 'macos', 'visionos']);
    assert.deepEqual(listed.map((release) => release.platform), ['ios']);
    assert.deepEqual((await cloudkit.listFlags('development', ['macos'])).map((flag) => flag.name), ['macos']);
    await cloudkit.deleteRelease('development', 'ios');
    assert.equal(fake.environments.development.has('ios'), false);
    assert.equal(fake.environments.production.size, 0);
    assert.ok(fake.requests.every((request) => request.valid && request.keyID === 'DEV'));
    assert.equal(fake.requests.find((request) => request.body.operations?.[0]?.record?.recordType === 'AppRelease').body.operations[0].operationType, 'forceReplace');
  } finally {
    await server.close();
  }
});

test('a wrong key is refused and not configured fails fast', async () => {
  const fake = fakeCloudKit({ publicKeyPem });
  const server = await listen(fake.handler);
  const { generateKeyPairSync } = await import('node:crypto');
  const other = generateKeyPairSync('ec', { namedCurve: 'P-256' }).privateKey.export({ type: 'sec1', format: 'pem' });
  try {
    const cloudkit = createCloudKit({ keyID: 'KEY123', privateKeyPem: other, baseURL: server.url });
    await assert.rejects(cloudkit.listFlags('production', ['web']), { code: 'AUTHENTICATION_FAILED' });
    const missing = createCloudKit({ keyID: '', privateKeyPem: TEST_KEY, baseURL: server.url });
    assert.equal(missing.configured, false);
    await assert.rejects(missing.listFlags('development', ['web']), { code: 'NOT_CONFIGURED' });
    await assert.rejects(createCloudKit({ keyID: 'K', privateKeyPem: TEST_KEY, baseURL: server.url }).saveFlag('staging', { name: 'web', isOn: true, rollout: 1 }), { code: 'BAD_ENVIRONMENT' });
  } finally {
    await server.close();
  }
});
