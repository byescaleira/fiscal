import { createHash, createPublicKey, generateKeyPairSync, randomBytes, sign, verify } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { CONTAINER } from '../src/cloudkit.mjs';

export const ORIGIN = 'https://fiscal.byescaleira.com';
export const RP_ID = 'fiscal.byescaleira.com';
export const PASSWORD = 'correct horse battery staple';

export const TEST_KEY = `-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIOwMrlNHWfUCJyzAtAN3MzsYbvjK5kqCczllbOMmYuuJoAoGCCqGSM49
AwEHoUQDQgAE1MSFddJcxNyaucK5VunCWvUBHPhWZd+xxecwUVyRGoxvJrg8tW6U
bN3EGba6Ym6WZRO6SLVlbrYqSqIgn6oYog==
-----END EC PRIVATE KEY-----
`;

const RECORDS_PATH = new RegExp(`^/database/1/${CONTAINER.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/(development|production)/public/records/(query|lookup|modify)$`);

export const tempDir = (prefix) => mkdtempSync(join(tmpdir(), prefix));

function header(major, length) {
  if (length < 24) return Buffer.from([(major << 5) | length]);
  if (length < 256) return Buffer.from([(major << 5) | 24, length]);
  if (length < 65536) return Buffer.from([(major << 5) | 25, length >> 8, length & 255]);
  const buffer = Buffer.alloc(5);
  buffer[0] = (major << 5) | 26;
  buffer.writeUInt32BE(length, 1);
  return buffer;
}

export function cbor(value) {
  if (Number.isInteger(value)) return value >= 0 ? header(0, value) : header(1, -1 - value);
  if (typeof value === 'string') {
    const bytes = Buffer.from(value, 'utf8');
    return Buffer.concat([header(3, bytes.length), bytes]);
  }
  if (value instanceof Uint8Array) return Buffer.concat([header(2, value.length), Buffer.from(value)]);
  if (value instanceof Map) {
    return Buffer.concat([header(5, value.size), ...[...value].flatMap(([key, item]) => [cbor(key), cbor(item)])]);
  }
  throw new Error(`cbor: unsupported ${typeof value}`);
}

const sha256 = (value) => createHash('sha256').update(value).digest();
const b64url = (value) => Buffer.from(value).toString('base64url');

export class SoftAuthenticator {
  constructor({ origin = ORIGIN, rpID = RP_ID } = {}) {
    this.origin = origin;
    this.rpID = rpID;
    this.keys = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    this.credentialID = randomBytes(16);
    this.counter = 0;
  }

  create(options) {
    const clientDataJSON = Buffer.from(JSON.stringify({ type: 'webauthn.create', challenge: options.challenge, origin: this.origin, crossOrigin: false }));
    const jwk = this.keys.publicKey.export({ format: 'jwk' });
    const cose = new Map([
      [1, 2],
      [3, -7],
      [-1, 1],
      [-2, Buffer.from(jwk.x, 'base64url')],
      [-3, Buffer.from(jwk.y, 'base64url')],
    ]);
    const idLength = Buffer.alloc(2);
    idLength.writeUInt16BE(this.credentialID.length);
    const authData = Buffer.concat([sha256(this.rpID), Buffer.from([0x45]), Buffer.alloc(4), Buffer.alloc(16), idLength, this.credentialID, cbor(cose)]);
    const attestationObject = cbor(new Map([['fmt', 'none'], ['attStmt', new Map()], ['authData', authData]]));
    return {
      id: b64url(this.credentialID),
      rawId: b64url(this.credentialID),
      type: 'public-key',
      clientExtensionResults: {},
      authenticatorAttachment: 'platform',
      response: { clientDataJSON: b64url(clientDataJSON), attestationObject: b64url(attestationObject), transports: ['internal'] },
    };
  }

  get(options, { userVerified = true } = {}) {
    this.counter += 1;
    const clientDataJSON = Buffer.from(JSON.stringify({ type: 'webauthn.get', challenge: options.challenge, origin: this.origin, crossOrigin: false }));
    const counter = Buffer.alloc(4);
    counter.writeUInt32BE(this.counter);
    const authenticatorData = Buffer.concat([sha256(this.rpID), Buffer.from([userVerified ? 0x05 : 0x01]), counter]);
    const signature = sign('sha256', Buffer.concat([authenticatorData, sha256(clientDataJSON)]), this.keys.privateKey);
    return {
      id: b64url(this.credentialID),
      rawId: b64url(this.credentialID),
      type: 'public-key',
      clientExtensionResults: {},
      response: { clientDataJSON: b64url(clientDataJSON), authenticatorData: b64url(authenticatorData), signature: b64url(signature) },
    };
  }
}

