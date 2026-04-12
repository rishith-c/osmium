/* ===========================================================================
 * kernel.c - Dual-State OS Kernel
 * ===========================================================================
 * Main entry point. Initializes all subsystems and launches the shell.
 *
 * Boot sequence:
 *   1. Clear screen, print banner
 *   2. Initialize IDT (Interrupt Descriptor Table)
 *   3. Initialize PIT timer (100 Hz)
 *   4. Initialize keyboard driver
 *   5. Initialize state manager
 *   6. Read and display RTC time
 *   7. Launch interactive shell
 * =========================================================================== */

#include "kernel.h"
#include "screen.h"
#include "idt.h"
#include "timer.h"
#include "keyboard.h"
#include "state_manager.h"
#include "rtc.h"
#include "shell.h"

/* ---------------------------------------------------------------------------
 * print_banner - Display the boot banner
 * --------------------------------------------------------------------------- */
static void print_banner(void)
{
    print_string_color(
        "============================================================\n",
        MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));
    print_string_color(
        "  Dual-State OS v" KERNEL_VERSION_STRING
        "                                \n",
        MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string_color(
        "  A minimal OS with dual-mode architecture                  \n",
        MAKE_COLOR(COLOR_LIGHT_GREY, COLOR_BLACK));
    print_string_color(
        "============================================================\n",
        MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));
    print_string("\n");
}

/* ---------------------------------------------------------------------------
 * kernel_main - Kernel entry point
 * --------------------------------------------------------------------------- */
void kernel_main(void)
{
    /* Phase 1: Screen */
    screen_clear();
    print_banner();

    /* Phase 2: Interrupts */
    print_string("[KERN] Initializing IDT...\n");
    idt_init();
    print_string_color("[  OK  ] ", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
    print_string("IDT loaded, interrupts enabled\n");

    /* Phase 3: Timer */
    print_string("[KERN] Initializing timer...\n");
    timer_init(100);
    print_string_color("[  OK  ] ", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
    print_string("PIT running at 100 Hz\n");

    /* Phase 4: Keyboard */
    print_string("[KERN] Initializing keyboard...\n");
    keyboard_init();
    print_string_color("[  OK  ] ", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
    print_string("PS/2 keyboard ready\n");

    /* Phase 5: State manager */
    print_string("[KERN] Initializing state manager...\n");
    state_init();
    print_string_color("[  OK  ] ", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
    print_string("Default: ");
    state_print_current();

    /* Phase 6: RTC */
    print_string("[KERN] Reading RTC...\n");
    print_string_color("[  OK  ] ", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
    rtc_print_datetime();
    print_string("\n");

    /* Phase 7: All systems go */
    print_string("\n");
    print_string_color("[KERN] All systems initialized.\n",
                      MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));

    /* Phase 8: Launch shell */
    shell_run();

    /* Should never reach here */
    for (;;) {
        __asm__ __volatile__("hlt");
    }
}
