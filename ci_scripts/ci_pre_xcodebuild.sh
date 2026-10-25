#!/bin/bash
set -euo pipefail

if [[ "${CI_XCODEBUILD_ACTION:-}" == "build-for-testing" && "${CI_XCODE_SCHEME:-}" != "FiscalStoreTests" ]]; then
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/lint.sh"
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/audit.sh"
fi
