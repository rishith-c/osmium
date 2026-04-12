/* ===========================================================================
 * pyshell.c - Mini Python-like REPL Implementation
 * ===========================================================================
 * A bare-metal Python-like interpreter. Since we can't run CPython on
 * bare metal, this is a custom mini-language that looks like Python.
 *
 * Supported features:
 *   print("hello world")     -> prints text
 *   print(2 + 3)             -> prints 5
 *   x = 10                   -> assigns variable
 *   print(x * 2)             -> prints 20
 *   x = x + 1                -> updates variable
 *   exit() or quit()         -> returns to shell
 *
 * Variables: 26 single-letter vars (a-z), initialized to 0.
 * Arithmetic: +, -, *, /, %, parentheses.
 * =========================================================================== */

#include "pyshell.h"
#include "screen.h"
#include "keyboard.h"
#include "string.h"
#include "calc.h"

/* 26 variables: a=0, b=1, ..., z=25 */
static int variables[26];

/* Parser state for expression evaluation */
static const char *py_ptr;
static int py_error;

/* Forward declaration */
static int py_parse_expr(void);

/* ---------------------------------------------------------------------------
 * py_skip_spaces - Skip whitespace in input
 * --------------------------------------------------------------------------- */
static void py_skip_spaces(void)
{
    while (*py_ptr == ' ' || *py_ptr == '\t') {
        py_ptr++;
    }
}

/* ---------------------------------------------------------------------------
 * py_parse_atom - Parse a number or variable name
 * --------------------------------------------------------------------------- */
static int py_parse_atom(void)
{
    py_skip_spaces();

    /* Unary minus */
    if (*py_ptr == '-') {
        py_ptr++;
        return -py_parse_atom();
    }

    /* Parenthesized expression */
    if (*py_ptr == '(') {
        py_ptr++;
        int result = py_parse_expr();
        py_skip_spaces();
        if (*py_ptr == ')') {
            py_ptr++;
        } else {
            py_error = 1;
        }
        return result;
    }

    /* Variable (single lowercase letter not followed by another letter) */
    if (*py_ptr >= 'a' && *py_ptr <= 'z') {
        char next = *(py_ptr + 1);
        if (!is_alpha(next) && next != '_') {
            int idx = *py_ptr - 'a';
            py_ptr++;
            return variables[idx];
        }
    }

    /* Number */
    if (is_digit(*py_ptr)) {
        int result = 0;
        while (is_digit(*py_ptr)) {
            result = result * 10 + (*py_ptr - '0');
            py_ptr++;
        }
        return result;
    }

    py_error = 1;
    return 0;
}

/* ---------------------------------------------------------------------------
 * py_parse_term - Parse *, /, %
 * --------------------------------------------------------------------------- */
static int py_parse_term(void)
{
    int result = py_parse_atom();
    while (!py_error) {
        py_skip_spaces();
        char op = *py_ptr;
        if (op != '*' && op != '/' && op != '%') break;
        py_ptr++;

        int right = py_parse_atom();

        if ((op == '/' || op == '%') && right == 0) {
            print_string_color("ZeroDivisionError\n",
                              MAKE_COLOR(COLOR_RED, COLOR_BLACK));
            py_error = 1;
            return 0;
        }

        if (op == '*')      result *= right;
        else if (op == '/') result /= right;
        else                result %= right;
    }
    return result;
}

/* ---------------------------------------------------------------------------
 * py_parse_expr - Parse +, -
 * --------------------------------------------------------------------------- */
static int py_parse_expr(void)
{
    int result = py_parse_term();
    while (!py_error) {
        py_skip_spaces();
        char op = *py_ptr;
        if (op != '+' && op != '-') break;
        py_ptr++;
        int right = py_parse_term();
        if (op == '+') result += right;
        else           result -= right;
    }
    return result;
}

/* ---------------------------------------------------------------------------
 * handle_print - Handle print() statements
 * ---------------------------------------------------------------------------
 * Supported forms:
 *   print("text")
 *   print(expression)
 * --------------------------------------------------------------------------- */
