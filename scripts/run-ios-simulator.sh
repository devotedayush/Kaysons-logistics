#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The iOS simulator requires macOS and Xcode." >&2
  exit 1
fi

flutter_bin="${FLUTTER_BIN:-flutter}"
if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  echo "Flutter was not found. Add it to PATH or set FLUTTER_BIN." >&2
  exit 1
fi
if [[ ! -f .env ]]; then
  echo "Copy .env.example to .env and fill in the Supabase URL and public anon key." >&2
  exit 1
fi

if ! xcodebuild -checkFirstLaunchStatus; then
  echo "Complete Xcode setup first: review 'sudo xcodebuild -license', then run 'sudo xcodebuild -runFirstLaunch'." >&2
  exit 1
fi

devices_json="$(xcrun simctl list devices available --json)"
device_id="$(printf '%s' "$devices_json" | python3 -c '
import json, os, sys
devices = [d for runtime, group in json.load(sys.stdin)["devices"].items()
           if ".iOS-" in runtime for d in group if d.get("isAvailable")]
requested = os.environ.get("IOS_SIMULATOR_ID")
if requested:
    devices = [d for d in devices if d["udid"] == requested]
else:
    devices = [d for d in devices if "iPhone" in d["name"]]
    devices.sort(key=lambda d: d["state"] != "Booted")
if not devices:
    sys.exit("No matching iOS simulator is installed. Run xcodebuild -downloadPlatform iOS, then create an iPhone simulator in Xcode.")
print(devices[0]["udid"])
')"

device_state="$(printf '%s' "$devices_json" | python3 -c '
import json, sys
print(next(d["state"] for group in json.load(sys.stdin)["devices"].values()
           for d in group if d["udid"] == sys.argv[1]))
' "$device_id")"
if [[ "$device_state" != Booted ]]; then
  xcrun simctl boot "$device_id"
fi

xcode_dir="$(xcode-select -p)"
if [[ -d "$xcode_dir/../Applications/DeviceHub.app" ]]; then
  open "$xcode_dir/../Applications/DeviceHub.app"
else
  open -a Simulator
fi
xcrun simctl bootstatus "$device_id" -b
exec "$flutter_bin" run -d "$device_id" "$@"
