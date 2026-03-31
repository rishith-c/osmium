#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/lib/rustlib/aarch64-apple-darwin/bin"
TARGET="aarch64-unknown-none-softfloat"
ELF_PATH="$ROOT/target/$TARGET/release/osmium"
BOOT_DIR="$ROOT/build/boot"

export CARGO_TARGET_AARCH64_UNKNOWN_NONE_SOFTFLOAT_LINKER="$TOOLCHAIN/rust-lld"
export RUSTFLAGS="-C link-arg=-T$ROOT/linker.ld -C link-arg=--gc-sections"

cargo build --release --target "$TARGET" --manifest-path "$ROOT/Cargo.toml"

mkdir -p "$BOOT_DIR"
"$TOOLCHAIN/llvm-objcopy" -O binary "$ELF_PATH" "$BOOT_DIR/kernel8.img"
cp "$ROOT/boot/config.txt" "$BOOT_DIR/config.txt"

printf 'Built %s\n' "$BOOT_DIR/kernel8.img"

