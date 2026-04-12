/* ===========================================================================
 * calc.h - Built-in Calculator
 * ===========================================================================
 * Evaluates arithmetic expressions with +, -, *, /, %, and parentheses.
 * Uses recursive descent parsing for correct operator precedence.
 * =========================================================================== */

#ifndef CALC_H
#define CALC_H

/* Evaluate a math expression string. Returns the result.
 * Sets *error to 1 if the expression is invalid, 0 otherwise. */
int calc_eval(const char *expr, int *error);

/* Run the interactive calculator mode */
void calc_run(void);

#endif /* CALC_H */
