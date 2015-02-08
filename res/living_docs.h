#ifndef __LIVING_DOCS_H__
#define __LIVING_DOCS_H__

#include "stdio.h"

#define __do_assert(e, file, line) \
    ((void)printf("%s:%u: failed assertion `%s'\n", file, line, e))
#define do_assert(EX) {if(!(EX)) { (__do_assert(#EX, __FILE__, __LINE__)); return 1; }}

#define will_be_true(expr) do_assert(expr)
#define will_be_equal(a, b) do_assert(a == b)
#define fail() do_assert(0)

#endif
