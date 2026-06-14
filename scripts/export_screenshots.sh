#!/bin/bash

set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "usage: $0 <bundle-id> <url-scheme> <device-name> [output-dir]" >&2
  exit 1
fi

BUNDLE_ID="$1"
URL_SCHEME="$2"
DEVICE_NAME_RAW="$3"
OUTPUT_ROOT="${4:-./output}"

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
  local value="$1"
  value="${value// /%20}"
  value="${value//\//%2F}"
  value="${value//:/%3A}"
  value="${value//\?/%3F}"
  value="${value//&/%26}"
  printf '%s' "$value"
}

DEVICE_NAME="$(sanitize_component "$DEVICE_NAME_RAW")"
DEVICE_NAME_QUERY="$(encode_query_value "$DEVICE_NAME_RAW")"

APP_CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE_ID" data)"
SESSIONS_DIR="$APP_CONTAINER/Library/Application Support/ScreenshotKit/Sessions"
LATEST_SESSION_POINTER="$SESSIONS_DIR/latest-session.txt"

xcrun simctl openurl booted "$URL_SCHEME://screenshot/start?deviceName=$DEVICE_NAME_QUERY"

for _ in $(seq 1 300); do
  if [ -f "$LATEST_SESSION_POINTER" ]; then
    SESSION_DIR="$(cat "$LATEST_SESSION_POINTER")"
    if [ -f "$SESSION_DIR/capture-complete" ]; then
      mkdir -p "$OUTPUT_ROOT"
      cp -R "$SESSION_DIR/$DEVICE_NAME" "$OUTPUT_ROOT/"
      if [ -f "$SESSION_DIR/manifest.json" ]; then
        cp "$SESSION_DIR/manifest.json" "$OUTPUT_ROOT/$DEVICE_NAME-manifest.json"
      fi
      echo "$OUTPUT_ROOT/$DEVICE_NAME"
      exit 0
    fi
    if [ -f "$SESSION_DIR/capture-error.txt" ]; then
      cat "$SESSION_DIR/capture-error.txt" >&2
      exit 1
    fi
  fi
  sleep 1
done

echo "timed out waiting for screenshot capture" >&2
exit 1
