#!/bin/bash

set -euo pipefail

if [ "$#" -gt 3 ]; then
  echo "usage: $0 [output-dir] [url-scheme] [device-id]" >&2
  exit 1
fi

OUTPUT_ROOT="${1:-./output}"
URL_SCHEME_OVERRIDE="${2:-}"
DEVICE_ID_OVERRIDE="${3:-}"
READINESS_TIMEOUT_SECONDS=15
READINESS_FALLBACK_DELAY_SECONDS=1
POST_READINESS_SETTLE_SECONDS=1

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

infer_project_settings() {
  python3 - "$PWD" "$URL_SCHEME_OVERRIDE" <<'PY'
import json
import os
import subprocess
import sys

root = sys.argv[1]

def run(cmd):
    return subprocess.check_output(cmd, cwd=root, text=True)

projects = []
for base, dirs, files in os.walk(root):
    for name in dirs:
        if name.endswith(".xcodeproj"):
            projects.append(os.path.join(base, name))
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

print(json.dumps({
    "project": project,
    "scheme": scheme,
    "bundle_id": bundle_id,
    "full_product_name": target_settings.get("FULL_PRODUCT_NAME", f"{scheme}.app"),
    "executable_name": target_settings.get("EXECUTABLE_NAME", scheme),
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

build_app() {
  local project_path="$1"
  local scheme="$2"
  local derived_data_path="$3"

  xcodebuild build \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO
}

install_app() {
  local udid="$1"
  local bundle_id="$2"
  local app_path="$3"

  xcrun simctl uninstall "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$app_path"
}

terminate_app() {
  local udid="$1"
  local bundle_id="$2"
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
}

wait_for_manifest() {
  local bundle_id="$1"
  local udid="$2"
  local raw_device_name="$3"
  local output_root="$4"

  local device_name
  local app_container
  local sessions_dir
  local latest_session_pointer
  local session_dir=""
  local output_manifest_path

  device_name="$(sanitize_component "$raw_device_name")"
  output_manifest_path="$output_root/$device_name-manifest.json"
  app_container="$(xcrun simctl get_app_container "$udid" "$bundle_id" data)"
  sessions_dir="$app_container/Library/Application Support/ScreenshotKit/Sessions"
  latest_session_pointer="$sessions_dir/latest-session.txt"

  terminate_app "$udid" "$bundle_id"
  SIMCTL_CHILD_SCREENSHOTKIT_MODE=manifest \
  SIMCTL_CHILD_SCREENSHOTKIT_DEVICE_NAME="$raw_device_name" \
  xcrun simctl launch --terminate-running-process "$udid" "$bundle_id" >/dev/null

  for _ in $(seq 1 300); do
    if [ -f "$latest_session_pointer" ]; then
      session_dir="$(cat "$latest_session_pointer")"
      if [ -f "$session_dir/capture-complete" ] && [ -f "$session_dir/manifest.json" ]; then
        mkdir -p "$output_root"
        cp "$session_dir/manifest.json" "$output_manifest_path"
        python3 - "$session_dir" "$session_dir/manifest.json" "$output_manifest_path" <<'PY'
import json
import sys
print(json.dumps({
    "session_dir": sys.argv[1],
    "manifest_path": sys.argv[2],
    "output_manifest_path": sys.argv[3],
}))
PY
        return 0
      fi
      if [ -f "$session_dir/capture-error.txt" ]; then
        cat "$session_dir/capture-error.txt" >&2
        return 1
      fi
    fi
    sleep 1
  done

  echo "timed out waiting for manifest on $raw_device_name" >&2
  return 1
}

manifest_entries_tsv() {
  local manifest_path="$1"
  python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    manifest = json.load(f)

for entry in manifest.get("entries", []):
    print("\t".join([
        entry["sceneID"],
        entry["localeIdentifier"],
        entry["outputIdentifier"],
    ]))
PY
}

wait_for_capture_readiness() {
  local udid="$1"
  local bundle_id="$2"
  local executable_name="$3"
  local raw_device_name="$4"
  local scene_id="$5"
  local locale_identifier="$6"
  local session_dir="$7"

  local log_file
  local stream_pid=""
  local ready_pattern
  local marker_path="$session_dir/capture-complete"
  local error_path="$session_dir/capture-error.txt"

  ready_pattern="SCREENSHOTKIT_READY sceneID=${scene_id} locale=${locale_identifier} "
  log_file="$(mktemp /tmp/screenshotkit-log.XXXXXX)"

  xcrun simctl spawn "$udid" log stream \
    --style compact \
    --level debug \
    --predicate "process == \"$executable_name\" AND eventMessage CONTAINS \"SCREENSHOTKIT_READY\"" \
    >"$log_file" 2>&1 &
  stream_pid=$!

  cleanup() {
    if [ -n "${stream_pid:-}" ]; then
      kill "$stream_pid" >/dev/null 2>&1 || true
      wait "$stream_pid" >/dev/null 2>&1 || true
    fi
    rm -f "${log_file:-}"
  }
  trap cleanup RETURN

  terminate_app "$udid" "$bundle_id"
  SIMCTL_CHILD_SCREENSHOTKIT_MODE=capture \
  SIMCTL_CHILD_SCREENSHOTKIT_DEVICE_NAME="$raw_device_name" \
  SIMCTL_CHILD_SCREENSHOTKIT_SCENE_ID="$scene_id" \
  SIMCTL_CHILD_SCREENSHOTKIT_LOCALE="$locale_identifier" \
  SIMCTL_CHILD_SCREENSHOTKIT_SESSION_PATH="$session_dir" \
  xcrun simctl launch --terminate-running-process "$udid" "$bundle_id" >/dev/null

  for _ in $(seq 1 "$READINESS_TIMEOUT_SECONDS"); do
    if [ -f "$error_path" ]; then
      cat "$error_path" >&2
      return 1
    fi

    if [ -f "$marker_path" ] && grep -Fq "$ready_pattern" "$marker_path"; then
      sed -n 's/.*outputIdentifier=//p' "$marker_path" | tail -n 1
      return 0
    fi

    if grep -Fq "$ready_pattern" "$log_file"; then
      grep -F "$ready_pattern" "$log_file" | sed -n 's/.*outputIdentifier=//p' | tail -n 1
      return 0
    fi

    sleep 1
  done

  echo "readiness log not detected for ${scene_id} (${locale_identifier}); falling back to ${READINESS_FALLBACK_DELAY_SECONDS}s wait" >&2
  sleep "$READINESS_FALLBACK_DELAY_SECONDS"

  if [ -f "$error_path" ]; then
    cat "$error_path" >&2
    return 1
  fi

  printf '%s\n' ""
  return 0
}

update_manifest_entry_output_identifier() {
  local manifest_path="$1"
  local scene_id="$2"
  local locale_identifier="$3"
  local output_identifier="$4"

  python3 - "$manifest_path" "$scene_id" "$locale_identifier" "$output_identifier" <<'PY'
import json
import sys

manifest_path, scene_id, locale_identifier, output_identifier = sys.argv[1:5]

with open(manifest_path, "r", encoding="utf-8") as f:
    manifest = json.load(f)

device_name = manifest.get("deviceName", "unknown-device")
for entry in manifest.get("entries", []):
    if entry.get("sceneID") == scene_id and entry.get("localeIdentifier") == locale_identifier:
        entry["outputIdentifier"] = output_identifier
        entry["relativePath"] = f"{device_name}/{locale_identifier}/{output_identifier}.png"
        break

with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
}

capture_scene() {
  local udid="$1"
  local bundle_id="$2"
  local executable_name="$3"
  local raw_device_name="$4"
  local session_dir="$5"
  local output_root="$6"
  local scene_id="$7"
  local locale_identifier="$8"
  local output_identifier="$9"
  local actual_output_identifier
  local resolved_output_identifier

  local device_name
  local locale_dir
  local target_path
  local temp_png

  device_name="$(sanitize_component "$raw_device_name")"
  locale_dir="$output_root/$device_name/$locale_identifier"
  temp_png="$(mktemp /tmp/screenshotkit-shot.XXXXXX)"

  mkdir -p "$locale_dir"

  actual_output_identifier="$(wait_for_capture_readiness \
    "$udid" \
    "$bundle_id" \
    "$executable_name" \
    "$raw_device_name" \
    "$scene_id" \
    "$locale_identifier" \
    "$session_dir")"
  resolved_output_identifier="${actual_output_identifier:-$output_identifier}"
  target_path="$locale_dir/$resolved_output_identifier.png"

  sleep "$POST_READINESS_SETTLE_SECONDS"
  xcrun simctl io "$udid" screenshot --mask ignored "$temp_png" >/dev/null
  mv "$temp_png" "$target_path"
  terminate_app "$udid" "$bundle_id"
  printf '%s\n' "$resolved_output_identifier"
}

run_capture_for_device() {
  local bundle_id="$1"
  local executable_name="$2"
  local udid="$3"
  local raw_device_name="$4"
  local output_root="$5"

  local manifest_info_json
  local session_dir
  local manifest_path
  local output_manifest_path
  local resolved_output_identifier

  manifest_info_json="$(wait_for_manifest "$bundle_id" "$udid" "$raw_device_name" "$output_root")"
  session_dir="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["session_dir"])' "$manifest_info_json")"
  manifest_path="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["manifest_path"])' "$manifest_info_json")"
  output_manifest_path="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["output_manifest_path"])' "$manifest_info_json")"

  while IFS=$'\t' read -r scene_id locale_identifier output_identifier; do
    [ -n "$scene_id" ] || continue
    resolved_output_identifier="$(capture_scene \
      "$udid" \
      "$bundle_id" \
      "$executable_name" \
      "$raw_device_name" \
      "$session_dir" \
      "$output_root" \
      "$scene_id" \
      "$locale_identifier" \
      "$output_identifier")"
    update_manifest_entry_output_identifier \
      "$output_manifest_path" \
      "$scene_id" \
      "$locale_identifier" \
      "$resolved_output_identifier"
  done < <(manifest_entries_tsv "$manifest_path")
}

PROJECT_SETTINGS_JSON="$(infer_project_settings)"
PROJECT_PATH="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["project"])' "$PROJECT_SETTINGS_JSON")"
SCHEME_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["scheme"])' "$PROJECT_SETTINGS_JSON")"
BUNDLE_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["bundle_id"])' "$PROJECT_SETTINGS_JSON")"
FULL_PRODUCT_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["full_product_name"])' "$PROJECT_SETTINGS_JSON")"
EXECUTABLE_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["executable_name"])' "$PROJECT_SETTINGS_JSON")"
DERIVED_DATA_PATH="$PWD/.build/example-derived-data"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/$FULL_PRODUCT_NAME"
mkdir -p "$OUTPUT_ROOT"

