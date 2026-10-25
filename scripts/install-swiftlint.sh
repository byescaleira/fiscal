#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
version="0.65.1"
checksum="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"
install_root="$project_root/.tools/swiftlint/$version"
binary="$install_root/swiftlint"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The pinned SwiftLint distribution requires macOS." >&2
  exit 1
fi

if [[ -x "$binary" ]] && [[ "$("$binary" version)" == "$version" ]]; then
  printf '%s\n' "$binary"
  exit 0
fi

download_dir="$(mktemp -d "${TMPDIR:-/tmp}/fiscal-swiftlint.XXXXXX")"
trap 'rm -rf "$download_dir"' EXIT

curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/realm/SwiftLint/releases/download/$version/portable_swiftlint.zip" \
  --output "$download_dir/portable_swiftlint.zip"
printf '%s  %s\n' "$checksum" "$download_dir/portable_swiftlint.zip" \
  | shasum -a 256 --check >&2
ditto -x -k "$download_dir/portable_swiftlint.zip" "$download_dir/extracted"
chmod +x "$download_dir/extracted/swiftlint"

if [[ "$("$download_dir/extracted/swiftlint" version)" != "$version" ]]; then
  echo "Unexpected SwiftLint version in the downloaded archive." >&2
  exit 1
fi

mkdir -p "$install_root"
mv "$download_dir/extracted/swiftlint" "$binary"
printf '%s\n' "$binary"
