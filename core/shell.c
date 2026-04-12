/* ===========================================================================
 * shell.c - Interactive Command Shell Implementation
 * ===========================================================================
 * Provides a command-line interface with built-in commands.
 * The prompt changes based on the current OS state:
 *   [SAFE]>     in SAFE_MODE
 *   [CREATOR]>  in CREATOR_MODE
 *
 * Commands:
 *   help     - Show available commands
 *   clear    - Clear the screen
 *   info     - System information
 *   time     - Show current date and time
 *   uptime   - Show time since boot
 *   mode     - Show current operating mode
 *   toggle   - Switch between SAFE and CREATOR mode
 *   echo     - Print text to screen
 *   calc     - Enter calculator mode
 *   python   - Enter Python REPL
 *   color    - Change text color (CREATOR mode only)
 *   reboot   - Reboot the system
 *   halt     - Halt the CPU
 * =========================================================================== */

#include "shell.h"
#include "kernel.h"
#include "screen.h"
#include "keyboard.h"
#include "string.h"
#include "state_manager.h"
#include "timer.h"
#include "rtc.h"
#include "calc.h"
#include "pyshell.h"

/* Maximum command line length */
#define CMD_MAX_LEN 256

/* Command history */
#define HISTORY_SIZE 10
static char history[HISTORY_SIZE][CMD_MAX_LEN];
static int history_count = 0;

/* ---------------------------------------------------------------------------
 * print_prompt - Print the mode-aware shell prompt
 * --------------------------------------------------------------------------- */
static void print_prompt(void)
{
    if (state_get_current() == SAFE_MODE) {
        print_string_color("[SAFE]", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
    } else {
        print_string_color("[CREATOR]", MAKE_COLOR(COLOR_YELLOW, COLOR_BLACK));
    }
    print_string_color("> ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
}

/* ---------------------------------------------------------------------------
 * read_line - Read a line from keyboard with echo and backspace support
 * --------------------------------------------------------------------------- */
static int read_line(char *buf, int max_len)
{
    int pos = 0;

    for (;;) {
        char c = keyboard_getchar();

        if (c == '\n') {
            print_char('\n');
            break;
        } else if (c == '\b') {
            if (pos > 0) {
                pos--;
                print_char('\b');
            }
        } else if (pos < max_len - 1) {
            buf[pos++] = c;
            print_char(c);
        }
    }
    buf[pos] = '\0';
    return pos;
}

/* ---------------------------------------------------------------------------
 * add_to_history - Store a command in the history buffer
 * --------------------------------------------------------------------------- */
static void add_to_history(const char *cmd)
{
    if (strlen(cmd) == 0) return;

    int idx = history_count % HISTORY_SIZE;
    strncpy(history[idx], cmd, CMD_MAX_LEN);
    history_count++;
}

/* ---------------------------------------------------------------------------
 * cmd_help - Print available commands
 * --------------------------------------------------------------------------- */
static void cmd_help(void)
{
    print_string_color("\n  Dual-State OS Shell Commands\n",
                      MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));
    print_string_color("  ============================\n\n",
                      MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));

    print_string_color("  help    ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Show this help message\n");
    print_string_color("  clear   ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Clear the screen\n");
    print_string_color("  info    ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Show system information\n");
    print_string_color("  time    ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Show current date and time\n");
    print_string_color("  uptime  ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Show time since boot\n");
    print_string_color("  mode    ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Show current operating mode\n");
    print_string_color("  toggle  ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Switch between SAFE and CREATOR mode\n");
    print_string_color("  echo    ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Print text (usage: echo <text>)\n");
    print_string_color("  calc    ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Open the calculator\n");
    print_string_color("  python  ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Open the Python REPL\n");
    print_string_color("  history ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Show command history\n");
    print_string_color("  color   ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Change text color (CREATOR mode only)\n");
    print_string_color("  reboot  ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Reboot the system\n");
    print_string_color("  halt    ", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string("- Halt the CPU\n");

    print_char('\n');
}

/* ---------------------------------------------------------------------------
 * cmd_info - Print system information
 * --------------------------------------------------------------------------- */
static void cmd_info(void)
{
    char buf[12];

    print_string_color("\n  System Information\n",
                      MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));
    print_string_color("  ==================\n\n",
                      MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));

    print_string("  OS:        Dual-State OS v" KERNEL_VERSION_STRING "\n");
    print_string("  Arch:      x86 (i386), 32-bit protected mode\n");
    print_string("  Display:   VGA text mode, 80x25\n");
    print_string("  Timer:     PIT @ 100 Hz\n");
    print_string("  Keyboard:  PS/2, US QWERTY layout\n");

    print_string("  Uptime:    ");
    itoa((int)timer_get_uptime(), buf);
    print_string(buf);
    print_string(" seconds (");
    itoa((int)timer_get_ticks(), buf);
    print_string(buf);
    print_string(" ticks)\n");

    print_string("  Date/Time: ");
    rtc_print_datetime();
    print_string("\n");

    print_string("  Mode:      ");
    if (state_get_current() == SAFE_MODE) {
        print_string_color("SAFE MODE\n", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
    } else {
        print_string_color("CREATOR MODE\n", MAKE_COLOR(COLOR_YELLOW, COLOR_BLACK));
    }

    print_char('\n');
}

