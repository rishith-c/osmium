# Osmium

Osmium is now a raw AArch64 assembly firmware project for Raspberry Pi 4. There is no Rust, no Cargo, and no language runtime in the source tree. The firmware boots directly into a UART shell and keeps the command surface intentionally small.

## What it has

- Pure assembly source in `firmware/osmium.S`
- Direct Raspberry Pi 4 MMIO for UART and timer
- UART shell with mac-style command names:
  `help`, `clear`, `pwd`, `cd`, `ls`, `cat`, `echo`, `uname`, `date`, `weather`, `mkdir`, `touch`, `write`, `python`
- RAM-backed filesystem with writable directories and files
- Timer-backed Unix seconds counter
- Cached weather file at `/etc/weather.txt`
- Tiny `python` REPL for integer expressions and `print("text")`

## What it does not have

- Full macOS/BSD semantics
- Persistent disk drivers
- Live networking
- Full Python / CPython
- Desktop boot support

Those are separate milestones. This repo now matches the "raw boot assembly firmware" requirement, but it is still a small OS prototype, not a clone of macOS.

## Build

```bash
./scripts/build-kernel.sh
```

This assembles and links the firmware directly and emits:

- `build/boot/kernel8.img`
- `build/boot/config.txt`
- `build/obj/osmium.elf`

## Boot on Raspberry Pi 4

1. Format the Pi boot partition as `FAT32`.
2. Copy `build/boot/kernel8.img` and `build/boot/config.txt` onto it.
3. Copy Raspberry Pi firmware files onto the same partition. At minimum:
   `start4.elf`, `fixup4.dat`, and `bcm2711-rpi-4-b.dtb`.
4. Attach a serial adapter to the Pi UART.
5. Open serial at `115200 8N1`.
6. Power on the Pi.

If you already have a mounted boot volume and a local firmware directory:

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
date +%s
date set 1774828800
weather
weather set San Francisco: 64F, fog
python
```

## Source layout

- `firmware/osmium.S`: boot path, UART, shell, filesystem, date, weather, python REPL
- `linker.ld`: image layout and boot stack
- `scripts/build-kernel.sh`: assembly-only build
- `scripts/stage-sd-card.sh`: copy helper for a mounted Pi boot volume
