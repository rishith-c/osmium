/* ===========================================================================
 * pyshell.h - Mini Python-like REPL
 * ===========================================================================
 * A simplified Python-like interpreter that supports:
 *   - print("text") and print(expression)
 *   - Variable assignment: x = 5
 *   - Arithmetic expressions: +, -, *, /, %
 *   - 26 single-letter variables (a-z)
 *   - exit() to quit
 * =========================================================================== */

#ifndef PYSHELL_H
#define PYSHELL_H

/* Run the Python REPL */
void pyshell_run(void);

#endif /* PYSHELL_H */
