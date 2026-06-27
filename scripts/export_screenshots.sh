#!/bin/bash

set -euo pipefail

if [ "$#" -gt 3 ]; then
  echo "usage: $0 [output-dir] [url-scheme] [device-id]" >&2
  exit 1
fi

OUTPUT_ROOT="${1:-./output}"
URL_SCHEME_OVERRIDE="${2:-}"
DEVICE_ID_OVERRIDE="${3:-}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_command xcrun
require_command xcodebuild
require_command python3

sanitize_component() {
  local value="$1"
  value="${value//\//-}"
  value="${value//:/-}"
  value="${value//\\/-}"
  value="${value//\?/-}"
  value="${value//%/-}"
  value="${value//\*/-}"
  value="${value//|/-}"
  value="${value//\"/-}"
  value="${value//</-}"
  value="${value//>/-}"
  value="$(printf '%s' "$value" | sed 's/[[:space:]]*$//')"

  if [ -z "$value" ]; then
    value="unknown-device"
  fi

  printf '%s' "$value"
}

encode_query_value() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

infer_project_settings() {
  python3 - "$PWD" "$URL_SCHEME_OVERRIDE" <<'PY'
import json
import os
import plistlib
import subprocess
import sys

root = sys.argv[1]
scheme_override = sys.argv[2]

def run(cmd):
    return subprocess.check_output(cmd, cwd=root, text=True)

projects = []
for base, _, files in os.walk(root):
    for name in files:
        if name.endswith(".xcodeproj"):
            projects.append(os.path.join(base, name))
projects.sort()

if not projects:
    raise SystemExit("No .xcodeproj found under current directory")

project = projects[0]
project_json = json.loads(run(["xcodebuild", "-list", "-json", "-project", project]))
schemes = project_json.get("project", {}).get("schemes", [])
scheme = next((s for s in schemes if not s.endswith(("Tests", "UITests"))), schemes[0] if schemes else None)
if not scheme:
    raise SystemExit("No usable scheme found")

build_settings_json = json.loads(run([
    "xcodebuild",
    "-showBuildSettings",
    "-json",
    "-project", project,
    "-scheme", scheme,
]))

target_settings = None
for entry in build_settings_json:
    settings = entry.get("buildSettings", {})
    product_type = settings.get("PRODUCT_TYPE")
    wrapper_extension = settings.get("WRAPPER_EXTENSION")
    if product_type == "com.apple.product-type.application" or wrapper_extension == "app":
        target_settings = settings
        break

if target_settings is None and build_settings_json:
    target_settings = build_settings_json[0].get("buildSettings", {})

bundle_id = target_settings.get("PRODUCT_BUNDLE_IDENTIFIER")
if not bundle_id:
    raise SystemExit("PRODUCT_BUNDLE_IDENTIFIER not found")

project_dir = target_settings.get("PROJECT_DIR", os.path.dirname(project))
info_plist = target_settings.get("INFOPLIST_FILE")
url_scheme = scheme_override

if not url_scheme and info_plist:
    info_plist_path = os.path.join(project_dir, info_plist)
    if os.path.exists(info_plist_path):
      with open(info_plist_path, "rb") as fh:
        plist = plistlib.load(fh)
      for url_type in plist.get("CFBundleURLTypes", []):
        schemes = url_type.get("CFBundleURLSchemes", [])
        if schemes:
          url_scheme = schemes[0]
          break

if not url_scheme:
    raise SystemExit("URL scheme was not provided and could not be inferred from Info.plist")

print(json.dumps({
    "project": project,
    "scheme": scheme,
    "bundle_id": bundle_id,
    "url_scheme": url_scheme,
}))
PY
}

choose_simulators() {
  python3 <<'PY'
import json
import re
import subprocess

runtimes = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "--json"], text=True))
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "--json"], text=True))
device_types = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devicetypes", "--json"], text=True))

available_runtimes = [
    runtime for runtime in runtimes.get("runtimes", [])
    if runtime.get("isAvailable") and runtime.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
]
if not available_runtimes:
    raise SystemExit("No available iOS runtimes")

