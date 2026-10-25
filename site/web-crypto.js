export const INFO = 'fiscal-web:v2';
export const LINK = 'https://fiscal.byescaleira.com/link';
const encoder = new TextEncoder();

function fromBase64(text) {
  const binary = atob(text.replace(/-/g, '+').replace(/_/g, '/'));
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function toBase64URL(buffer) {
  let binary = '';
  for (const byte of new Uint8Array(buffer)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function createSessionID(bytes = crypto.getRandomValues(new Uint8Array(16))) {
  return toBase64URL(bytes);
}

export function generateKeyPair() {
  return crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveBits']);
}

export async function pairingLink(sessionID, publicKey) {
  const raw = await crypto.subtle.exportKey('raw', publicKey);
  return `${LINK}?s=${sessionID}&k=${toBase64URL(raw)}`;
}

export async function sharedSecret(privateKey, appKey) {
  const publicKey = await crypto.subtle.importKey('raw', fromBase64(appKey), { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: publicKey }, privateKey, 256));
}

export async function deriveKey(secret, sessionID) {
  const material = await crypto.subtle.importKey('raw', secret, 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt: fromBase64(sessionID), info: encoder.encode(INFO) },
    material,
    { name: 'AES-GCM', length: 256 },
    true,
    ['decrypt']
  );
}

export async function openPackage(privateKey, sessionID, pack) {
  if (!pack || pack.v !== 2) throw new Error('unsupported');
  const key = await deriveKey(await sharedSecret(privateKey, pack.appKey), sessionID);
  const plain = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: fromBase64(pack.nonce), additionalData: encoder.encode(sessionID), tagLength: 128 },
    key,
    fromBase64(pack.ciphertext)
  );
  return JSON.parse(new TextDecoder().decode(plain));
}

export async function fetchPackage(sessionID, etag, base = '/bridge') {
  const response = await fetch(`${base}/v1/snapshots/${sessionID}`, {
    headers: etag ? { 'If-None-Match': etag } : {},
    cache: 'no-store'
  });
  if (response.status === 304) return { status: 'unchanged' };
  if (response.status === 404) return { status: 'missing' };
  if (response.status === 429) return { status: 'limited' };
  if (response.status === 503) return { status: 'paused' };
  if (!response.ok) return { status: 'error' };
  return { status: 'ok', etag: response.headers.get('ETag'), pack: await response.json() };
}
