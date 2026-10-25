#!/bin/bash
set -euo pipefail
limit="${FISCAL_SIMULATOR_LIMIT:-2}"
lock="${FISCAL_SIMULATOR_LOCK:-$(getconf DARWIN_USER_TEMP_DIR)fiscal-simulator.lock}"
command="${1:-}"
device="${2:-}"

booted() { xcrun simctl list devices booted | grep -c "(Booted)" || true; }
is_booted() { xcrun simctl list devices booted | grep -q "$device"; }
with_timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

case "$command" in
  acquire)
    [ -n "$device" ] || { echo "usage: $0 acquire|release <udid> | run <seconds> <command...> | status" >&2; exit 2; }
    while true; do
      if mkdir "$lock" 2>/dev/null; then
        if is_booted; then rmdir "$lock"; echo "ready $device"; exit 0; fi
        if [ "$(booted)" -lt "$limit" ]; then
          if ! xcrun simctl boot "$device"; then
            rmdir "$lock"
            echo "boot failed: $device" >&2
            exit 1
          fi
          rmdir "$lock"
          with_timeout 300 xcrun simctl bootstatus "$device" >/dev/null
          echo "ready $device"
          exit 0
        fi
        rmdir "$lock"
      elif [ -n "$(find "$lock" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
        rmdir "$lock" 2>/dev/null || true
        continue
      fi
      echo "waiting: $(booted)/$limit simulators booted" >&2
      sleep 20
    done
    ;;
  release)
    [ -n "$device" ] || { echo "usage: $0 acquire|release <udid> | run <seconds> <command...> | status" >&2; exit 2; }
    xcrun simctl shutdown "$device" 2>/dev/null || true
    echo "released $device"
    ;;
  run)
    shift
    seconds="$1"
    shift
    with_timeout "$seconds" "$@"
    ;;
  status)
    xcrun simctl list devices booted | grep "(Booted)" || true
    echo "$(booted)/$limit"
    ;;
  *)
    echo "usage: $0 acquire|release <udid> | run <seconds> <command...> | status" >&2
    exit 2
    ;;
esac
