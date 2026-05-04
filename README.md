# Osmium

A bootable x86 operating system written in C and Assembly. It boots from a raw disk image into 32-bit protected mode, runs an interactive shell with a calculator and a Python-like REPL, and operates in two modes: Safe and Creator.

## What it does

Osmium is a bare-metal OS that boots on real x86 hardware (or QEMU). When you power it on, a 512-byte bootloader loads the kernel from disk, enables the A20 address line, sets up the Global Descriptor Table for protected mode, and jumps to the kernel entry point. The kernel initializes the Interrupt Descriptor Table, remaps the PIC, sets up the PIT timer at 100 Hz, enables the PS/2 keyboard driver, reads the RTC for date and time, and launches an interactive shell.

The shell supports a set of built-in commands: `help`, `clear`, `info`, `time`, `uptime`, `echo`, `calc`, `python`, `history`, `color`, `toggle`, `reboot`, and `halt`. If you type something that is not a command, the shell tries to evaluate it as an arithmetic expression. The `calc` command opens a dedicated calculator mode with a recursive descent parser that handles integers, parentheses, and the standard operators. The `python` command opens a mini Python-like REPL that supports `print()`, single-letter variables (a through z), and arithmetic expressions.

## How the dual-mode architecture works

The OS has two operating modes: Safe Mode and Creator Mode. It boots into Safe Mode by default. You can switch between them with the `toggle` command. The shell prompt changes to reflect the current mode (`[SAFE]>` or `[CREATOR]>`), and certain features like `color` (which changes the VGA text color) are only available in Creator Mode.

This dual-mode design is the foundation for a permission system. Safe Mode is meant to be restrictive. Creator Mode grants access to configuration and customization. The state manager is designed with transition logging and hooks for future authentication and permission flushing on mode changes.

## How the boot process works

The boot sequence is a textbook x86 real-to-protected-mode transition, fully commented in the source:

1. The BIOS loads the 512-byte boot sector from disk to address 0x7C00.
2. The bootloader sets up segment registers, saves the boot drive number, and loads 48 sectors of kernel binary from disk into memory at 0x1000 using BIOS interrupt 0x13.
3. It enables the A20 line using the fast method (I/O port 0x92) so the CPU can address memory beyond 1 MB.
4. It loads a flat-model GDT with code and data segments spanning the full 4 GB address space.
5. It sets the Protection Enable bit in CR0 and does a far jump to flush the pipeline and enter 32-bit protected mode.
6. In protected mode, it sets up all segment registers, creates a stack at 0x90000, and calls the kernel entry point.

## How interrupts work

The kernel sets up a 256-entry IDT with handlers for CPU exceptions (vectors 0 through 31) and hardware IRQs (vectors 32 through 47). The PIC is remapped so IRQs do not collide with CPU exception vectors. ISR stubs are written in NASM assembly to save registers, call C handlers, and restore state. The PIT timer fires at 100 Hz to track uptime. The keyboard driver processes PS/2 scancodes with a US QWERTY layout and provides a blocking `keyboard_getchar()` interface.

## Quickstart

### Prerequisites

- **NASM** (assembler for boot sector and ISR stubs)
- **GCC cross-compiler** for i386 (either `x86_64-elf-gcc` or `i686-elf-gcc`). On macOS, install via Homebrew: `brew install x86_64-elf-gcc`
- **QEMU** for emulation: `brew install qemu`
- **make**

If you do not have a cross-compiler, the Makefile will fall back to the system GCC, but a proper cross-compiler is recommended for correct freestanding compilation.

### Build and run

```bash
git clone https://github.com/yourusername/osmium.git
cd osmium

# Build the OS image
make

# Run in QEMU
make run

# Or run with GDB debugging on port 1234
make debug
```

The build produces `build/os-image.bin`, a raw bootable disk image. QEMU loads it directly. The image is padded to 25,088 bytes (1 boot sector + 48 kernel sectors).

### Clean

```bash
make clean
```

## Project structure

```
osmium/
  boot/
    boot.asm             16-bit bootloader: disk load, GDT, A20, mode switch
  kernel/
    kernel_entry.asm     32-bit entry stub that calls kernel_main()
    kernel.c             Kernel init sequence: IDT, timer, keyboard, shell
    kernel.h             Version string and kernel constants
  core/
    idt.c / idt.h        Interrupt Descriptor Table setup and PIC remapping
    isr.c / isr.h        C-side interrupt service routines
    isr_stubs.asm        NASM ISR stubs (save/restore, call C handler)
    shell.c / shell.h    Interactive command shell with history
    calc.c / calc.h      Recursive descent calculator (integer arithmetic)
    pyshell.c / pyshell.h  Python-like REPL (print, variables, expressions)
    state_manager.c / .h   Dual-mode state machine (Safe vs Creator)
    memory.c / memory.h    memset, memcpy (freestanding, no libc)
    string.c / string.h    strlen, strcmp, strncpy, itoa, atoi (freestanding)
  drivers/
    screen.c / screen.h    VGA text mode driver (0xB8000), cursor control
    keyboard.c / .h        PS/2 keyboard driver, scancode-to-ASCII, getchar
    timer.c / timer.h      PIT timer driver, 100 Hz tick, uptime tracking
    rtc.c / rtc.h          CMOS RTC reader for date and time
    ports.h                x86 I/O port inline assembly (inb, outb)
  linker.ld              Kernel layout: .text at 0x1000, .rodata, .data, .bss
  Makefile               Build system with auto-detected cross-compiler
```

## Screenshots / Demo

<!-- Add screenshot: QEMU window showing the boot banner, initialization sequence with green OK markers, and the [SAFE]> shell prompt -->

<!-- Add screenshot: the shell running the info command, showing system information including arch, VGA mode, timer frequency, and uptime -->

<!-- Add screenshot: the calculator mode evaluating arithmetic expressions -->

<!-- Add screenshot: the Python REPL with variable assignment and print statements -->

## What is not here (and why)

- **No filesystem.** The kernel runs entirely in memory. Adding a FAT12/16 driver is the natural next step.
- **No paging.** Memory protection uses the flat-model GDT with segmentation effectively disabled. Paging would be needed for process isolation.
- **No multitasking.** The shell runs in a single-threaded loop. A task scheduler would require a TSS and context switching.
- **No dynamic memory allocation.** There is no heap. All data is stack-allocated or global. A bump allocator or free-list allocator would be needed for dynamic allocation.
- **No floating point.** All arithmetic is integer. Enabling the FPU would require saving/restoring FPU state on context switches.

These are all standard next steps for an educational OS project. The current codebase is a clean foundation for any of them.

## License

MIT. See [LICENSE](LICENSE).
