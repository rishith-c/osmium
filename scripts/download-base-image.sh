#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DOWNLOAD_DIR="$BUILD_DIR/downloads"
MANIFEST_PATH="$DOWNLOAD_DIR/os_list_imagingutility_v4.json"

mkdir -p "$DOWNLOAD_DIR"

curl -fsSL "https://downloads.raspberrypi.com/os_list_imagingutility_v4.json" -o "$MANIFEST_PATH"

IMAGE_URL="$(jq -r '.. | objects | select(.name? == "Raspberry Pi OS (Legacy, 64-bit) Lite") | .url' "$MANIFEST_PATH")"

if [[ -z "$IMAGE_URL" || "$IMAGE_URL" == "null" ]]; then
  echo "Failed to resolve Raspberry Pi OS Bookworm Lite arm64 image from official manifest." >&2
  exit 1
fi

IMAGE_NAME="$(basename "$IMAGE_URL")"
IMAGE_PATH="$DOWNLOAD_DIR/$IMAGE_NAME"

if [[ ! -f "$IMAGE_PATH" ]]; then
  curl -fL "$IMAGE_URL" -o "$IMAGE_PATH"
fi

echo "$IMAGE_PATH"

