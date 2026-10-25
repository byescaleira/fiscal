#!/bin/bash
set -euo pipefail
device="${1:?usage: launch.sh <simulator udid> [fresh] [extra launch arguments...]}"
shift
build_root="${FISCAL_BUILD_ROOT:-$HOME/Library/Developer/FiscalBuild-media}"
app="$build_root/Debug/Build/Products/Debug-iphonesimulator/Fiscal.app"
bundle=com.byescaleira.fiscal
if [ "${1:-}" = fresh ]; then
  shift
  xcrun simctl uninstall "$device" "$bundle" 2>/dev/null || true
  xcrun simctl install "$device" "$app"
fi
xcrun simctl status_bar "$device" override --time 9:41 --dataNetwork wifi --wifiMode active \
  --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl ui "$device" appearance "${FISCAL_APPEARANCE:-light}"
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" \
  -fiscal.developer.showcase YES \
  -AppleLanguages "(${FISCAL_LANGUAGE:-en})" -AppleLocale "${FISCAL_LOCALE:-en_US}" "$@"
