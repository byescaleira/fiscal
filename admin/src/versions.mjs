export const PLATFORMS = [
  { name: 'ios', title: 'iPhone e iPad' },
  { name: 'macos', title: 'Mac' },
  { name: 'visionos', title: 'Apple Vision Pro' },
];

export const PLATFORM_NAMES = PLATFORMS.map((platform) => platform.name);

const VERSION = /^(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})$/;
const BUILD = /^(0|[1-9]\d{0,8})$/;

export function parseVersion(text) {
  const match = VERSION.exec(String(text ?? '').trim());
  return match ? match.slice(1).map(Number) : null;
}

export function compareVersions(left, right) {
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] < right[index] ? -1 : 1;
  }
  return 0;
}

export function parseReleaseForm(form) {
  const platform = form.get('platform') ?? '';
  if (!PLATFORM_NAMES.includes(platform)) return { error: 'unknown_platform' };
  const value = { platform };
  for (const key of ['minimumVersion', 'recommendedVersion']) {
    const version = parseVersion(form.get(key));
    if (!version) return { error: 'invalid_version', field: key };
    value[key] = version.join('.');
  }
  for (const key of ['minimumBuild', 'recommendedBuild']) {
    const raw = String(form.get(key) ?? '').trim();
    if (!BUILD.test(raw)) return { error: 'invalid_build', field: key };
    value[key] = Number(raw);
  }
  if (compareVersions(parseVersion(value.recommendedVersion), parseVersion(value.minimumVersion)) < 0) {
    return { error: 'recommended_below_minimum', field: 'recommendedVersion' };
  }
  if (value.recommendedBuild < value.minimumBuild) return { error: 'recommended_below_minimum', field: 'recommendedBuild' };
  return { value };
}