def version_key(runtime):
    version = runtime.get("version") or runtime.get("identifier", "").split("iOS-")[-1].replace("-", ".")
    parts = []
    for token in version.replace("-", ".").split("."):
        try:
            parts.append(int(token))
        except ValueError:
            parts.append(0)
    return tuple(parts)

runtime = max(available_runtimes, key=version_key)
runtime_id = runtime["identifier"]

type_map = {item["name"]: item["identifier"] for item in device_types.get("devicetypes", [])}
devices_for_runtime = devices.get("devices", {}).get(runtime_id, [])

available_names = {
    device["name"]
    for device in devices_for_runtime
    if device.get("isAvailable", True)
}

def iphone_score(name):
    if not name.startswith("iPhone "):
        return None

    generation_match = re.search(r"iPhone (\d+)", name)
    generation = int(generation_match.group(1)) if generation_match else 0

    tier = 0
    if "Pro Max" in name:
        tier = 5
    elif "Pro" in name:
        tier = 4
    elif "Plus" in name:
        tier = 3
    elif "Air" in name:
        tier = 2
    elif "e" in name:
        tier = 1

    return (generation, tier, name)

def ipad_score(name):
    if not name.startswith("iPad "):
        return None

    chip_match = re.search(r"\(M(\d+)\)", name)
    chip_generation = int(chip_match.group(1)) if chip_match else 0

    size_score = 0
    if "13-inch" in name or "12.9-inch" in name:
        size_score = 3
    elif "11-inch" in name:
        size_score = 2

    family_score = 0
    if "iPad Pro" in name:
        family_score = 4
    elif "iPad Air" in name:
        family_score = 3
    elif "iPad mini" in name:
        family_score = 1
    else:
        family_score = 2

    memory_score = 1 if "16GB" in name else 0

    return (chip_generation, family_score, size_score, memory_score, name)

def pick(prefix, scorer):
    candidates = []
    for name, identifier in type_map.items():
        if not name.startswith(prefix):
            continue
        if name not in available_names:
            continue
        score = scorer(name)
        if score is None:
            continue
        udid = None
        for device in devices_for_runtime:
            if device.get("name") == name and device.get("isAvailable", True):
                udid = device["udid"]
                break
        candidates.append((score, name, identifier, udid))

    if not candidates:
        raise SystemExit(f"No available {prefix} device found for runtime {runtime_id}")

    _, name, identifier, udid = max(candidates, key=lambda item: item[0])
    return {
        "name": name,
        "type_identifier": identifier,
        "udid": udid,
    }

print(json.dumps({
    "runtime_id": runtime_id,
    "iphone": pick("iPhone ", iphone_score),
    "ipad": pick("iPad ", ipad_score),
}))
PY
}

ensure_device() {
  local runtime_id="$1"
  local name="$2"
  local type_identifier="$3"
  local existing_udid="${4:-}"

  if [ -n "$existing_udid" ] && [ "$existing_udid" != "null" ]; then
    printf '%s' "$existing_udid"
    return
  fi

  xcrun simctl create "ScreenshotKit ${name}" "$type_identifier" "$runtime_id"
}

get_device_info() {
  local udid="$1"

  python3 - "$udid" <<'PY'
import json
import subprocess
import sys

udid = sys.argv[1]
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "--json"], text=True))
for runtime_id, runtime_devices in devices.get("devices", {}).items():
    for device in runtime_devices:
        if device.get("udid") == udid:
            print(json.dumps({
                "runtime_id": runtime_id,
                "name": device.get("name"),
                "is_available": device.get("isAvailable", True),
            }))
            raise SystemExit(0)

raise SystemExit(f"Device not found: {udid}")
PY
}

boot_device() {
  local udid="$1"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
}

