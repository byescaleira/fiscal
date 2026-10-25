#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="${FISCAL_BUILD_ROOT:-$HOME/Library/Developer/FiscalBuild}"
objects="$build_root/Debug/Build/Intermediates.noindex"
catalog="$project_root/Fiscal/Fiscal/Localizable.xcstrings"

strings=()
while IFS= read -r -d '' file; do
  strings+=("$file")
done < <(find "$objects" -path '*Debug-iphonesimulator*' -name '*.stringsdata' \
  -not -path '*/FiscalAudit*' -not -path '*/FiscalMock*' -not -path '*/FiscalPreview*' \
  -not -path '*/FiscalMCP-t.build/*' -not -path '*/FiscalWidgets.build/*' -not -path '*Tests*' -print0)

if [[ ${#strings[@]} -eq 0 ]]; then
  echo "No extracted strings in $objects. Run scripts/build.sh Debug first." >&2
  exit 1
fi
xcrun xcstringstool sync "$catalog" --stringsdata "${strings[@]}"
echo "Localizable: $(xcrun xcstringstool print "$catalog" | wc -l | tr -d ' ') strings"

widgets=()
while IFS= read -r -d '' file; do
  widgets+=("$file")
done < <(find "$objects" -path '*Debug-iphonesimulator*' -path '*/FiscalWidgets.build/*' -name '*.stringsdata' -print0)
if [[ ${#widgets[@]} -gt 0 ]]; then
  widget_catalog="$project_root/Fiscal/FiscalWidgets/Localizable.xcstrings"
  xcrun xcstringstool sync "$widget_catalog" --stringsdata "${widgets[@]}"
  echo "Widgets: $(xcrun xcstringstool print "$widget_catalog" | wc -l | tr -d ' ') strings"
fi
