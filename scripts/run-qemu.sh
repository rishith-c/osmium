#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
IMAGE_DIR="$BUILD_DIR/images"
QEMU_BOOT_DIR="$BUILD_DIR/qemu-boot"
SERIAL_LOG="$BUILD_DIR/qemu-serial.log"

MODE="headless"
IMAGE_PATH=""

usage() {
  cat <<'EOF'
Usage: ./scripts/run-qemu.sh [--window|--headless] [image-path]

Boot the built Raspberry Pi OS image with QEMU's raspi4b machine.

Options:
  --window     Try to open a QEMU window with USB keyboard/mouse attached
  --headless   Run with serial console in the terminal (default)

If no image path is provided, the script uses the newest
build/images/osmium-rpi-os-bookworm-arm64-*.img file.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --window)
      MODE="window"
      shift
      ;;
    --headless)
      MODE="headless"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      IMAGE_PATH="$1"
      shift
      ;;
  esac
done

if [[ -z "$IMAGE_PATH" ]]; then
  IMAGE_PATH="$(ls -t "$IMAGE_DIR"/osmium-rpi-os-bookworm-arm64-*.img 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$IMAGE_PATH" || ! -f "$IMAGE_PATH" ]]; then
  echo "No built Osmium image found." >&2
  echo "Build one first with ./scripts/build-image.sh" >&2
  exit 1
fi

if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
  echo "qemu-system-aarch64 is not installed." >&2
  echo "Install it with: brew install qemu" >&2
  exit 1
fi

mkdir -p "$QEMU_BOOT_DIR"

ATTACH_OUTPUT="$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount "$IMAGE_PATH")"
ATTACHED_DISK="$(awk '/^\/dev\/disk/{print $1; exit}' <<<"$ATTACH_OUTPUT")"
ATTACHED_BOOT_DEV="$(awk '/^\/dev\/disk.*s1/{print $1; exit}' <<<"$ATTACH_OUTPUT")"

if [[ -z "$ATTACHED_DISK" ]]; then
  echo "Failed to attach image: $IMAGE_PATH" >&2
  exit 1
fi

if [[ -z "$ATTACHED_BOOT_DEV" ]]; then
  ATTACHED_BOOT_DEV="${ATTACHED_DISK}s1"
fi

cleanup() {
  set +e
  if [[ -n "${ATTACHED_BOOT_DEV:-}" ]]; then
    diskutil unmount "$ATTACHED_BOOT_DEV" >/dev/null 2>&1 || true
  fi
  if [[ -n "${ATTACHED_DISK:-}" ]]; then
    hdiutil detach "$ATTACHED_DISK" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

diskutil mount "$ATTACHED_BOOT_DEV" >/dev/null
BOOT_MOUNT="$(diskutil info "$ATTACHED_BOOT_DEV" | awk -F': *' '/Mount Point/{print $2}')"

for path in kernel8.img initramfs8 bcm2711-rpi-4-b.dtb cmdline.txt; do
  cp "$BOOT_MOUNT/$path" "$QEMU_BOOT_DIR/$path"
done

cleanup
trap - EXIT

CMDLINE="$(tr -d '\n' < "$QEMU_BOOT_DIR/cmdline.txt" \
  | sed 's/console=serial0,115200/console=ttyAMA0,115200/' \
  | sed 's/ quiet//g' \
  | sed 's/ splash//g')"
CMDLINE="$CMDLINE earlycon=pl011,mmio32,0xfe201000 ignore_loglevel loglevel=8"

COMMON_ARGS=(
  -M raspi4b
  -cpu cortex-a72
  -m 2G
  -kernel "$QEMU_BOOT_DIR/kernel8.img"
  -dtb "$QEMU_BOOT_DIR/bcm2711-rpi-4-b.dtb"
  -initrd "$QEMU_BOOT_DIR/initramfs8"
  -drive "file=$IMAGE_PATH,if=sd,format=raw"
  -append "$CMDLINE"
)

if [[ "$MODE" == "window" ]]; then
  rm -f "$SERIAL_LOG"
  echo "Launching QEMU window. Serial log: $SERIAL_LOG"
  exec qemu-system-aarch64 \
    "${COMMON_ARGS[@]}" \
    -serial "file:$SERIAL_LOG" \
    -usb \
    -device usb-kbd \
    -device usb-mouse
fi

echo "Launching QEMU headless serial console."
exec qemu-system-aarch64 \
  "${COMMON_ARGS[@]}" \
  -serial mon:stdio \
  -display none \
  -monitor none