if [ -n "$DEVICE_ID_OVERRIDE" ]; then
  DEVICE_INFO_JSON="$(get_device_info "$DEVICE_ID_OVERRIDE")"
  TARGET_DEVICE_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["name"])' "$DEVICE_INFO_JSON")"
  boot_device "$DEVICE_ID_OVERRIDE"
  build_app "$PROJECT_PATH" "$SCHEME_NAME" "$DERIVED_DATA_PATH"
  install_app "$DEVICE_ID_OVERRIDE" "$BUNDLE_ID" "$APP_PATH"
  run_capture_for_device "$BUNDLE_ID" "$EXECUTABLE_NAME" "$DEVICE_ID_OVERRIDE" "$TARGET_DEVICE_NAME" "$OUTPUT_ROOT"
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
build_app "$PROJECT_PATH" "$SCHEME_NAME" "$DERIVED_DATA_PATH"
install_app "$IPHONE_UDID" "$BUNDLE_ID" "$APP_PATH"
install_app "$IPAD_UDID" "$BUNDLE_ID" "$APP_PATH"

run_capture_for_device "$BUNDLE_ID" "$EXECUTABLE_NAME" "$IPHONE_UDID" "$IPHONE_NAME" "$OUTPUT_ROOT" &
iphone_pid=$!

run_capture_for_device "$BUNDLE_ID" "$EXECUTABLE_NAME" "$IPAD_UDID" "$IPAD_NAME" "$OUTPUT_ROOT" &
ipad_pid=$!

wait "$iphone_pid"
wait "$ipad_pid"
