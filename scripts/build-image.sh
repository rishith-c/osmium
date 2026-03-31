#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DOWNLOAD_DIR="$BUILD_DIR/downloads"
IMAGE_DIR="$BUILD_DIR/images"
WORK_DIR="$BUILD_DIR/work"
OVERLAY_DIR="$ROOT/overlay/rootfs"
CONFIG_FILE="$ROOT/config/osmium.env"
MANIFEST_PATH="$DOWNLOAD_DIR/os_list_imagingutility_v4.json"
OUTPUT_IMAGE="$IMAGE_DIR/osmium-rpi-os-bookworm-arm64-lite.img"
BOOT_APPEND=" systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target"

mkdir -p "$DOWNLOAD_DIR" "$IMAGE_DIR" "$WORK_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

OSMIUM_HOSTNAME="${OSMIUM_HOSTNAME:-osmium}"
OSMIUM_BASE_PROFILE="${OSMIUM_BASE_PROFILE:-full}"
OSMIUM_CREATE_DEFAULT_USER="${OSMIUM_CREATE_DEFAULT_USER:-false}"
OSMIUM_USERNAME="${OSMIUM_USERNAME:-osmium}"
OSMIUM_PASSWORD="${OSMIUM_PASSWORD:-osmium}"
OSMIUM_ENABLE_DESKTOP_LOGIN="${OSMIUM_ENABLE_DESKTOP_LOGIN:-true}"
OSMIUM_TIMEZONE="${OSMIUM_TIMEZONE:-America/Los_Angeles}"
OSMIUM_LOCALE="${OSMIUM_LOCALE:-en_US.UTF-8}"
OSMIUM_PACKAGES="${OSMIUM_PACKAGES:-python3 python3-pip git curl vim htop build-essential ca-certificates}"
OSMIUM_WIFI_SSID="${OSMIUM_WIFI_SSID:-}"
OSMIUM_WIFI_PSK="${OSMIUM_WIFI_PSK:-}"
OSMIUM_WIFI_COUNTRY="${OSMIUM_WIFI_COUNTRY:-US}"

case "$OSMIUM_BASE_PROFILE" in
  full)
    IMAGE_NAME_FILTER='Raspberry Pi OS (Legacy, 64-bit) Full'
    IMAGE_SLUG='bookworm-arm64-full'
    ;;
  lite)
    IMAGE_NAME_FILTER='Raspberry Pi OS (Legacy, 64-bit) Lite'
    IMAGE_SLUG='bookworm-arm64-lite'
    ;;
  *)
    echo "Unsupported OSMIUM_BASE_PROFILE: $OSMIUM_BASE_PROFILE" >&2
    echo "Use 'full' or 'lite'." >&2
    exit 1
    ;;
esac

OUTPUT_IMAGE="$IMAGE_DIR/osmium-rpi-os-$IMAGE_SLUG.img"
SOURCE_XZ="$("$ROOT/scripts/download-base-image.sh")"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Missing manifest at $MANIFEST_PATH" >&2
  exit 1
fi

SOURCE_IMG="$IMAGE_DIR/rpios-$IMAGE_SLUG-base.img"
EXPECTED_SHA="$(jq -r --arg name "$IMAGE_NAME_FILTER" '.. | objects | select(.name? == $name) | .extract_sha256' "$MANIFEST_PATH")"

if [[ ! -f "$SOURCE_IMG" ]]; then
  xz -dkc "$SOURCE_XZ" > "$SOURCE_IMG"
fi

ACTUAL_SHA="$(shasum -a 256 "$SOURCE_IMG" | awk '{print $1}')"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "Base image SHA256 mismatch." >&2
  echo "Expected: $EXPECTED_SHA" >&2
  echo "Actual:   $ACTUAL_SHA" >&2
  exit 1
fi

cp "$SOURCE_IMG" "$OUTPUT_IMAGE"

OVERLAY_TAR="$WORK_DIR/osmium-rootfs-overlay.tgz"
FIRSTRUN_SH="$WORK_DIR/firstrun.sh"
USERCONF_TXT="$WORK_DIR/userconf.txt"
WPA_CONF="$WORK_DIR/wpa_supplicant.conf"

tar -C "$OVERLAY_DIR" -czf "$OVERLAY_TAR" .

PASSWORD_HASH="$(openssl passwd -6 "$OSMIUM_PASSWORD")"
printf '%s:%s\n' "$OSMIUM_USERNAME" "$PASSWORD_HASH" > "$USERCONF_TXT"

cat > "$FIRSTRUN_SH" <<EOF
#!/bin/bash
set -euxo pipefail
exec > >(tee /boot/osmium-firstboot.log) 2>&1

