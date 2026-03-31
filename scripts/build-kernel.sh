#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/lib/rustlib/aarch64-apple-darwin/bin"
BOOT_DIR="$ROOT/build/boot"
OBJ_DIR="$ROOT/build/obj"
ELF_PATH="$OBJ_DIR/osmium.elf"
OBJ_PATH="$OBJ_DIR/osmium.o"

mkdir -p "$BOOT_DIR" "$OBJ_DIR"
clang --target=aarch64-none-elf -c "$ROOT/firmware/osmium.S" -o "$OBJ_PATH"
"$TOOLCHAIN/gcc-ld/ld.lld" -T "$ROOT/linker.ld" -o "$ELF_PATH" "$OBJ_PATH"
mkdir -p "$BOOT_DIR"
"$TOOLCHAIN/llvm-objcopy" -O binary "$ELF_PATH" "$BOOT_DIR/kernel8.img"
cp "$ROOT/boot/config.txt" "$BOOT_DIR/config.txt"

printf 'Built %s\n' "$BOOT_DIR/kernel8.img"
