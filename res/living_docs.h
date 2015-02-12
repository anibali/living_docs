#ifndef __LIVING_DOCS_H__
#define __LIVING_DOCS_H__

#include "stdio.h"
#include "stdlib.h"

char** __failure_messages;
int __n_failure_messages;

#define __do_assert(e, file, line) {                                          \
  char* __failure_message = malloc(sizeof(char) * 256);                       \
  sprintf(__failure_message, "%s:%u: failed assertion `%s'", file, line, e);  \
  __failure_messages[__n_failure_messages++] = __failure_message;             \
}

#define do_assert(EX) {if(!(EX)) { (__do_assert(#EX, __FILE__, __LINE__)); return 1; }}

#define will_be_true(expr) do_assert(expr)
#define will_be_equal(a, b) do_assert(a == b)
#define fail() do_assert(0)

#endif
