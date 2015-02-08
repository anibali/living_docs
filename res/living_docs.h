#ifndef __LIVING_DOCS_H__
#define __LIVING_DOCS_H__

#include "assert.h"

#define will_be_true(expr) assert(expr)
#define will_be_equal(a, b) assert(a == b)
#define fail() assert(0)

#endif
