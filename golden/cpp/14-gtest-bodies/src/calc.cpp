#include "calc.h"

int add(int a, int b) { return a + b; }

bool Calc::ok() const { return add(1, 1) == 2; }
