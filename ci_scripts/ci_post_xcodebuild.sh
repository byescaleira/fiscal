#!/bin/bash
set -euo pipefail

if [[ "${CI_XCODEBUILD_ACTION:-}" != "archive" || ! -d "${CI_APP_STORE_SIGNED_APP_PATH:-}" ]]; then
  exit 0
fi

cd "$CI_PRIMARY_REPOSITORY_PATH"
git fetch --deepen 40 --quiet || true
mkdir -p TestFlight

{
  echo "Build ${CI_BUILD_NUMBER:-?} · ${CI_BRANCH:-${CI_TAG:-detached}} · ${CI_COMMIT:0:7}"
  echo
  echo "Changes:"
  git log --no-merges -n 12 --pretty=format:'• %s' -- Fiscal FiscalKit | awk '{ if (length($0) > 220) print substr($0, 1, 217) "..."; else print }'
} | head -c 3800 > TestFlight/WhatToTest.en-US.txt

cat TestFlight/WhatToTest.en-US.txt
