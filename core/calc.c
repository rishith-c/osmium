/* ===========================================================================
 * calc.c - Built-in Calculator Implementation
 * ===========================================================================
 * Recursive descent parser for arithmetic expressions.
 *
 * Grammar:
 *   expression = term (('+' | '-') term)*
 *   term       = factor (('*' | '/' | '%') factor)*
 *   factor     = ['-'] ( '(' expression ')' | number )
 *   number     = digit+
 *
 * Supports: +, -, *, /, %, unary minus, parentheses
 * All arithmetic is integer (no floating point in the kernel).
 * =========================================================================== */

#include "calc.h"
#include "screen.h"
#include "keyboard.h"
#include "string.h"

/* Parser state */
static const char *expr_ptr;
static int parse_error;

/* ---------------------------------------------------------------------------
 * skip_spaces - Advance past whitespace
 * --------------------------------------------------------------------------- */
static void skip_spaces(void)
{
    while (*expr_ptr == ' ') {
        expr_ptr++;
    }
}

/* Forward declarations for recursive descent */
static int parse_expression(void);

/* ---------------------------------------------------------------------------
 * parse_number - Parse an integer literal
 * --------------------------------------------------------------------------- */
static int parse_number(void)
{
    skip_spaces();

    if (!is_digit(*expr_ptr)) {
        parse_error = 1;
        return 0;
    }

    int result = 0;
    while (is_digit(*expr_ptr)) {
        result = result * 10 + (*expr_ptr - '0');
        expr_ptr++;
    }
    return result;
}

/* ---------------------------------------------------------------------------
 * parse_factor - Parse a factor: number, parenthesized expression, or negation
 * --------------------------------------------------------------------------- */
static int parse_factor(void)
{
    skip_spaces();

    /* Unary minus */
    if (*expr_ptr == '-') {
        expr_ptr++;
        return -parse_factor();
    }

    /* Parenthesized sub-expression */
    if (*expr_ptr == '(') {
        expr_ptr++;  /* Skip '(' */
        int result = parse_expression();
        skip_spaces();
        if (*expr_ptr == ')') {
            expr_ptr++;  /* Skip ')' */
        } else {
            parse_error = 1;
        }
        return result;
    }

    /* Must be a number */
    return parse_number();
}

/* ---------------------------------------------------------------------------
 * parse_term - Parse multiplication, division, modulo
 * --------------------------------------------------------------------------- */
static int parse_term(void)
{
    int result = parse_factor();

    while (!parse_error) {
        skip_spaces();
        char op = *expr_ptr;

        if (op != '*' && op != '/' && op != '%') {
            break;
        }
        expr_ptr++;

        int right = parse_factor();

        if ((op == '/' || op == '%') && right == 0) {
            parse_error = 1;
            print_string_color("Error: division by zero\n",
                              MAKE_COLOR(COLOR_RED, COLOR_BLACK));
            return 0;
        }

        if (op == '*')      result *= right;
        else if (op == '/') result /= right;
        else                result %= right;
    }

    return result;
}

/* ---------------------------------------------------------------------------
 * parse_expression - Parse addition and subtraction (lowest precedence)
 * --------------------------------------------------------------------------- */
static int parse_expression(void)
{
    int result = parse_term();

    while (!parse_error) {
        skip_spaces();
        char op = *expr_ptr;

        if (op != '+' && op != '-') {
            break;
        }
        expr_ptr++;

        int right = parse_term();

        if (op == '+') result += right;
        else           result -= right;
    }

    return result;
}

/* ---------------------------------------------------------------------------
 * calc_eval - Evaluate an expression string
 * --------------------------------------------------------------------------- */
int calc_eval(const char *expr, int *error)
{
    expr_ptr = expr;
    parse_error = 0;

    int result = parse_expression();

    /* Check for trailing garbage */
    skip_spaces();
    if (*expr_ptr != '\0') {
        parse_error = 1;
    }

    if (error) {
        *error = parse_error;
    }
    return result;
}

/* ---------------------------------------------------------------------------
 * calc_run - Interactive calculator mode
 * --------------------------------------------------------------------------- */
void calc_run(void)
{
    char line[128];
    int pos;
    char buf[12];

    print_string_color("\n=== Calculator ===\n",
                      MAKE_COLOR(COLOR_CYAN, COLOR_BLACK));
    print_string("Supports: + - * / % ( )\n");
    print_string("Type 'exit' to return to shell.\n\n");

    for (;;) {
        print_string_color("calc> ", MAKE_COLOR(COLOR_YELLOW, COLOR_BLACK));

        /* Read a line */
        pos = 0;
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
            } else if (pos < 127) {
                line[pos++] = c;
                print_char(c);
            }
        }
        line[pos] = '\0';

        /* Check for exit */
        if (strcmp(line, "exit") == 0 || strcmp(line, "quit") == 0) {
            break;
        }

        /* Skip empty lines */
        if (pos == 0) {
            continue;
        }

        /* Evaluate */
        int error = 0;
        int result = calc_eval(line, &error);

        if (error) {
            print_string_color("Error: invalid expression\n",
                              MAKE_COLOR(COLOR_RED, COLOR_BLACK));
        } else {
            print_string_color("= ", MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
            itoa(result, buf);
            print_string_color(buf, MAKE_COLOR(COLOR_GREEN, COLOR_BLACK));
            print_char('\n');
        }
    }
}