/* ---------------------------------------------------------------------------
 * cmd_time - Print current date and time
 * --------------------------------------------------------------------------- */
static void cmd_time(void)
{
    print_string("  ");
    rtc_print_datetime();
    print_char('\n');
}

/* ---------------------------------------------------------------------------
 * cmd_uptime - Print uptime
 * --------------------------------------------------------------------------- */
static void cmd_uptime(void)
{
    char buf[12];
    unsigned int total_secs = timer_get_uptime();
    unsigned int hours = total_secs / 3600;
    unsigned int mins  = (total_secs % 3600) / 60;
    unsigned int secs  = total_secs % 60;

    print_string("  Up ");
    itoa((int)hours, buf);
    print_string(buf);
    print_string("h ");
    itoa((int)mins, buf);
    print_string(buf);
    print_string("m ");
    itoa((int)secs, buf);
    print_string(buf);
    print_string("s\n");
}

/* ---------------------------------------------------------------------------
 * cmd_mode - Print current mode
 * --------------------------------------------------------------------------- */
static void cmd_mode(void)
{
    print_string("  Current mode: ");
    state_print_current();
}

/* ---------------------------------------------------------------------------
 * cmd_toggle - Toggle between modes
 * --------------------------------------------------------------------------- */
static void cmd_toggle(void)
{
    print_string("  ");
    state_toggle();
}

/* ---------------------------------------------------------------------------
 * cmd_echo - Print text
 * --------------------------------------------------------------------------- */
static void cmd_echo(const char *args)
{
    /* Skip leading spaces */
    while (*args == ' ') args++;
    print_string(args);
    print_char('\n');
}

/* ---------------------------------------------------------------------------
 * cmd_history - Show command history
 * --------------------------------------------------------------------------- */
static void cmd_history(void)
{
    char buf[12];
    int start = 0;
    int total = history_count;

    if (total > HISTORY_SIZE) {
        start = total - HISTORY_SIZE;
    }

    print_string("\n");
    int i;
    for (i = start; i < total; i++) {
        print_string("  ");
        itoa(i + 1, buf);
        print_string(buf);
        print_string("  ");
        print_string(history[i % HISTORY_SIZE]);
        print_char('\n');
    }
    print_char('\n');
}

/* ---------------------------------------------------------------------------
 * cmd_color - Change text color (CREATOR mode only)
 * --------------------------------------------------------------------------- */
static void cmd_color(const char *args)
{
    if (state_get_current() != CREATOR_MODE) {
        print_string_color("  Error: 'color' requires CREATOR MODE\n",
                          MAKE_COLOR(COLOR_RED, COLOR_BLACK));
        print_string("  Use 'toggle' to switch modes.\n");
        return;
    }

    /* Skip spaces */
    while (*args == ' ') args++;

    if (*args == '\0') {
        print_string("  Usage: color <0-15>\n");
        print_string("  Colors: 0=black 1=blue 2=green 3=cyan\n");
        print_string("          4=red 5=magenta 6=brown 7=lgrey\n");
        print_string("          8=dgrey 9=lblue 10=lgreen 11=lcyan\n");
        print_string("          12=lred 13=lmagenta 14=yellow 15=white\n");
        return;
    }

    int color = atoi(args);
    if (color >= 0 && color <= 15) {
        screen_set_color(MAKE_COLOR((unsigned char)color, COLOR_BLACK));
        print_string("  Color changed.\n");
    } else {
        print_string_color("  Error: color must be 0-15\n",
                          MAKE_COLOR(COLOR_RED, COLOR_BLACK));
    }
}

