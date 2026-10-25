#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
catalog="$project_root/FiscalKit/Sources/FiscalResource/Assets/Media.xcassets/AppIcon"
mkdir -p "$catalog"
printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$catalog/Contents.json"
for icon in "$project_root"/Fiscal/Fiscal/FiscalIcon*.icon; do
  name="$(basename "$icon" .icon)"
  set="$catalog/$name.imageset"
  mkdir -p "$set"
  "$ictool" "$icon" --export-image --output-file "$set/$name.png" --platform iOS \
    --rendition Default --width 180 --height 180 --scale 2 > /dev/null
  "$ictool" "$icon" --export-image --output-file "$set/$name-dark.png" --platform iOS \
    --rendition Dark --width 180 --height 180 --scale 2 > /dev/null
  cat > "$set/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "$name.png", "idiom" : "universal" },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "$name-dark.png", "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
  echo "$name"
done
