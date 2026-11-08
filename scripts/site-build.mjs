import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const APP_ID = 'Q7QLR2PH2X.com.byescaleira.fiscal';
export const ASSOCIATION = '.well-known/apple-app-site-association';
export const FILES = [
  'index.html',
  'privacy.html',
  'terms.html',
  'support.html',
  '404.html',
  'llms.txt',
  'style.css',
  'assets/favicon.png',
  'assets/icon.png',
  'assets/icon-dark.png',
  'fonts/BricolageGrotesque.woff2',
  'fonts/OFL.txt',
  ASSOCIATION,
];
export const HEADERS = `/${ASSOCIATION}
  Content-Type: application/json

/*
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Cache-Control: public, max-age=300
`;

export function checkAssociation(text) {
  let association;
  try {
    association = JSON.parse(text);
  } catch {
    throw new Error(`${ASSOCIATION} não é um JSON válido`);
  }
  const details = association?.applinks?.details;
  const found = Array.isArray(details) && details.some((detail) => detail?.appIDs?.includes(APP_ID));
  if (!found) throw new Error(`${ASSOCIATION} não lista ${APP_ID} em applinks.details[].appIDs`);
}

export function build(source, output) {
  if (existsSync(output) && readdirSync(output).length > 0) {
    throw new Error(`${output} já existe e não está vazia`);
  }
  const missing = FILES.filter((file) => !existsSync(join(source, file)));
  if (missing.length > 0) throw new Error(`faltam em ${source}: ${missing.join(', ')}`);
  checkAssociation(readFileSync(join(source, ASSOCIATION), 'utf8'));
  const created = !existsSync(output);
  try {
    for (const file of FILES) {
      mkdirSync(dirname(join(output, file)), { recursive: true });
      cpSync(join(source, file), join(output, file));
    }
    writeFileSync(join(output, '_headers'), HEADERS);
  } catch (error) {
    if (created) rmSync(output, { recursive: true, force: true });
    else for (const entry of readdirSync(output)) rmSync(join(output, entry), { recursive: true, force: true });
    throw error;
  }
  return [...FILES, '_headers'].sort();
}

const here = fileURLToPath(import.meta.url);
if (process.argv[1] && resolve(process.argv[1]) === here) {
  const output = process.argv[2];
  if (!output) {
    console.error('Uso: node scripts/site-build.mjs <pasta>');
    process.exit(2);
  }
  try {
    for (const file of build(join(dirname(here), '..', 'site'), resolve(output))) console.log(file);
  } catch (error) {
    console.error(`site-build: ${error.message}`);
    process.exit(1);
  }
}
