#!/bin/bash
set -euo pipefail

if [[ "${CI_XCODEBUILD_ACTION:-}" == "build-for-testing" ]]; then
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/lint.sh"
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/audit.sh"
fi
