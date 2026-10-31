#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-}"
platform="${2:-${FISCAL_VERIFY_PLATFORM:-ios}}"
cd "$project_root"

step() {
  echo "==> $*"
  "$@"
}

web() {
  if ! command -v node > /dev/null; then
    echo "==> node not found; skipping the web checks"
    return
  fi
  step node --test bridge/server.test.mjs site/web-crypto.test.mjs
  step python3 scripts/site-i18n.py check
}

admin() {
  if [[ -d admin/node_modules ]]; then
    (cd admin && step node --test test/*.test.mjs)
  else
    echo "==> admin/node_modules missing; run (cd admin && npm ci --ignore-scripts) to include the admin tests"
  fi
}

server() {
  if ! command -v go > /dev/null; then
    echo "==> go not found; skipping the server checks"
    return
  fi
  local toolchain
  toolchain="go$(awk '$1 == "go" { print $2; exit }' server/go.mod)"
  (
    cd server
    export GOTOOLCHAIN="$toolchain"
    step go build ./...
    step go vet ./...
    step go test ./...
  )
}

server_changed() {
  local base=HEAD
  for ref in development main; do
    if git rev-parse --verify -q "$ref" > /dev/null; then
      base="$ref"
      break
    fi
  done
  [[ -n "$(git diff --name-only "$base...HEAD" -- server)$(git status --porcelain -- server)" ]]
}

case "$mode" in
  --quick)
    step scripts/build.sh Debug "$platform"
    step scripts/test.sh --affected
    web
    if server_changed; then
      server
    else
      echo "==> server unchanged; skipping the Go checks"
    fi
    ;;
  --full)
    step scripts/lint.sh
    step scripts/build.sh Debug
    step scripts/test.sh
    web
    admin
    server
    step python3 -I scripts/art.py check
    step scripts/audit.sh
    ;;
  *)
    echo "usage: $0 --quick [ios|macos|visionos] | --full" >&2
    exit 2
    ;;
esac
echo "verify $mode: ok"
