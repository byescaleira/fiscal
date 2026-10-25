#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="${FISCAL_BUILD_ROOT:-$HOME/Library/Developer/FiscalBuild}"
configuration="${1:-Debug}"
platforms="${2:-ios macos visionos}"
build() {
  xcodebuild -workspace "$project_root/Fiscal.xcworkspace" -scheme Production \
    -configuration "$configuration" -destination "$1" -derivedDataPath "$2" \
    -skipPackageUpdates -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO ARCHS=arm64 build
}
for platform in $platforms; do
  case "$platform" in
    ios) build 'generic/platform=iOS Simulator' "$build_root/$configuration" ;;
    macos) build 'generic/platform=macOS' "$build_root/macOS-$configuration" ;;
    visionos) build 'generic/platform=visionOS Simulator' "$build_root/visionOS-$configuration" ;;
    *) echo "Unknown platform: $platform (use ios, macos or visionos)" >&2; exit 1 ;;
  esac
done