/* ---------------------------------------------------------------------------
 * cmd_reboot - Reboot the system via keyboard controller
 * --------------------------------------------------------------------------- */
static void cmd_reboot(void)
{
    print_string("  Rebooting...\n");

    /* Triple fault method: load a zero-length IDT and trigger an interrupt */
    /* This causes a triple fault which resets the CPU */
    unsigned char temp[6] = {0};
    __asm__ __volatile__("lidt (%0)" : : "r"(temp));
    __asm__ __volatile__("int $0x03");
}

/* ---------------------------------------------------------------------------
 * cmd_halt - Halt the CPU
 * --------------------------------------------------------------------------- */
static void cmd_halt(void)
{
    print_string_color("  System halted.\n",
                      MAKE_COLOR(COLOR_YELLOW, COLOR_BLACK));
    __asm__ __volatile__("cli; hlt");
}

/* ---------------------------------------------------------------------------
 * process_command - Parse and execute a command
 * --------------------------------------------------------------------------- */
static void process_command(const char *line)
{
    /* Skip leading whitespace */
    while (*line == ' ') line++;

    /* Empty command */
    if (*line == '\0') return;

    /* Extract the command name (first word) */
    char cmd[32];
    int i = 0;
    while (line[i] && line[i] != ' ' && i < 31) {
        cmd[i] = line[i];
        i++;
    }
    cmd[i] = '\0';

    /* Find arguments (everything after the first space) */
    const char *args = line + i;

    /* Dispatch to command handlers */
    if (strcmp(cmd, "help") == 0) {
        cmd_help();
    } else if (strcmp(cmd, "clear") == 0) {
        screen_clear();
    } else if (strcmp(cmd, "info") == 0) {
        cmd_info();
    } else if (strcmp(cmd, "time") == 0) {
        cmd_time();
    } else if (strcmp(cmd, "uptime") == 0) {
        cmd_uptime();
    } else if (strcmp(cmd, "mode") == 0) {
        cmd_mode();
    } else if (strcmp(cmd, "toggle") == 0) {
        cmd_toggle();
    } else if (strcmp(cmd, "echo") == 0) {
        cmd_echo(args);
    } else if (strcmp(cmd, "calc") == 0) {
        calc_run();
    } else if (strcmp(cmd, "python") == 0) {
        pyshell_run();
    } else if (strcmp(cmd, "history") == 0) {
        cmd_history();
    } else if (strcmp(cmd, "color") == 0) {
        cmd_color(args);
    } else if (strcmp(cmd, "reboot") == 0) {
        cmd_reboot();
    } else if (strcmp(cmd, "halt") == 0) {
        cmd_halt();
    } else {
        /* Try to evaluate as a calc expression */
        int error = 0;
        int result = calc_eval(line, &error);
        if (!error) {
            char buf[12];
            print_string("  = ");
            itoa(result, buf);
            print_string(buf);
            print_char('\n');
        } else {
            print_string_color("  Unknown command: ", MAKE_COLOR(COLOR_RED, COLOR_BLACK));
            print_string(cmd);
            print_string("\n  Type 'help' for available commands.\n");
        }
    }
}

/* ---------------------------------------------------------------------------
 * shell_run - Main shell loop (does not return)
 * --------------------------------------------------------------------------- */
void shell_run(void)
{
    char line[CMD_MAX_LEN];

    print_string_color("\nWelcome to Dual-State OS v" KERNEL_VERSION_STRING "\n",
                      MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));
    print_string("Type ");
    print_string_color("help", MAKE_COLOR(COLOR_WHITE, COLOR_BLACK));
    print_string(" for available commands.\n\n");

    for (;;) {
        print_prompt();

        int len = read_line(line, CMD_MAX_LEN);

        if (len > 0) {
            add_to_history(line);
            process_command(line);
        }
    }
}
