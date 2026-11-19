void paint_red(void) {}
void paint_green(void) {}

#define X(name) paint_##name();
void paint_all(void) {
#include "colors.def"
}
#undef X
