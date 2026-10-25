import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
} from '@simplewebauthn/server';
import { Challenges, Limiter, MIN_PASSWORD, SESSION_MS, Sessions, SetupCode, createAuthStore, hashPassword, readCookie, sessionCookie, verifyPassword } from './auth.mjs';
import { createAudit } from './audit.mjs';
import { parseBridgeForm } from './bridge.mjs';
import { ENVIRONMENTS } from './cloudkit.mjs';
import { FLAGS, FLAG_NAMES, parseFlagForm } from './flags.mjs';
import { PLATFORMS, PLATFORM_NAMES, parseReleaseForm } from './versions.mjs';
import { auditPage, bridgePage, flagsPage, loginPage, notFoundPage, overviewPage, setupPage, versionsPage } from './views.mjs';

const ASSETS = {
  '/admin/assets/admin.css': ['text/css; charset=utf-8', readFileSync(new URL('../public/admin.css', import.meta.url))],
  '/admin/assets/admin.js': ['text/javascript; charset=utf-8', readFileSync(new URL('../public/admin.js', import.meta.url))],
};

const SECURITY_HEADERS = {
  'Cache-Control': 'no-store',
  'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'; object-src 'none'",
  'Referrer-Policy': 'no-referrer',
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Cross-Origin-Opener-Policy': 'same-origin',
};

const MESSAGES = {
  saved: ['Salvo.', 'success'],
  reset: ['A flag voltou ao padrão do app.', 'success'],
  release_saved: ['Versões salvas.', 'success'],
  release_reset: ['A política foi removida. O app deixa de pedir atualização nesta plataforma.', 'success'],
  bridge_saved: ['Ponte atualizada.', 'success'],
  locked: ['Muitas tentativas. Tente de novo em 15 minutos.', 'error'],
  expired: ['A sessão terminou. Entre de novo.', 'error'],
};

function clientIP(request) {
  const forwarded = String(request.headers['x-forwarded-for'] ?? '')
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
  return forwarded.at(-1) || request.socket.remoteAddress || 'unknown';
}

function readBody(request, limit = 64 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size <= limit) chunks.push(chunk);
    });
    request.on('end', () => (size > limit ? reject(Object.assign(new Error('too large'), { status: 413 })) : resolve(Buffer.concat(chunks).toString('utf8'))));
    request.on('error', reject);
  });
}

const toBase64URL = (bytes) => Buffer.from(bytes).toString('base64url');
const fromBase64URL = (text) => new Uint8Array(Buffer.from(text, 'base64url'));

