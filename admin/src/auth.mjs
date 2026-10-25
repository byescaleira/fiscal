import { createHash, randomBytes, randomInt, scrypt, timingSafeEqual } from 'node:crypto';
import { readFileSync, renameSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { promisify } from 'node:util';

const scryptAsync = promisify(scrypt);
const SCRYPT = { N: 2 ** 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const MIN_PASSWORD = 14;
export const SESSION_MS = 12 * 60 * 60 * 1000;
export const SETUP_MS = 30 * 60 * 1000;
export const LOCK_WINDOW_MS = 15 * 60 * 1000;
export const LOCK_FAILURES = 5;

const digest = (value) => createHash('sha256').update(value).digest();
const same = (a, b) => timingSafeEqual(digest(a), digest(b));

export async function hashPassword(password) {
  const salt = randomBytes(16);
  const hash = await scryptAsync(password.normalize('NFKC'), salt, 64, SCRYPT);
  return { algorithm: 'scrypt', N: SCRYPT.N, r: SCRYPT.r, p: SCRYPT.p, salt: salt.toString('base64'), hash: hash.toString('base64') };
}

export async function verifyPassword(password, stored) {
  if (!stored || typeof password !== 'string') return false;
  const expected = Buffer.from(stored.hash, 'base64');
  const actual = await scryptAsync(password.normalize('NFKC'), Buffer.from(stored.salt, 'base64'), expected.length, {
    N: stored.N,
    r: stored.r,
    p: stored.p,
    maxmem: SCRYPT.maxmem,
  });
  return timingSafeEqual(actual, expected);
}

export function newSetupCode() {
  const characters = Array.from({ length: 16 }, () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]).join('');
  return characters.match(/.{4}/g).join('-');
}

export const normalizeCode = (value) => String(value ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');

export function createAuthStore({ secretsDir }) {
  const file = join(secretsDir, 'auth.json');

  function load() {
    try {
      return JSON.parse(readFileSync(file, 'utf8'));
    } catch (error) {
      if (error.code === 'ENOENT') return null;
      throw error;
    }
  }

  function save(value) {
    writeFileSync(`${file}.tmp`, JSON.stringify(value, null, 2), { mode: 0o600 });
    renameSync(`${file}.tmp`, file);
  }

  return { load, save };
}

export class SetupCode {
  constructor(now) {
    this.code = newSetupCode();
    this.expiresAt = now + SETUP_MS;
  }

  matches(value, now) {
    if (!this.code || now > this.expiresAt) return false;
    return same(normalizeCode(value), normalizeCode(this.code));
  }

  consume() {
    this.code = null;
  }
}

export class Limiter {
  constructor() {
    this.failures = new Map();
    this.locks = new Map();
  }

  locked(ip, now) {
    const until = this.locks.get(ip);
    if (until && until > now) return true;
    if (until) this.locks.delete(ip);
    return false;
  }

  fail(ip, now) {
    const recent = (this.failures.get(ip) ?? []).filter((at) => now - at < LOCK_WINDOW_MS);
    recent.push(now);
    if (recent.length >= LOCK_FAILURES) {
      this.failures.delete(ip);
      this.locks.set(ip, now + LOCK_WINDOW_MS);
      return true;
    }
    this.failures.set(ip, recent);
    return false;
  }

  succeed(ip) {
    this.failures.delete(ip);
  }
}

export class Sessions {
  constructor() {
    this.entries = new Map();
  }

  create(now) {
    const token = randomBytes(32).toString('base64url');
    this.entries.set(digest(token).toString('hex'), now + SESSION_MS);
    return token;
  }

  touch(token, now) {
    if (!token) return false;
    const key = digest(token).toString('hex');
    const expires = this.entries.get(key);
    if (!expires || expires <= now) {
      this.entries.delete(key);
      return false;
    }
    this.entries.set(key, now + SESSION_MS);
    return true;
  }

  destroy(token) {
    if (token) this.entries.delete(digest(token).toString('hex'));
  }

  clear() {
    this.entries.clear();
  }
}

export class Challenges {
  constructor(ttl) {
    this.ttl = ttl;
    this.entries = new Map();
  }

  put(value, now) {
    for (const [key, entry] of this.entries) if (entry.expiresAt <= now) this.entries.delete(key);
    if (this.entries.size >= 50) this.entries.delete(this.entries.keys().next().value);
    const token = randomBytes(24).toString('base64url');
    this.entries.set(digest(token).toString('hex'), { ...value, expiresAt: now + this.ttl });
    return token;
  }

  take(token, now) {
    if (typeof token !== 'string') return null;
    const key = digest(token).toString('hex');
    const entry = this.entries.get(key);
    this.entries.delete(key);
    return entry && entry.expiresAt > now ? entry : null;
  }

  clear() {
    this.entries.clear();
  }
}

export function sessionCookie(token, maxAgeSeconds = SESSION_MS / 1000) {
  return `fiscal_admin=${token}; HttpOnly; Secure; SameSite=Strict; Path=/admin; Max-Age=${maxAgeSeconds}`;
}

export function readCookie(header, name = 'fiscal_admin') {
  for (const part of String(header ?? '').split(';')) {
    const [key, ...rest] = part.trim().split('=');
    if (key === name) return rest.join('=');
  }
  return null;
}
