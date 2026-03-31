#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DOWNLOAD_DIR="$BUILD_DIR/downloads"
MANIFEST_PATH="$DOWNLOAD_DIR/os_list_imagingutility_v4.json"
CONFIG_FILE="$ROOT/config/osmium.env"

mkdir -p "$DOWNLOAD_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

OSMIUM_BASE_PROFILE="${OSMIUM_BASE_PROFILE:-full}"

case "$OSMIUM_BASE_PROFILE" in
  full)
    IMAGE_NAME_FILTER='Raspberry Pi OS (Legacy, 64-bit) Full'
    ;;
  lite)
    IMAGE_NAME_FILTER='Raspberry Pi OS (Legacy, 64-bit) Lite'
    ;;
  *)
    echo "Unsupported OSMIUM_BASE_PROFILE: $OSMIUM_BASE_PROFILE" >&2
    echo "Use 'full' or 'lite'." >&2
    exit 1
    ;;
esac

curl -fsSL "https://downloads.raspberrypi.com/os_list_imagingutility_v4.json" -o "$MANIFEST_PATH"

IMAGE_URL="$(jq -r --arg name "$IMAGE_NAME_FILTER" '.. | objects | select(.name? == $name) | .url' "$MANIFEST_PATH")"

if [[ -z "$IMAGE_URL" || "$IMAGE_URL" == "null" ]]; then
  echo "Failed to resolve $IMAGE_NAME_FILTER from official manifest." >&2
  exit 1
fi

IMAGE_NAME="$(basename "$IMAGE_URL")"
IMAGE_PATH="$DOWNLOAD_DIR/$IMAGE_NAME"

if [[ ! -f "$IMAGE_PATH" ]]; then
  curl -fL "$IMAGE_URL" -o "$IMAGE_PATH"
fi

echo "$IMAGE_PATH"
