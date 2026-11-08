import assert from 'node:assert/strict';
import { cpSync, existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { APP_ID, ASSOCIATION, build } from './site-build.mjs';

const site = join(dirname(fileURLToPath(import.meta.url)), '..', 'site');

function scratch(t) {
  const directory = mkdtempSync(join(tmpdir(), 'site-build-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  return directory;
}

function listed(directory) {
  return readdirSync(directory, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => relative(directory, join(entry.parentPath, entry.name)))
    .sort();
}

function rules(text) {
  const parsed = {};
  let current;
  for (const line of text.split('\n')) {
    if (line.trim() === '') continue;
    if (!line.startsWith(' ')) {
      current = line.trim();
      parsed[current] = {};
    } else {
      const [name, ...value] = line.trim().split(':');
      parsed[current][name] = value.join(':').trim();
    }
  }
  return parsed;
}

test('only the public pages, their files and the association go up', (t) => {
  const output = join(scratch(t), 'out');
  build(site, output);
  assert.deepEqual(listed(output), [
    '.well-known/apple-app-site-association',
    '404.html',
    '_headers',
    'assets/favicon.png',
    'assets/icon-dark.png',
    'assets/icon.png',
    'fonts/BricolageGrotesque.woff2',
    'fonts/OFL.txt',
    'index.html',
    'llms.txt',
    'privacy.html',
    'style.css',
    'support.html',
    'terms.html',
  ]);
  for (const kept of ['app.html', 'app.js', 'link.html', 'web.css', 'web.js', 'vendor', 'package.json', 'web-crypto.test.mjs']) {
    assert.equal(existsSync(join(output, kept)), false, kept);
  }
});

test('the association goes up byte for byte with its eight components', (t) => {
  const output = join(scratch(t), 'out');
  build(site, output);
  const published = readFileSync(join(output, ASSOCIATION));
  assert.deepEqual(published, readFileSync(join(site, ASSOCIATION)));
  const details = JSON.parse(published).applinks.details;
  assert.deepEqual(details[0].appIDs, [APP_ID]);
  assert.equal(details[0].components.length, 8);
});

test('the headers give the association JSON and every page the security and cache headers', (t) => {
  const output = join(scratch(t), 'out');
  build(site, output);
  const parsed = rules(readFileSync(join(output, '_headers'), 'utf8'));
  assert.deepEqual(parsed[`/${ASSOCIATION}`], { 'Content-Type': 'application/json' });
  assert.deepEqual(parsed['/*'], {
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Cache-Control': 'public, max-age=300',
  });
  const shared = Object.keys(parsed[`/${ASSOCIATION}`]).filter((name) => name in parsed['/*']);
  assert.deepEqual(shared, []);
});

for (const [name, change, message] of [
  ['invalid JSON', (file) => writeFileSync(file, '{"applinks":'), /não é um JSON válido/],
  ['another app', (file) => writeFileSync(file, '{"applinks":{"details":[{"appIDs":["X.other"]}]}}'), /não lista/],
  ['a missing file', (file) => rmSync(file), /faltam em/],
]) {
  test(`an association with ${name} stops the build and leaves nothing behind`, (t) => {
    const directory = scratch(t);
    const source = join(directory, 'site');
    cpSync(site, source, { recursive: true });
    change(join(source, ASSOCIATION));
    const output = join(directory, 'out');
    assert.throws(() => build(source, output), message);
    assert.equal(existsSync(output), false);
  });
}

test('a folder that already has files is never touched', (t) => {
  const output = scratch(t);
  writeFileSync(join(output, 'keep.txt'), 'keep');
  assert.throws(() => build(site, output), /não está vazia/);
  assert.deepEqual(readdirSync(output), ['keep.txt']);
});

test('an empty folder made beforehand is filled', (t) => {
  const output = scratch(t);
  build(site, output);
  assert.equal(existsSync(join(output, '_headers')), true);
});
