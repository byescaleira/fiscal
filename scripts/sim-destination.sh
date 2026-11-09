#!/bin/bash
default_destination() {
  xcrun simctl list devices available -j | python3 -I -c '
import json, sys
kinds = sys.argv[1:]
runtimes = json.load(sys.stdin)["devices"]
found = []
for runtime, devices in runtimes.items():
    if ".SimRuntime.iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.rsplit("iOS-", 1)[1].split("-"))
    for device in devices:
        identifier = device.get("deviceTypeIdentifier", "")
        for rank, kind in enumerate(kinds):
            if kind in identifier:
                found.append((-rank, device["state"] == "Booted", version, device["udid"]))
if not found:
    sys.exit("No available simulator for " + ", ".join(kinds) + "; set FISCAL_TEST_DESTINATION.")
print("platform=iOS Simulator,id=" + max(found)[3])
' "$@"
}
