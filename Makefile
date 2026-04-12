# =============================================================================
# Makefile - Dual-State OS Build System
# =============================================================================
#   make          Build os-image.bin
#   make run      Build and run in QEMU
#   make debug    Build and run with GDB server on :1234
#   make clean    Remove all build artifacts
# =============================================================================

# ---------------------------------------------------------------------------
# Toolchain (auto-detect cross-compiler)
# ---------------------------------------------------------------------------
CROSS_PREFIX ?= $(shell \
    if command -v x86_64-elf-gcc >/dev/null 2>&1; then echo "x86_64-elf-"; \
    elif command -v i686-elf-gcc >/dev/null 2>&1; then echo "i686-elf-"; \
    else echo ""; fi)

CC      = $(CROSS_PREFIX)gcc
LD      = $(CROSS_PREFIX)ld
OBJCOPY = $(CROSS_PREFIX)objcopy
AS      = nasm

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
CFLAGS  = -m32 -ffreestanding -fno-pie -fno-stack-protector \
          -nostdlib -nostdinc -fno-builtin \
          -Wall -Wextra -Wno-unused-parameter \
          -Idrivers -Icore -Ikernel

LDFLAGS = -m elf_i386 -T linker.ld

ASFLAGS_BIN = -f bin
ASFLAGS_ELF = -f elf32

# ---------------------------------------------------------------------------
# Directories and Files
# ---------------------------------------------------------------------------
BUILD_DIR = build

BOOT_SRC = boot/boot.asm
BOOT_BIN = $(BUILD_DIR)/boot.bin

# Assembly objects
ASM_OBJECTS = $(BUILD_DIR)/kernel_entry.o \
              $(BUILD_DIR)/isr_stubs.o

# C objects
C_OBJECTS = $(BUILD_DIR)/kernel.o \
            $(BUILD_DIR)/screen.o \
            $(BUILD_DIR)/keyboard.o \
            $(BUILD_DIR)/timer.o \
            $(BUILD_DIR)/rtc.o \
            $(BUILD_DIR)/memory.o \
            $(BUILD_DIR)/string.o \
            $(BUILD_DIR)/idt.o \
            $(BUILD_DIR)/isr.o \
            $(BUILD_DIR)/state_manager.o \
            $(BUILD_DIR)/shell.o \
            $(BUILD_DIR)/calc.o \
            $(BUILD_DIR)/pyshell.o

# Final outputs
KERNEL_ELF = $(BUILD_DIR)/kernel.elf
KERNEL_BIN = $(BUILD_DIR)/kernel.bin
OS_IMAGE   = $(BUILD_DIR)/os-image.bin

# QEMU
QEMU = qemu-system-x86_64
QEMU_FLAGS = -drive format=raw,file=$(OS_IMAGE) -no-reboot -no-shutdown

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------
.PHONY: all run debug clean dirs

all: dirs $(OS_IMAGE)
	@echo ""
	@echo "=========================================="
	@echo "  Build complete: $(OS_IMAGE)"
	@echo "  Run with: make run"
	@echo "=========================================="

dirs:
	@mkdir -p $(BUILD_DIR)

# --- Boot sector ---
$(BOOT_BIN): $(BOOT_SRC) | dirs
	@echo "[ASM ] $<"
	$(AS) $(ASFLAGS_BIN) $< -o $@

# --- Assembly objects ---
$(BUILD_DIR)/kernel_entry.o: kernel/kernel_entry.asm | dirs
	@echo "[ASM ] $<"
	$(AS) $(ASFLAGS_ELF) $< -o $@

$(BUILD_DIR)/isr_stubs.o: core/isr_stubs.asm | dirs
	@echo "[ASM ] $<"
	$(AS) $(ASFLAGS_ELF) $< -o $@

# --- C objects ---
$(BUILD_DIR)/kernel.o: kernel/kernel.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/screen.o: drivers/screen.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/keyboard.o: drivers/keyboard.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/timer.o: drivers/timer.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/rtc.o: drivers/rtc.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/memory.o: core/memory.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/string.o: core/string.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/idt.o: core/idt.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/isr.o: core/isr.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/state_manager.o: core/state_manager.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/shell.o: core/shell.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/calc.o: core/calc.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/pyshell.o: core/pyshell.c | dirs
	@echo "[CC  ] $<"
	$(CC) $(CFLAGS) -c $< -o $@

# --- Link kernel (kernel_entry.o MUST be first) ---
$(KERNEL_ELF): $(ASM_OBJECTS) $(C_OBJECTS) linker.ld | dirs
	@echo "[LINK] -> $@"
	$(LD) $(LDFLAGS) -o $@ $(BUILD_DIR)/kernel_entry.o $(BUILD_DIR)/isr_stubs.o $(C_OBJECTS)

# --- Convert ELF to raw binary ---
$(KERNEL_BIN): $(KERNEL_ELF) | dirs
	@echo "[BIN ] $< -> $@"
	$(OBJCOPY) -O binary $< $@

# --- Create bootable image (padded to 32KB) ---
$(OS_IMAGE): $(BOOT_BIN) $(KERNEL_BIN) | dirs
	@echo "[IMG ] Creating OS image..."
	cat $(BOOT_BIN) $(KERNEL_BIN) > $@
	@# Pad to 49 sectors (1 boot + 48 kernel) = 25088 bytes minimum
	dd if=/dev/zero bs=1 count=$$((25088 - $$(wc -c < $@))) >> $@ 2>/dev/null || true
	@echo "[IMG ] Image size: $$(wc -c < $@) bytes"

# --- Run ---
run: all
	@echo "[QEMU] Launching..."
	$(QEMU) $(QEMU_FLAGS)

# --- Debug ---
debug: all
	@echo "[QEMU] Launching with GDB on :1234..."
	$(QEMU) $(QEMU_FLAGS) -s -S

# --- Clean ---
clean:
	rm -rf $(BUILD_DIR)
