#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="${FISCAL_BUILD_ROOT:-$HOME/Library/Developer/FiscalBuild}"
device="${FISCAL_DEVICE:?Set FISCAL_DEVICE to the iPhone UDID (xcrun devicectl list devices)}"
xcodebuild -workspace "$project_root/Fiscal.xcworkspace" -scheme Production -configuration Debug \
  -destination "platform=iOS,id=$device" -derivedDataPath "$build_root/Device" \
  -allowProvisioningUpdates -skipPackageUpdates -disableAutomaticPackageResolution \
  COMPILER_INDEX_STORE_ENABLE=NO build
app="$build_root/Device/Build/Products/Debug-iphoneos/Fiscal.app"
xcrun devicectl device install app --timeout 300 --device "$device" "$app"
xcrun devicectl device process launch --terminate-existing --device "$device" \
  com.byescaleira.fiscal -- "$@"
