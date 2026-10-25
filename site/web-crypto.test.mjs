import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createSessionID, generateKeyPair, pairingLink, sharedSecret, deriveKey, openPackage } from './web-crypto.js';

const vector = JSON.parse(readFileSync(new URL('../docs/web-test-vector-v2.json', import.meta.url), 'utf8'));
const url = (bytes) => Buffer.from(bytes).toString('base64url');
const hex = (bytes) => Buffer.from(bytes).toString('hex');

async function webKeys() {
  const raw = Buffer.from(vector.webPublicKey.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
  const jwk = { kty: 'EC', crv: 'P-256', d: url(Buffer.from(vector.webPrivateKeyHex, 'hex')), x: url(raw.subarray(1, 33)), y: url(raw.subarray(33)) };
  const privateKey = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveBits']);
  const publicKey = await crypto.subtle.importKey('raw', raw, { name: 'ECDH', namedCurve: 'P-256' }, true, []);
  return { privateKey, publicKey };
}

test('session id from the shared bytes', () => {
  assert.equal(createSessionID(Buffer.from(vector.sessionHex, 'hex')), vector.sessionID);
  assert.match(createSessionID(), /^[A-Za-z0-9_-]{22}$/);
});

test('pairing link matches the shared link', async () => {
  const { publicKey } = await webKeys();
  assert.equal(await pairingLink(vector.sessionID, publicKey), vector.link);
});

test('shared secret and key match', async () => {
  const { privateKey } = await webKeys();
  const secret = await sharedSecret(privateKey, vector.package.appKey);
  assert.equal(hex(secret), vector.sharedSecretHex);
  const key = await deriveKey(secret, vector.sessionID);
  assert.equal(hex(await crypto.subtle.exportKey('raw', key)), vector.keyHex);
});

test('opens the shared package', async () => {
  const { privateKey } = await webKeys();
  assert.deepEqual(await openPackage(privateKey, vector.sessionID, vector.package), vector.snapshot);
});

test('rejects another browser key', async () => {
  const other = await generateKeyPair();
  await assert.rejects(openPackage(other.privateKey, vector.sessionID, vector.package));
});

test('rejects a package moved to another session', async () => {
  const { privateKey } = await webKeys();
  await assert.rejects(openPackage(privateKey, 'A'.repeat(22), vector.package));
});

test('generated private keys are not extractable', async () => {
  const pair = await generateKeyPair();
  assert.equal(pair.privateKey.extractable, false);
  await assert.rejects(crypto.subtle.exportKey('jwk', pair.privateKey));
});