cleanup() {
  rm -f /boot/firstrun.sh
  rm -f /boot/osmium-rootfs-overlay.tgz
  rm -f /boot/userconf.txt
  rm -f /boot/wpa_supplicant.conf
  sed -i 's| systemd.run.*||g' /boot/cmdline.txt
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive

TARGET_USER='${OSMIUM_USERNAME}'
TARGET_HASH='${PASSWORD_HASH}'
TARGET_HOSTNAME='${OSMIUM_HOSTNAME}'
TARGET_TIMEZONE='${OSMIUM_TIMEZONE}'
TARGET_LOCALE='${OSMIUM_LOCALE}'
TARGET_PACKAGES='${OSMIUM_PACKAGES}'
CREATE_DEFAULT_USER='${OSMIUM_CREATE_DEFAULT_USER}'
ENABLE_DESKTOP_LOGIN='${OSMIUM_ENABLE_DESKTOP_LOGIN}'

if [ "\$CREATE_DEFAULT_USER" = "true" ]; then
  if [ -x /usr/lib/userconf-pi/userconf ]; then
    /usr/lib/userconf-pi/userconf "\$TARGET_USER" "\$TARGET_HASH"
  elif ! id -u "\$TARGET_USER" >/dev/null 2>&1; then
    useradd -m -G users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo -s /bin/bash "\$TARGET_USER"
    echo "\$TARGET_USER:${OSMIUM_PASSWORD}" | chpasswd
  else
    echo "\$TARGET_USER:\$TARGET_HASH" | chpasswd -e
  fi
fi

echo "\$TARGET_HOSTNAME" >/etc/hostname
hostnamectl set-hostname "\$TARGET_HOSTNAME" || true

if grep -q '^127.0.1.1' /etc/hosts; then
  sed -i "s/^127.0.1.1.*/127.0.1.1\t\$TARGET_HOSTNAME/" /etc/hosts
else
  printf '127.0.1.1\t%s\n' "\$TARGET_HOSTNAME" >> /etc/hosts
fi

ln -fs /usr/share/zoneinfo/"\$TARGET_TIMEZONE" /etc/localtime || true
dpkg-reconfigure -f noninteractive tzdata || true
sed -i "s/^# *\$TARGET_LOCALE UTF-8/\$TARGET_LOCALE UTF-8/" /etc/locale.gen || true
locale-gen "\$TARGET_LOCALE" || true
update-locale LANG="\$TARGET_LOCALE" || true

systemctl enable ssh || true
touch /boot/ssh

if [ "\$ENABLE_DESKTOP_LOGIN" = "true" ] && [ -f /etc/lightdm/lightdm.conf ]; then
  sed -i '/^autologin-user=/d' /etc/lightdm/lightdm.conf || true
  sed -i '/^autologin-user-timeout=/d' /etc/lightdm/lightdm.conf || true
fi

if [ -f /boot/osmium-rootfs-overlay.tgz ]; then
  tar -xzf /boot/osmium-rootfs-overlay.tgz -C /
fi

chmod +x /usr/local/bin/weather || true
if command -v python3 >/dev/null 2>&1; then
  ln -sf /usr/bin/python3 /usr/local/bin/python
fi

if getent hosts archive.raspberrypi.com >/dev/null 2>&1 || getent hosts deb.debian.org >/dev/null 2>&1; then
  apt-get update
  apt-get install -y \$TARGET_PACKAGES
else
  echo "Network unavailable during first boot; skipping apt install"
fi

if command -v python3 >/dev/null 2>&1; then
  ln -sf /usr/bin/python3 /usr/local/bin/python
fi

sync
EOF

chmod +x "$FIRSTRUN_SH"

if [[ -n "$OSMIUM_WIFI_SSID" && -n "$OSMIUM_WIFI_PSK" ]]; then
  cat > "$WPA_CONF" <<EOF
country=${OSMIUM_WIFI_COUNTRY}
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
  ssid="${OSMIUM_WIFI_SSID}"
  psk="${OSMIUM_WIFI_PSK}"
}
EOF
fi

ATTACHED_DISK=""
ATTACHED_BOOT_DEV=""
BOOT_MOUNT=""

cleanup_host() {
  set +e
  if [[ -n "$ATTACHED_BOOT_DEV" ]]; then
    diskutil unmount "$ATTACHED_BOOT_DEV" >/dev/null 2>&1 || true
  fi
  if [[ -n "$ATTACHED_DISK" ]]; then
    hdiutil detach "$ATTACHED_DISK" >/dev/null 2>&1 || true
  fi
}
trap cleanup_host EXIT

ATTACH_OUTPUT="$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount "$OUTPUT_IMAGE")"
ATTACHED_DISK="$(awk '/^\/dev\/disk/{print $1; exit}' <<<"$ATTACH_OUTPUT")"
ATTACHED_BOOT_DEV="$(awk '/^\/dev\/disk.*s1/{print $1; exit}' <<<"$ATTACH_OUTPUT")"

if [[ -z "$ATTACHED_DISK" ]]; then
  echo "Failed to attach image: $OUTPUT_IMAGE" >&2
  exit 1
fi

if [[ -z "$ATTACHED_BOOT_DEV" ]]; then
  ATTACHED_BOOT_DEV="${ATTACHED_DISK}s1"
fi

diskutil mount "$ATTACHED_BOOT_DEV" >/dev/null
BOOT_MOUNT="$(diskutil info "$ATTACHED_BOOT_DEV" | awk -F': *' '/Mount Point/{print $2}')"

if [[ -z "$BOOT_MOUNT" || ! -d "$BOOT_MOUNT" ]]; then
  echo "Failed to mount boot partition from $OUTPUT_IMAGE" >&2
  exit 1
fi

cp "$FIRSTRUN_SH" "$BOOT_MOUNT/firstrun.sh"
cp "$OVERLAY_TAR" "$BOOT_MOUNT/osmium-rootfs-overlay.tgz"
if [[ "$OSMIUM_CREATE_DEFAULT_USER" == "true" ]]; then
  cp "$USERCONF_TXT" "$BOOT_MOUNT/userconf.txt"
fi
touch "$BOOT_MOUNT/ssh"

if [[ -f "$WPA_CONF" ]]; then
  cp "$WPA_CONF" "$BOOT_MOUNT/wpa_supplicant.conf"
fi

CMDLINE_PATH="$BOOT_MOUNT/cmdline.txt"
CMDLINE_CONTENT="$(tr -d '\n' < "$CMDLINE_PATH")"
if [[ "$CMDLINE_CONTENT" != *"systemd.run=/boot/firstrun.sh"* ]]; then
  printf '%s%s\n' "$CMDLINE_CONTENT" "$BOOT_APPEND" > "$CMDLINE_PATH"
fi

sync
cleanup_host
trap - EXIT

echo "Built customized image: $OUTPUT_IMAGE"
