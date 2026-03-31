# Osmium

Osmium now targets Raspberry Pi OS compatibility directly. Instead of a custom raw firmware kernel, this repo builds a customized Raspberry Pi OS Bookworm Lite (64-bit) image for Raspberry Pi hardware, so standard Raspberry Pi OS / Debian arm64 packages and software continue to work.

## What it builds

- Base OS: official Raspberry Pi OS (Legacy / Bookworm, 64-bit, Lite)
- Output: a bootable `.img` file for Raspberry Pi
- Customization method: macOS-side boot partition injection plus Raspberry Pi first-boot provisioning
- Result: a stock-compatible Raspberry Pi OS image with:
  - custom hostname and user
  - SSH enabled
  - Python, pip, git, curl, vim, htop, build-essential
  - `python` symlinked to `python3`
  - a simple `weather` command
  - Osmium branding files under `/etc`

## Why Bookworm Lite

The latest Raspberry Pi OS Trixie images use a newer `cloudinit-rpi` customization path. For local macOS image customization, Bookworm Lite is the simpler stable target because the official image manifest marks it as `init_format=systemd`, which allows a `firstrun.sh` boot-partition workflow.

## Quick start

1. Optional: copy the config template and edit it.

```bash
cd /Users/rishith/Developer/osmium
cp config/osmium.env.example config/osmium.env
```

2. Build the customized Raspberry Pi OS image.

```bash
./scripts/build-image.sh
```

This downloads the official base image, verifies its SHA-256, customizes it, and writes:

- `build/images/osmium-rpi-os-bookworm-arm64-lite.img`

3. Flash the image to an SD card.

```bash
./scripts/flash-image.sh build/images/osmium-rpi-os-bookworm-arm64-lite.img disk4
```

Replace `disk4` with the correct removable disk from `diskutil list`.

## Configuration

Default settings live in:

- `config/osmium.env.example`

Supported options:

- `OSMIUM_HOSTNAME`
- `OSMIUM_USERNAME`
- `OSMIUM_PASSWORD`
- `OSMIUM_TIMEZONE`
- `OSMIUM_LOCALE`
- `OSMIUM_PACKAGES`
- `OSMIUM_WIFI_SSID`
- `OSMIUM_WIFI_PSK`
- `OSMIUM_WIFI_COUNTRY`

Change `OSMIUM_PASSWORD` before flashing an image you plan to put on a real network.

## Project layout

- `scripts/download-base-image.sh`: resolves and downloads the official Raspberry Pi OS Bookworm Lite arm64 image from the official manifest
- `scripts/build-image.sh`: verifies, customizes, and emits the final bootable image
- `scripts/flash-image.sh`: writes the generated image to an SD card on macOS
- `overlay/rootfs/`: files unpacked onto the Pi root filesystem during first boot
- `config/osmium.env.example`: editable build configuration

## Notes

- This project is now designed for compatibility with Raspberry Pi OS software, not for custom-kernel experimentation.
- The first boot performs package installation. Networking should be available if you want the package set installed immediately.
- The generated image remains a Raspberry Pi OS / Debian arm64 system, so `apt` packages and standard Linux software continue to work.
