#!/bin/sh
set -eu
name="${1:-}"
sha="${2:-}"
case "$name" in api|ingest|pages) ;; *) echo "uso: promote-image.sh <api|ingest|pages> <sha>" >&2; exit 2 ;; esac
case "$sha" in ""|*[!0-9a-f]*) echo "sha inválido: $sha" >&2; exit 2 ;; esac
image="fiscal-$name"
new="$(docker image inspect -f '{{.Id}}' "$image:$sha")"
current="$(docker image inspect -f '{{.Id}}' "$image:current" 2>/dev/null || true)"
label="$(docker image inspect -f '{{index .Config.Labels "fiscal.sha"}}' "$image:current" 2>/dev/null || true)"
if [ -n "$current" ] && { [ "$current" = "$new" ] || [ "$label" = "$sha" ]; }; then
  echo "$image: $sha já é a current; a previous fica como está"
elif [ -n "$current" ]; then
  docker tag "$image:current" "$image:previous"
elif docker image inspect "$image:latest" >/dev/null 2>&1; then
  docker tag "$image:latest" "$image:previous"
fi
docker tag "$image:$sha" "$image:current"
