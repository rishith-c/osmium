#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <raspberry-pi-firmware-dir> <mounted-fat-boot-volume>"
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRMWARE_DIR="$1"
BOOT_VOLUME="$2"

"$ROOT/scripts/build-kernel.sh"

cp "$ROOT/build/boot/kernel8.img" "$BOOT_VOLUME/kernel8.img"
cp "$ROOT/build/boot/config.txt" "$BOOT_VOLUME/config.txt"

for file in start4.elf fixup4.dat bootcode.bin bcm2711-rpi-4-b.dtb; do
  if [[ -f "$FIRMWARE_DIR/$file" ]]; then
    cp "$FIRMWARE_DIR/$file" "$BOOT_VOLUME/$file"
  fi
done

echo "Boot volume updated at $BOOT_VOLUME"

