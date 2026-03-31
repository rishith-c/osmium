#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_PATH="${1:-$ROOT/build/images/osmium-rpi-os-bookworm-arm64-lite.img}"
DISK_ID="${2:-}"

if [[ -z "$DISK_ID" ]]; then
  echo "usage: $0 <image-path> <disk-id>" >&2
  echo "example: $0 $IMAGE_PATH disk4" >&2
  exit 1
fi

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "image not found: $IMAGE_PATH" >&2
  exit 1
fi

echo "About to erase and write $IMAGE_PATH to /dev/$DISK_ID"
diskutil info "/dev/$DISK_ID"
diskutil unmountDisk "/dev/$DISK_ID"
sudo dd if="$IMAGE_PATH" of="/dev/r${DISK_ID}" bs=8m status=progress
sync
diskutil eject "/dev/$DISK_ID"