export async function listen(handler) {
  const server = createServer(handler);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  return {
    url,
    close: () => {
      server.closeAllConnections();
      return new Promise((resolve) => server.close(resolve));
    },
  };
}

export function client(base) {
  let cookie = null;
  async function call(method, path, { json, form, origin = ORIGIN, headers = {}, ip = '203.0.113.7' } = {}) {
    const response = await fetch(`${base}${path}`, {
      method,
      redirect: 'manual',
      headers: {
        'X-Forwarded-For': ip,
        ...(method !== 'GET' && origin ? { Origin: origin } : {}),
        ...(cookie ? { Cookie: `fiscal_admin=${cookie}` } : {}),
        ...(json ? { 'Content-Type': 'application/json' } : {}),
        ...(form ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
        ...headers,
      },
      body: json ? JSON.stringify(json) : form ? new URLSearchParams(form).toString() : undefined,
    });
    const setCookie = response.headers.get('set-cookie');
    if (setCookie) {
      const value = setCookie.match(/^fiscal_admin=([^;]*)/)?.[1];
      cookie = value || null;
    }
    const text = await response.text();
    let body = text;
    if ((response.headers.get('content-type') ?? '').startsWith('application/json')) body = JSON.parse(text);
    return { status: response.status, headers: response.headers, body, setCookie };
  }
  return {
    call,
    get cookie() {
      return cookie;
    },
    set cookie(value) {
      cookie = value;
    },
  };
}

export function fakeCloudKit({ publicKeyPem }) {
  const environments = { development: new Map(), production: new Map() };
  const requests = [];
  let failQuery = false;
  const publicKey = createPublicKey(publicKeyPem);

  const handler = (request, response) => {
    const chunks = [];
    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => {
      const body = Buffer.concat(chunks).toString('utf8');
      const date = request.headers['x-apple-cloudkit-request-iso8601date'];
      const signature = request.headers['x-apple-cloudkit-request-signaturev1'];
      const message = `${date}:${sha256(body).toString('base64')}:${request.url}`;
      const valid = Boolean(signature) && verify('sha256', Buffer.from(message), publicKey, Buffer.from(signature, 'base64'));
      const reply = (status, value) => {
        response.writeHead(status, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(value));
      };
      requests.push({ url: request.url, keyID: request.headers['x-apple-cloudkit-request-keyid'], valid, body: JSON.parse(body) });
      if (!valid) return reply(401, { serverErrorCode: 'AUTHENTICATION_FAILED', reason: 'bad signature' });
      const match = request.url.match(RECORDS_PATH);
      if (!match) return reply(404, { serverErrorCode: 'NOT_FOUND' });
      const records = environments[match[1]];
      const payload = JSON.parse(body);
      const shape = (record) => ({ recordName: record.recordName, recordType: record.recordType ?? 'FeatureFlag', fields: record.fields, modified: { timestamp: 1_760_000_000_000 }, recordChangeTag: 'x' });
      if (match[2] === 'query') {
        if (failQuery) return reply(400, { serverErrorCode: 'BAD_REQUEST', reason: 'Field recordName is not marked queryable' });
        return reply(200, { records: [...records.values()].filter((record) => (record.recordType ?? 'FeatureFlag') === payload.query.recordType).map(shape) });
      }
      if (match[2] === 'lookup') {
        return reply(200, { records: payload.records.map(({ recordName }) => (records.has(recordName) ? shape(records.get(recordName)) : { recordName, serverErrorCode: 'NOT_FOUND' })) });
      }
      const results = payload.operations.map(({ operationType, record }) => {
        if (operationType === 'forceDelete') {
          records.delete(record.recordName);
          return { recordName: record.recordName, deleted: true };
        }
        records.set(record.recordName, record);
        return shape(record);
      });
      return reply(200, { records: results });
    });
  };

  return {
    handler,
    environments,
    requests,
    set failQuery(value) {
      failQuery = value;
    },
  };
}