run_capture_for_device() {
  local bundle_id="$1"
  local url_scheme="$2"
  local udid="$3"
  local raw_device_name="$4"
  local output_root="$5"

  local device_name
  local device_name_query
  local app_container
  local sessions_dir
  local latest_session_pointer
  local start_url
  local session_dir

  device_name="$(sanitize_component "$raw_device_name")"
  device_name_query="$(encode_query_value "$raw_device_name")"

  app_container="$(xcrun simctl get_app_container "$udid" "$bundle_id" data)"
  sessions_dir="$app_container/Library/Application Support/ScreenshotKit/Sessions"
  latest_session_pointer="$sessions_dir/latest-session.txt"
  start_url="${url_scheme}:/screenshots/start?deviceName=${device_name_query}"

  xcrun simctl openurl "$udid" "$start_url"

  for _ in $(seq 1 300); do
    if [ -f "$latest_session_pointer" ]; then
      session_dir="$(cat "$latest_session_pointer")"
      if [ -f "$session_dir/capture-complete" ]; then
        mkdir -p "$output_root"
        cp -R "$session_dir/$device_name" "$output_root/"
        if [ -f "$session_dir/manifest.json" ]; then
          cp "$session_dir/manifest.json" "$output_root/$device_name-manifest.json"
        fi
        echo "$output_root/$device_name"
        return 0
      fi
      if [ -f "$session_dir/capture-error.txt" ]; then
        cat "$session_dir/capture-error.txt" >&2
        return 1
      fi
    fi
    sleep 1
  done

  echo "timed out waiting for screenshot capture on $raw_device_name" >&2
  return 1
}

PROJECT_SETTINGS_JSON="$(infer_project_settings)"
BUNDLE_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["bundle_id"])' "$PROJECT_SETTINGS_JSON")"
URL_SCHEME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["url_scheme"])' "$PROJECT_SETTINGS_JSON")"
mkdir -p "$OUTPUT_ROOT"

if [ -n "$DEVICE_ID_OVERRIDE" ]; then
  DEVICE_INFO_JSON="$(get_device_info "$DEVICE_ID_OVERRIDE")"
  TARGET_DEVICE_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["name"])' "$DEVICE_INFO_JSON")"
  boot_device "$DEVICE_ID_OVERRIDE"
  run_capture_for_device "$BUNDLE_ID" "$URL_SCHEME" "$DEVICE_ID_OVERRIDE" "$TARGET_DEVICE_NAME" "$OUTPUT_ROOT"
  exit 0
fi

SIMULATOR_PLAN_JSON="$(choose_simulators)"
RUNTIME_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["runtime_id"])' "$SIMULATOR_PLAN_JSON")"

IPHONE_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["iphone"]["name"])' "$SIMULATOR_PLAN_JSON")"
IPHONE_TYPE_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["iphone"]["type_identifier"])' "$SIMULATOR_PLAN_JSON")"
IPHONE_UDID_EXISTING="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["iphone"]["udid"])' "$SIMULATOR_PLAN_JSON")"

IPAD_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["ipad"]["name"])' "$SIMULATOR_PLAN_JSON")"
IPAD_TYPE_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["ipad"]["type_identifier"])' "$SIMULATOR_PLAN_JSON")"
IPAD_UDID_EXISTING="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["ipad"]["udid"])' "$SIMULATOR_PLAN_JSON")"

IPHONE_UDID="$(ensure_device "$RUNTIME_ID" "$IPHONE_NAME" "$IPHONE_TYPE_ID" "$IPHONE_UDID_EXISTING")"
IPAD_UDID="$(ensure_device "$RUNTIME_ID" "$IPAD_NAME" "$IPAD_TYPE_ID" "$IPAD_UDID_EXISTING")"

boot_device "$IPHONE_UDID"
boot_device "$IPAD_UDID"

run_capture_for_device "$BUNDLE_ID" "$URL_SCHEME" "$IPHONE_UDID" "$IPHONE_NAME" "$OUTPUT_ROOT" &
iphone_pid=$!

run_capture_for_device "$BUNDLE_ID" "$URL_SCHEME" "$IPAD_UDID" "$IPAD_NAME" "$OUTPUT_ROOT" &
ipad_pid=$!

wait "$iphone_pid"
wait "$ipad_pid"
