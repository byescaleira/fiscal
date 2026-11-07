#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$project_root/scripts/kit-access.sh"
source "$project_root/scripts/sim-destination.sh"
build_root="${FISCAL_BUILD_ROOT:-$HOME/Library/Developer/FiscalBuild}"
destination="${FISCAL_TEST_DESTINATION:-$(default_destination iPad iPhone)}"
results="$build_root/UITests/$(date +%Y%m%d-%H%M%S).xcresult"
captures="${results%.xcresult}"
status=0
xcodebuild "${kit_scm[@]}" -workspace "$project_root/Fiscal.xcworkspace" -scheme FiscalUITests \
  -destination "$destination" -derivedDataPath "$build_root/UITest" \
  -skipPackageUpdates -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -collect-test-diagnostics never -resultBundlePath "$results" \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO "$@" test || status=$?
if [[ -d "$results" ]]; then
  mkdir -p "$captures"
  xcrun xcresulttool export attachments --path "$results" --output-path "$captures" >/dev/null
  echo "Captures: $captures"
fi
exit "$status"
