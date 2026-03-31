# Osmium

Osmium is a from-scratch Raspberry Pi bare-metal operating system prototype written in Rust. It currently targets Raspberry Pi 4 in 64-bit mode and boots into a UART shell with familiar macOS command names such as `ls`, `cd`, `cat`, `pwd`, `echo`, `uname`, and `date`.

## What it has

- A real AArch64 kernel entrypoint that builds to `kernel8.img`
- UART console and shell
- In-memory filesystem with directories and writable files
- `date` backed by the ARM architectural timer
- Cached `weather` app stored in `/etc/weather.txt`
- Tiny `python` app (`OsmiumPy`) for integer math, variables, and `print(expr)`

## What it does not have yet

- Full macOS/BSD command compatibility
- Persistent storage drivers
- Networking, so `weather` is cached/manual rather than live
- Full CPython
- A bundled Raspberry Pi firmware set

Those gaps are fundamental scope issues, not oversights. A bootable hobby OS and a production macOS-compatible Unix are different projects.

## Build

```bash
./scripts/build-kernel.sh
```

This emits:

- `build/boot/kernel8.img`
- `build/boot/config.txt`

## Boot on Raspberry Pi 4

1. Format an SD card boot partition as FAT32.
2. Copy the files from `build/boot/` onto that partition.
3. Copy the Raspberry Pi firmware files onto the same partition. At minimum, `start4.elf`, `fixup4.dat`, and `bcm2711-rpi-4-b.dtb` should be present.
4. Connect a serial adapter to the Pi UART and open it at `115200 8N1`.
5. Power on the board and interact with the shell over serial.

If you already have a mounted FAT boot volume and a local Raspberry Pi firmware directory, you can use:

```bash
./scripts/stage-sd-card.sh /path/to/rpi-firmware /Volumes/BOOT
```

## Shell quick start

```text
help
ls
cat /etc/motd
mkdir /home/projects
touch /home/projects/todo.txt
write /home/projects/todo.txt ship it
date
date set 1774828800
weather
weather set San Francisco: 64F, fog
python
```

## Notes

- The shell intentionally mirrors command names from macOS first. Exact BSD semantics are a later milestone.
- The system uses a fixed in-memory filesystem for now, so files reset on reboot.
