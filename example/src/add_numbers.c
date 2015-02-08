#include "numbers.h"
#include "stdio.h"

/**
 * Adds two numbers together.
 *
 * For example,
 *
 *     int result = add_numbers(1, 2);
 *     will_be_equal(result, 3);
 *
 * Or perhaps
 *
 *     int result = add_numbers(-1, 5);
 *     will_be_true(result == 4);
 *     if(result != 4)
 *       fail();
 */
int add_numbers(int x, int y) {
  return x + y;
}

/**
 * Subtracts a number from another.
 *
 * For example,
 *
 *     int result = sub_numbers(42, 5);
 *     will_be_equal(result, 37);
 */
int sub_numbers(int x, int y) {
  return x - y;
}
