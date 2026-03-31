# Osmium

Osmium now targets Raspberry Pi OS compatibility directly. Instead of a custom raw firmware kernel, this repo builds a customized Raspberry Pi OS Bookworm (64-bit) image for Raspberry Pi hardware, so standard Raspberry Pi OS / Debian arm64 packages and software continue to work. The default target is the Full desktop image, so you get the normal graphical Raspberry Pi desktop, file manager, terminal, browser, and application stack.

## What it builds

- Base OS: official Raspberry Pi OS (Legacy / Bookworm, 64-bit), defaulting to the Full desktop image
- Output: a bootable `.img` file for Raspberry Pi
- Customization method: macOS-side boot partition injection plus Raspberry Pi first-boot provisioning
- Result: a stock-compatible Raspberry Pi OS image with:
  - full desktop UI by default
  - browser, desktop shell, folders, terminal, and normal Raspberry Pi OS desktop apps
  - desktop login screen support
  - custom hostname and user
  - SSH enabled
  - Python, pip, git, curl, vim, htop, build-essential
  - `python` symlinked to `python3`
  - a simple `weather` command
  - Osmium branding files under `/etc`

## Why Bookworm

The latest Raspberry Pi OS Trixie images use a newer `cloudinit-rpi` customization path. For local macOS image customization, Bookworm is the simpler stable target because the official image manifest marks the legacy Bookworm images as `init_format=systemd`, which allows a `firstrun.sh` boot-partition workflow. The default Osmium profile now uses the Full desktop Bookworm image; you can switch to Lite in config if you want a smaller headless image.

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

This downloads the official base image, verifies its SHA-256, customizes it, and writes a desktop-ready image such as:

- `build/images/osmium-rpi-os-bookworm-arm64-full.img`

3. Flash the image to an SD card.

```bash
./scripts/flash-image.sh build/images/osmium-rpi-os-bookworm-arm64-full.img disk4
```

Replace `disk4` with the correct removable disk from `diskutil list`.

## Run In QEMU On macOS

You can also try booting the built image under QEMU's Raspberry Pi 4 model on a Mac:

```bash
bash ./scripts/run-qemu.sh --headless
```

That path is verified to boot the Raspberry Pi kernel and print serial logs in the terminal.

To try a windowed run instead:

```bash
bash ./scripts/run-qemu.sh --window
```

QEMU's `raspi4b` emulation is still incomplete, so a full Raspberry Pi OS desktop session is not guaranteed under emulation even though the kernel starts. Real hardware remains the reliable target for the full desktop experience.

## Configuration

Default settings live in:

- `config/osmium.env.example`

Supported options:

- `OSMIUM_HOSTNAME`
- `OSMIUM_BASE_PROFILE`
- `OSMIUM_CREATE_DEFAULT_USER`
- `OSMIUM_USERNAME`
- `OSMIUM_PASSWORD`
- `OSMIUM_ENABLE_DESKTOP_LOGIN`
- `OSMIUM_TIMEZONE`
- `OSMIUM_LOCALE`
- `OSMIUM_PACKAGES`
- `OSMIUM_WIFI_SSID`
- `OSMIUM_WIFI_PSK`
- `OSMIUM_WIFI_COUNTRY`

If `OSMIUM_CREATE_DEFAULT_USER=false`, Osmium preserves the normal first-boot account-creation flow instead of pre-seeding a user. Use that if you want a more stock desktop setup experience.

Change `OSMIUM_PASSWORD` before flashing an image you plan to put on a real network if you enable default-user creation.

## Project layout

- `scripts/download-base-image.sh`: resolves and downloads the official Raspberry Pi OS Bookworm arm64 image from the official manifest
- `scripts/build-image.sh`: verifies, customizes, and emits the final bootable image
- `scripts/flash-image.sh`: writes the generated image to an SD card on macOS
- `overlay/rootfs/`: files unpacked onto the Pi root filesystem during first boot
- `config/osmium.env.example`: editable build configuration

## Notes

- This project is now designed for compatibility with Raspberry Pi OS software, not for custom-kernel experimentation.
- The first boot performs package installation. Networking should be available if you want the package set installed immediately.
- The default profile is large: the official Full desktop image is roughly 3.4 GB compressed and 16 GB extracted.
- The generated image remains a Raspberry Pi OS / Debian arm64 system, so `apt` packages and standard Linux software continue to work.
