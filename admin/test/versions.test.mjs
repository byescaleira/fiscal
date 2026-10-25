import { test } from 'node:test';
import assert from 'node:assert/strict';
import { compareVersions, parseReleaseForm, parseVersion } from '../src/versions.mjs';

const form = (values) => new URLSearchParams({ platform: 'ios', minimumVersion: '1.0.0', minimumBuild: '60', recommendedVersion: '1.10.0', recommendedBuild: '80', ...values });

test('versions are x.y.z with plain numbers', () => {
  assert.deepEqual(parseVersion('1.10.0'), [1, 10, 0]);
  assert.deepEqual(parseVersion(' 2.0.3 '), [2, 0, 3]);
  for (const text of ['1.0', '1', '1.0.0.0', '01.0.0', '1.0.x', '1..0', '', '-1.0.0', '1.0.0 beta', null]) assert.equal(parseVersion(text), null, String(text));
});

test('versions compare numerically', () => {
  assert.equal(compareVersions(parseVersion('1.10.0'), parseVersion('1.9.2')), 1);
  assert.equal(compareVersions(parseVersion('1.2.3'), parseVersion('1.2.3')), 0);
  assert.equal(compareVersions(parseVersion('0.9.9'), parseVersion('1.0.0')), -1);
});

test('a valid form becomes the record values', () => {
  assert.deepEqual(parseReleaseForm(form({ minimumVersion: ' 1.0.0 ' })).value, { platform: 'ios', minimumVersion: '1.0.0', minimumBuild: 60, recommendedVersion: '1.10.0', recommendedBuild: 80 });
  assert.deepEqual(parseReleaseForm(form({ recommendedVersion: '1.0.0', recommendedBuild: '60' })).value.recommendedBuild, 60);
});

test('invalid forms name the field', () => {
  assert.deepEqual(parseReleaseForm(form({ platform: 'android' })), { error: 'unknown_platform' });
  assert.deepEqual(parseReleaseForm(form({ minimumVersion: '1.0' })), { error: 'invalid_version', field: 'minimumVersion' });
  assert.deepEqual(parseReleaseForm(form({ recommendedVersion: 'latest' })), { error: 'invalid_version', field: 'recommendedVersion' });
  assert.deepEqual(parseReleaseForm(form({ minimumBuild: '6.5' })), { error: 'invalid_build', field: 'minimumBuild' });
  assert.deepEqual(parseReleaseForm(form({ recommendedBuild: '' })), { error: 'invalid_build', field: 'recommendedBuild' });
  assert.deepEqual(parseReleaseForm(form({ minimumBuild: '-1' })), { error: 'invalid_build', field: 'minimumBuild' });
  assert.deepEqual(parseReleaseForm(form({ recommendedVersion: '0.9.0' })), { error: 'recommended_below_minimum', field: 'recommendedVersion' });
  assert.deepEqual(parseReleaseForm(form({ recommendedBuild: '59' })), { error: 'recommended_below_minimum', field: 'recommendedBuild' });
});
