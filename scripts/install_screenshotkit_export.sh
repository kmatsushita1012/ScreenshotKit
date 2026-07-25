#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="${SCREENSHOTKIT_REPOSITORY:-https://github.com/kmatsushita1012/ScreenshotKit}"
VERSION="${1:-1.3.2}"
VERSION="${VERSION#v}"
INSTALL_DIR="${SCREENSHOTKIT_INSTALL_DIR:-${HOME}/.local/bin}"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/screenshotkit-export.XXXXXX")"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "required command not found: curl" >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "required command not found: tar" >&2
  exit 1
fi

if ! command -v shasum >/dev/null 2>&1; then
  echo "required command not found: shasum" >&2
  exit 1
fi

case "$(uname -m)" in
  arm64|aarch64)
    ARCHITECTURE="arm64"
    ;;
  x86_64|amd64)
    ARCHITECTURE="x86_64"
    ;;
  *)
    echo "unsupported macOS architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

ASSET_NAME="screenshotkit-export-v${VERSION}-macos-${ARCHITECTURE}.tar.gz"
ASSET_URL="${REPOSITORY}/releases/download/v${VERSION}/${ASSET_NAME}"
ARCHIVE_PATH="$TEMP_ROOT/$ASSET_NAME"
CHECKSUM_PATH="$TEMP_ROOT/${ASSET_NAME}.sha256"

echo "Downloading screenshotkit-export v${VERSION} (${ARCHITECTURE})..."
curl --fail --silent --show-error --location "$ASSET_URL" --output "$ARCHIVE_PATH"
curl --fail --silent --show-error --location "${ASSET_URL}.sha256" --output "$CHECKSUM_PATH"

(cd "$TEMP_ROOT" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")")

tar -xzf "$ARCHIVE_PATH" -C "$TEMP_ROOT"
EXPORTER_PATH="$TEMP_ROOT/screenshotkit-export"

mkdir -p "$INSTALL_DIR"
cp "$EXPORTER_PATH" "$INSTALL_DIR/screenshotkit-export"
chmod +x "$INSTALL_DIR/screenshotkit-export"

echo "Installed $INSTALL_DIR/screenshotkit-export"
if ! command -v screenshotkit-export >/dev/null 2>&1; then
  echo "Add this directory to PATH if needed:"
  echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi
