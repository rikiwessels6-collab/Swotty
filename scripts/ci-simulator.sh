#!/usr/bin/env bash
# Prints the UDID of an iPhone simulator to run tests on.
# Uses an existing one if the runner has it, otherwise downloads the iOS
# simulator runtime and/or creates a device. Diagnostics go to stderr.
set -euo pipefail

find_iphone() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
for runtime in sorted(data, reverse=True):
    if "iOS" not in runtime:
        continue
    for d in data[runtime]:
        if d.get("isAvailable") and d["name"].startswith("iPhone"):
            print(d["udid"])
            sys.exit(0)
'
}

latest_runtime() {
  xcrun simctl list runtimes available -j | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r.get("isAvailable") and r["identifier"].split(".")[-1].startswith("iOS")]
if runtimes:
    print(sorted(runtimes, key=lambda r: r["version"].split("."), reverse=True)[0]["identifier"])
'
}

echo "Simulators on this runner:" >&2
xcrun simctl list devices available >&2 || true

UDID="$(find_iphone || true)"

if [ -z "$UDID" ]; then
  RUNTIME="$(latest_runtime || true)"
  if [ -z "$RUNTIME" ]; then
    echo "No iOS simulator runtime installed; downloading it..." >&2
    xcodebuild -downloadPlatform iOS >&2
    RUNTIME="$(latest_runtime)"
  fi
  echo "Creating an iPhone simulator on $RUNTIME" >&2
  DEVICE_TYPE="$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
types = [t["identifier"] for t in json.load(sys.stdin)["devicetypes"] if "iPhone" in t["name"]]
print(types[-1])
')"
  UDID="$(xcrun simctl create "CI iPhone" "$DEVICE_TYPE" "$RUNTIME")"
fi

echo "Using simulator $UDID" >&2
echo "$UDID"
