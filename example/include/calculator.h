#ifndef __CALCULATOR_H__
#define __CALCULATOR_H__

typedef struct {
  int x, y;
} Point;

struct Rectangle {
  Point top_left;
  Point bottom_right;
};

int add(int x, int y);
int subtract(int x, int y);
int multiply(int x, int y);
int divide(int x, int y);

#endif