static void handle_print(const char *args)
{
    /* Skip whitespace and opening paren */
    while (*args == ' ') args++;
    if (*args != '(') {
        print_string_color("SyntaxError: expected '('\n",
                          MAKE_COLOR(COLOR_RED, COLOR_BLACK));
        return;
    }
    args++;

    /* Find matching closing paren */
    const char *end = args;
    int depth = 1;
    while (*end && depth > 0) {
        if (*end == '(') depth++;
        if (*end == ')') depth--;
        if (depth > 0) end++;
    }

    /* Check for string literal */
    while (*args == ' ') args++;

    if (*args == '"' || *args == '\'') {
        char quote = *args;
        args++;  /* Skip opening quote */

        /* Print until closing quote */
        while (*args && *args != quote && args < end) {
            print_char(*args);
            args++;
        }
        print_char('\n');
    } else {
        /* Evaluate as expression */
        /* Copy the expression to a temp buffer for parsing */
        char expr_buf[128];
        int i = 0;
        const char *p = args;
        while (p < end && i < 126) {
            expr_buf[i++] = *p++;
        }
        expr_buf[i] = '\0';

        py_ptr = expr_buf;
        py_error = 0;
        int result = py_parse_expr();

        if (!py_error) {
            char buf[12];
            itoa(result, buf);
            print_string(buf);
            print_char('\n');
        }
    }
}

/* ---------------------------------------------------------------------------
 * handle_assignment - Handle variable assignment: x = expression
 * --------------------------------------------------------------------------- */
static int try_assignment(const char *line)
{
    /* Check pattern: single letter, optional spaces, '=' (not '==') */
    if (!is_alpha(line[0]) || is_alpha(line[1])) {
        return 0;
    }

    const char *p = line + 1;
    while (*p == ' ') p++;

    if (*p != '=' || *(p + 1) == '=') {
        return 0;
    }
    p++;  /* Skip '=' */

    int var_idx = line[0] - 'a';
    if (var_idx < 0 || var_idx >= 26) return 0;

    /* Evaluate the right-hand side */
    py_ptr = p;
    py_error = 0;
    int value = py_parse_expr();

    if (!py_error) {
        variables[var_idx] = value;
    } else {
        print_string_color("SyntaxError: invalid expression\n",
                          MAKE_COLOR(COLOR_RED, COLOR_BLACK));
    }

    return 1;
}

/* ---------------------------------------------------------------------------
 * read_line - Read a line from keyboard with echo
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
 * pyshell_run - Main Python REPL loop
 * --------------------------------------------------------------------------- */
void pyshell_run(void)
{
    char line[128];

    /* Reset all variables */
    int i;
    for (i = 0; i < 26; i++) {
        variables[i] = 0;
    }

    print_string_color("\nPython 3.12.0 (Dual-State OS Edition)\n",
                      MAKE_COLOR(COLOR_YELLOW, COLOR_BLACK));
    print_string("Mini Python REPL - Supports: print(), variables (a-z),\n");
    print_string("arithmetic (+, -, *, /, %, parens)\n");
    print_string("Type exit() or quit() to return to shell.\n\n");

    for (;;) {
        print_string_color(">>> ", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));

        int len = read_line(line, sizeof(line));

        /* Skip empty lines */
        if (len == 0) continue;

        /* Check for exit */
        if (strcmp(line, "exit()") == 0 || strcmp(line, "quit()") == 0) {
            break;
        }

        /* Check for help */
        if (strcmp(line, "help()") == 0) {
            print_string("Commands:\n");
            print_string("  print(\"text\")   - Print a string\n");
            print_string("  print(expr)     - Print expression result\n");
            print_string("  x = 5           - Assign to variable (a-z)\n");
            print_string("  expression      - Evaluate and display\n");
            print_string("  exit()          - Return to shell\n");
            continue;
        }

        /* Check for print() */
        if (strncmp(line, "print", 5) == 0) {
            handle_print(line + 5);
            continue;
        }

        /* Check for variable assignment */
        if (line[0] >= 'a' && line[0] <= 'z' && try_assignment(line)) {
            continue;
        }

        /* Try to evaluate as expression */
        py_ptr = line;
        py_error = 0;
        int result = py_parse_expr();

        py_skip_spaces();
        if (!py_error && *py_ptr == '\0') {
            char buf[12];
            itoa(result, buf);
            print_string(buf);
            print_char('\n');
        } else if (!py_error) {
            print_string_color("SyntaxError: unexpected characters\n",
                              MAKE_COLOR(COLOR_RED, COLOR_BLACK));
        }
    }
}