export function createApp({ secretsDir, dataDir, origin, rpID, cloudkit, bridge, now = () => Date.now(), log = console.log }) {
  const store = createAuthStore({ secretsDir });
  const audit = createAudit({ dataDir, now: () => new Date(now()) });
  const limiter = new Limiter();
  const sessions = new Sessions();
  const setupChallenges = new Challenges(5 * 60 * 1000);
  const loginChallenges = new Challenges(2 * 60 * 1000);
  let account = store.load();
  let setup = null;

  if (!account) {
    setup = new SetupCode(now());
    log(`[setup] one-time setup code: ${setup.code} (valid until ${new Date(setup.expiresAt).toISOString()}). Open ${origin}/admin/setup`);
  }

  function send(response, status, body, headers = {}) {
    response.writeHead(status, { ...SECURITY_HEADERS, ...headers });
    response.end(body);
  }

  const html = (response, status, page, headers = {}) => send(response, status, page, { 'Content-Type': 'text/html; charset=utf-8', ...headers });
  const json = (response, status, value, headers = {}) => send(response, status, JSON.stringify(value), { 'Content-Type': 'application/json', ...headers });
  const redirect = (response, location, headers = {}) => send(response, 303, '', { Location: location, ...headers });

  function failure(ip, reason) {
    audit.record('login_failed', ip, { reason });
    if (limiter.fail(ip, now())) audit.record('lockout', ip);
  }

  function startSession(response, status, value) {
    const token = sessions.create(now());
    json(response, status, value, { 'Set-Cookie': sessionCookie(token) });
  }

  async function setupStart(request, response, ip, body) {
    if (account || !setup) return json(response, 404, { error: 'not_found' });
    if (limiter.locked(ip, now())) return json(response, 429, { error: 'locked' });
    if (!setup.matches(body.code, now())) {
      failure(ip, 'setup_code');
      return json(response, 401, { error: 'invalid_code' });
    }
    if (typeof body.password !== 'string' || [...body.password].length < MIN_PASSWORD) return json(response, 400, { error: 'weak_password' });
    const userID = randomBytes(16);
    const options = await generateRegistrationOptions({
      rpName: 'Fiscal Admin',
      rpID,
      userName: 'admin',
      userDisplayName: 'Fiscal Admin',
      userID,
      attestationType: 'none',
      authenticatorSelection: { residentKey: 'preferred', userVerification: 'required' },
    });
    const passwordHash = await hashPassword(body.password);
    const token = setupChallenges.put({ challenge: options.challenge, passwordHash, userID: toBase64URL(userID) }, now());
    return json(response, 200, { token, options });
  }

  async function setupFinish(request, response, ip, body) {
    if (account || !setup) return json(response, 404, { error: 'not_found' });
    if (limiter.locked(ip, now())) return json(response, 429, { error: 'locked' });
    const pending = setupChallenges.take(body.token, now());
    if (!pending) return json(response, 400, { error: 'expired' });
    let verification;
    try {
      verification = await verifyRegistrationResponse({
        response: body.response,
        expectedChallenge: pending.challenge,
        expectedOrigin: origin,
        expectedRPID: rpID,
        requireUserVerification: true,
      });
    } catch {
      verification = { verified: false };
    }
    if (!verification.verified) {
      failure(ip, 'setup_passkey');
      return json(response, 401, { error: 'invalid_passkey' });
    }
    const { credential } = verification.registrationInfo;
    account = {
      version: 1,
      createdAt: new Date(now()).toISOString(),
      userID: pending.userID,
      password: pending.passwordHash,
      credentials: [{ id: credential.id, publicKey: toBase64URL(credential.publicKey), counter: credential.counter, transports: credential.transports ?? [] }],
    };
    store.save(account);
    setup.consume();
    setup = null;
    setupChallenges.clear();
    limiter.succeed(ip);
    audit.record('setup', ip);
    return startSession(response, 200, { ok: true, redirect: '/admin/overview' });
  }

  async function loginStart(request, response, ip) {
    if (!account) return json(response, 409, { error: 'not_configured' });
    if (limiter.locked(ip, now())) return json(response, 429, { error: 'locked' });
    const options = await generateAuthenticationOptions({
      rpID,
      userVerification: 'required',
      allowCredentials: account.credentials.map((credential) => ({ id: credential.id, transports: credential.transports })),
    });
    const token = loginChallenges.put({ challenge: options.challenge }, now());
    return json(response, 200, { token, options });
  }

  async function loginFinish(request, response, ip, body) {
    if (!account) return json(response, 409, { error: 'not_configured' });
    if (limiter.locked(ip, now())) return json(response, 429, { error: 'locked' });
    const pending = loginChallenges.take(body.token, now());
    const passwordOK = await verifyPassword(body.password, account.password);
    const credential = account.credentials.find((item) => item.id === body.response?.id);
    let verification = { verified: false };
    if (pending && credential) {
      try {
        verification = await verifyAuthenticationResponse({
          response: body.response,
          expectedChallenge: pending.challenge,
          expectedOrigin: origin,
          expectedRPID: rpID,
          credential: { id: credential.id, publicKey: fromBase64URL(credential.publicKey), counter: credential.counter, transports: credential.transports },
          requireUserVerification: true,
        });
      } catch {
        verification = { verified: false };
      }
    }
    if (!passwordOK || !verification.verified) {
      failure(ip, !pending ? 'expired' : !passwordOK ? 'password' : 'passkey');
      return json(response, limiter.locked(ip, now()) ? 429 : 401, { error: limiter.locked(ip, now()) ? 'locked' : 'invalid_credentials' });
    }
    credential.counter = verification.authenticationInfo.newCounter;
    store.save(account);
    limiter.succeed(ip);
    audit.record('login', ip);
    return startSession(response, 200, { ok: true, redirect: '/admin/overview' });
  }

  async function flagsGet(response, url, message) {
    const environment = ENVIRONMENTS.includes(url.searchParams.get('env')) ? url.searchParams.get('env') : 'development';
    let remote = null;
    let error = null;
    let readAt = null;
    if (cloudkit.configured) {
      try {
        const flags = await cloudkit.listFlags(environment, FLAG_NAMES);
        remote = new Map(flags.map((flag) => [flag.name, flag]));
        readAt = new Date(now()).toISOString();
      } catch (failureError) {
        error = failureError.code ?? 'erro';
      }
    }
    return html(response, 200, flagsPage({ environment, flags: FLAGS, remote, error, readAt, message, configured: cloudkit.configured }));
  }

  async function flagsPost(response, ip, form) {
    const environment = form.get('env');
    if (!ENVIRONMENTS.includes(environment)) return redirect(response, '/admin/flags?error=env');
    const back = (query) => redirect(response, `/admin/flags?env=${environment}&${query}`);
    const parsed = parseFlagForm(form);
    if (parsed.error) return back(`error=${parsed.error}`);
    const { name, isOn, rollout } = parsed.value;
    try {
      const current = await cloudkit.listFlags(environment, FLAG_NAMES);
      const before = current.find((flag) => flag.name === name) ?? null;
      if (form.get('action') === 'reset') {
        await cloudkit.deleteFlag(environment, name);
        audit.record('flag_reset', ip, { environment, flag: name, before });
        return back('ok=reset');
      }
      await cloudkit.saveFlag(environment, { name, isOn, rollout });
      audit.record('flag_save', ip, { environment, flag: name, isOn, rollout, before: before && { isOn: before.isOn, rollout: before.rollout } });
      return back('ok=saved');
    } catch (error) {
      return back(`error=${encodeURIComponent(error.code ?? 'cloudkit')}`);
    }
  }

  const environmentFrom = (url) => (ENVIRONMENTS.includes(url.searchParams.get('env')) ? url.searchParams.get('env') : 'development');

  async function versionsGet(response, url, message) {
    const environment = environmentFrom(url);
    let remote = null;
    let error = null;
    let readAt = null;
    if (cloudkit.configured) {
      try {
        const releases = await cloudkit.listReleases(environment, PLATFORM_NAMES);
        remote = new Map(releases.map((release) => [release.platform, release]));
        readAt = new Date(now()).toISOString();
      } catch (failureError) {
        error = failureError.code ?? 'erro';
      }
    }
    return html(response, 200, versionsPage({ environment, platforms: PLATFORMS, remote, error, readAt, message, configured: cloudkit.configured }));
  }

  async function versionsPost(response, ip, form) {
    const environment = form.get('env');
    if (!ENVIRONMENTS.includes(environment)) return redirect(response, '/admin/versions?error=env');
    const back = (query) => redirect(response, `/admin/versions?env=${environment}&${query}`);
    const platform = form.get('platform') ?? '';
    if (!PLATFORM_NAMES.includes(platform)) return back('error=unknown_platform');
    const reset = form.get('action') === 'reset';
    const parsed = reset ? { value: { platform } } : parseReleaseForm(form);
    if (parsed.error) return back(`error=${parsed.error}&field=${encodeURIComponent(parsed.field ?? '')}`);
    try {
      const [current] = await cloudkit.listReleases(environment, [platform]);
      const before = current ? { minimumVersion: current.minimumVersion, minimumBuild: current.minimumBuild, recommendedVersion: current.recommendedVersion, recommendedBuild: current.recommendedBuild } : null;
      if (reset) {
        await cloudkit.deleteRelease(environment, platform);
        audit.record('release_reset', ip, { environment, platform, before });
        return back('ok=release_reset');
      }
      const { minimumVersion, minimumBuild, recommendedVersion, recommendedBuild } = parsed.value;
      await cloudkit.saveRelease(environment, parsed.value);
      audit.record('release_save', ip, { environment, platform, minimumVersion, minimumBuild, recommendedVersion, recommendedBuild, before });
      return back('ok=release_saved');
    } catch (error) {
      return back(`error=${encodeURIComponent(error.code ?? 'cloudkit')}`);
    }
  }

  async function bridgeGet(response, message) {
    try {
      return html(response, 200, bridgePage({ config: await bridge.config(), message }));
    } catch (error) {
      return html(response, 200, bridgePage({ config: null, error: error.code }));
    }
  }

  async function bridgePost(response, ip, form) {
    const parsed = parseBridgeForm(form);
    if (parsed.error) return redirect(response, `/admin/bridge?error=${parsed.error}&field=${parsed.error && encodeURIComponent(parsed.field)}`);
    try {
      const before = await bridge.config();
      const after = await bridge.update(parsed.value);
      const changes = Object.fromEntries(Object.keys(parsed.value).filter((key) => before[key] !== after[key]).map((key) => [key, [before[key], after[key]]]));
      if (Object.keys(changes).length) audit.record('bridge_config', ip, { changes });
      return redirect(response, '/admin/bridge?ok=bridge_saved');
    } catch (error) {
      return redirect(response, `/admin/bridge?error=${encodeURIComponent(error.code ?? 'bridge')}`);
    }
  }

  function messageFrom(url) {
    const ok = url.searchParams.get('ok');
    if (ok && MESSAGES[ok]) return { text: MESSAGES[ok][0], kind: MESSAGES[ok][1] };
    const error = url.searchParams.get('error');
    if (error) {
      const field = url.searchParams.get('field');
      return { text: `Não foi possível salvar (${error}${field ? `: ${field}` : ''}).`, kind: 'error' };
    }
    return null;
  }

  async function route(request, response) {
    const url = new URL(request.url, 'http://admin');
    const path = url.pathname.replace(/\/+$/, '') || '/';
    const method = request.method;
    const ip = clientIP(request);

    if (path === '/admin/health') return json(response, 200, { ok: true });
    if (ASSETS[path] && method === 'GET') return send(response, 200, ASSETS[path][1], { 'Content-Type': ASSETS[path][0], 'Cache-Control': 'no-cache' });
    if (!path.startsWith('/admin')) return html(response, 404, notFoundPage());

    const writing = method !== 'GET' && method !== 'HEAD';
    if (writing && request.headers.origin !== origin) {
      request.resume();
      return json(response, 403, { error: 'bad_origin' });
    }

    let body = {};
    let form = new URLSearchParams();
    if (writing) {
      const text = await readBody(request);
      if (String(request.headers['content-type'] ?? '').startsWith('application/json')) {
        try {
          body = JSON.parse(text || '{}');
        } catch {
          return json(response, 400, { error: 'invalid_json' });
        }
      } else {
        form = new URLSearchParams(text);
      }
    }

    if (path === '/admin/setup' && method === 'GET') return account || !setup ? html(response, 404, notFoundPage()) : html(response, 200, setupPage({ available: now() <= setup.expiresAt }));
    if (path === '/admin/setup/start' && method === 'POST') return setupStart(request, response, ip, body);
    if (path === '/admin/setup/finish' && method === 'POST') return setupFinish(request, response, ip, body);
    if (path === '/admin/login' && method === 'GET') {
      if (!account) return redirect(response, '/admin/setup');
      return html(response, 200, loginPage({ message: limiter.locked(ip, now()) ? MESSAGES.locked[0] : url.searchParams.get('expired') ? MESSAGES.expired[0] : null }));
    }
    if (path === '/admin/login/start' && method === 'POST') return loginStart(request, response, ip);
    if (path === '/admin/login/finish' && method === 'POST') return loginFinish(request, response, ip, body);

    const token = readCookie(request.headers.cookie);
    const signedIn = Boolean(account) && sessions.touch(token, now());
    if (!signedIn) {
      if (writing) return json(response, 401, { error: 'unauthorized' });
      return redirect(response, account ? '/admin/login' : '/admin/setup');
    }
    const renewed = { 'Set-Cookie': sessionCookie(token, SESSION_MS / 1000) };
    const page = (status, content) => html(response, status, content, renewed);

    if (path === '/admin/logout' && method === 'POST') {
      sessions.destroy(token);
      audit.record('logout', ip);
      return redirect(response, '/admin/login', { 'Set-Cookie': sessionCookie('', 0) });
    }
    if ((path === '/admin' || path === '/admin/overview') && method === 'GET') {
      if (path === '/admin') return redirect(response, '/admin/overview');
      try {
        return page(200, overviewPage({ stats: await bridge.stats() }));
      } catch (error) {
        return page(200, overviewPage({ error: error.code ?? 'erro' }));
      }
    }
    if (path === '/admin/flags' && method === 'GET') {
      response.setHeader('Set-Cookie', renewed['Set-Cookie']);
      return flagsGet(response, url, messageFrom(url));
    }
    if (path === '/admin/flags' && method === 'POST') return flagsPost(response, ip, form);
    if (path === '/admin/versions' && method === 'GET') {
      response.setHeader('Set-Cookie', renewed['Set-Cookie']);
      return versionsGet(response, url, messageFrom(url));
    }
    if (path === '/admin/versions' && method === 'POST') return versionsPost(response, ip, form);
    if (path === '/admin/bridge' && method === 'GET') {
      response.setHeader('Set-Cookie', renewed['Set-Cookie']);
      return bridgeGet(response, messageFrom(url));
    }
    if (path === '/admin/bridge' && method === 'POST') return bridgePost(response, ip, form);
    if (path === '/admin/audit' && method === 'GET') return page(200, auditPage({ entries: audit.recent() }));
    return page(404, notFoundPage());
  }

  function handle(request, response) {
    route(request, response).catch((error) => {
      log(`error ${request.method} ${request.url}: ${error.message}`);
      if (!response.headersSent) json(response, error.status ?? 500, { error: error.status === 413 ? 'too_large' : 'internal' });
      else response.end();
    });
  }

  return {
    handle,
    get setupCode() {
      return setup?.code ?? null;
    },
    get account() {
      return account;
    },
  };
}
