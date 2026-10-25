#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
"$project_root/scripts/format.sh" --check
swiftlint_binary="$("$project_root/scripts/install-swiftlint.sh")"

cd "$project_root"
"$swiftlint_binary" lint --strict --config "$project_root/.swiftlint.yml" \
  --cache-path "$project_root/.tools/swiftlint/cache" "$@"
