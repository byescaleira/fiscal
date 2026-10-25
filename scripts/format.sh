#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
formatter="$(xcrun --find swift-format)"

case "${1:-}" in
  "")
    arguments=(format --in-place)
    ;;
  --check)
    arguments=(lint --strict)
    ;;
  *)
    echo "Usage: scripts/format.sh [--check]" >&2
    exit 2
    ;;
esac

paths=()
for path in \
  "$project_root/Fiscal/Fiscal" \
  "$project_root/Fiscal/Shared" \
  "$project_root/Fiscal/FiscalWidgets" \
  "$project_root/Fiscal/FiscalUITests" \
  "$project_root/Fiscal/FiscalStoreTests" \
  "$project_root/FiscalKit/Sources" \
  "$project_root/FiscalKit/Tests" \
  "$project_root/FiscalKit/Package.swift"; do
  [[ -e "$path" ]] && paths+=("$path")
done

"$formatter" "${arguments[@]}" \
  --configuration "$project_root/.swift-format" --recursive --parallel "${paths[@]}"
