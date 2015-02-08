#include "calculator.h"
#include "stdio.h"

/**
 * Adds two numbers together.
 *
 * When two positive numbers are added together, the result will also be
 * positive.
 *
 *     int result = add(1, 2);
 *     will_be_true(result > 0);
 *
 * It is possible to achieve the same effect as subtraction by adding a negative
 * number.
 *
 *     int sum = add(5, -1);
 *     int difference = subtract(5, 1);
 *     will_be_equal(sum, difference);
 */
int add(int x, int y) {
  return x + y;
}

/**
 * Finds the difference between two numbers.
 *
 * For example,
 *
 *     int result = subtract(42, 5);
 *     will_be_equal(result, 37);
 */
int subtract(int x, int y) {
  return x - y;
}
