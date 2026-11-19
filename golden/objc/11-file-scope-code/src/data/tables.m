#define SQUARE(x) ((x) * (x))

static const int kTable[] = { SQUARE(2), SQUARE(3) };

int tableValue(int i) {
  return kTable[i] + SQUARE(i);
}
