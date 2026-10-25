import { createServer } from 'node:http';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createApp } from './app.mjs';
import { createBridge } from './bridge.mjs';
import { createCloudKit } from './cloudkit.mjs';

const env = process.env;
const secretsDir = env.SECRETS_DIR ?? '/secrets';
const keyFile = env.CLOUDKIT_KEY_FILE ?? join(secretsDir, 'cloudkit.pem');

const cloudkit = createCloudKit({
  keyID: env.CLOUDKIT_KEY_ID ?? '',
  keyIDs: { development: env.CLOUDKIT_KEY_ID_DEVELOPMENT ?? '', production: env.CLOUDKIT_KEY_ID_PRODUCTION ?? '' },
  privateKeyPem: existsSync(keyFile) ? readFileSync(keyFile, 'utf8') : null,
  baseURL: env.CLOUDKIT_URL ?? 'https://api.apple-cloudkit.com',
  container: env.CLOUDKIT_CONTAINER ?? 'iCloud.fiscal',
});

const bridge = createBridge({ url: env.BRIDGE_URL ?? 'http://fiscal-bridge:3111', token: env.BRIDGE_ADMIN_TOKEN ?? '' });

const app = createApp({
  secretsDir,
  dataDir: env.DATA_DIR ?? '/data',
  origin: env.ORIGIN ?? 'https://fiscal.byescaleira.com',
  rpID: env.RP_ID ?? 'fiscal.byescaleira.com',
  cloudkit,
  bridge,
});

const port = Number(env.PORT ?? 3120);
const host = env.HOST ?? '127.0.0.1';
const server = createServer(app.handle);
server.headersTimeout = 15_000;
server.requestTimeout = 30_000;
server.listen(port, host, () => {
  console.log(`fiscal admin on ${host}:${port}; cloudkit ${cloudkit.configured ? 'configured' : 'not configured'}`);
});
