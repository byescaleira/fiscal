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

case "$mode" in
  --quick)
    step scripts/build.sh Debug "$platform"
    step scripts/test.sh --affected
    web
    ;;
  --full)
    step scripts/lint.sh
    step scripts/build.sh Debug
    step scripts/test.sh
    web
    admin
    step scripts/audit.sh
    ;;
  *)
    echo "usage: $0 --quick [ios|macos|visionos] | --full" >&2
    exit 2
    ;;
esac
echo "verify $mode: ok"
