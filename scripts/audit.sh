#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
if ! grep -q '"FiscalAudit"' "$project_root/FiscalKit/Package.swift"; then
  echo "Skipping the data audit: FiscalKit has no FiscalAudit target yet (recipe in the byescaleira-sdd tooling-and-ci.md)."
  exit 0
fi
swift build -c release --package-path "$project_root/FiscalKit" --product FiscalAudit
"$project_root/FiscalKit/.build/release/FiscalAudit" check
