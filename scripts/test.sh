#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$project_root/scripts/kit-access.sh"
source "$project_root/scripts/sim-destination.sh"
build_root="${FISCAL_BUILD_ROOT:-$HOME/Library/Developer/FiscalBuild}"
destination="${FISCAL_TEST_DESTINATION:-$(default_destination iPhone)}"
echo "Destination: $destination"
targets=()
if [[ "${1:-}" == "--affected" ]]; then
  while IFS= read -r target; do [[ -n "$target" ]] && targets+=("$target"); done \
    < <(python3 "$project_root/scripts/affected-tests.py" ${2:+"$2"})
  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "No test target depends on the changed files."
    exit 0
  fi
  echo "Affected: ${targets[*]}"
else
  targets=("$@")
fi
only=()
for target in ${targets[@]+"${targets[@]}"}; do only+=("-only-testing:$target"); done
xcodebuild "${kit_scm[@]}" -workspace "$project_root/Fiscal.xcworkspace" -scheme FiscalKitTests \
  -destination "$destination" -derivedDataPath "$build_root/Test" \
  -skipPackageUpdates -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  ${only[@]+"${only[@]}"} CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO test
