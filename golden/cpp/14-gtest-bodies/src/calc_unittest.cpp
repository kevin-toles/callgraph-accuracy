#include <gtest/gtest.h>

#include "calc.h"

class CalcTest : public ::testing::Test {
 protected:
  int twice(int x) { return add(x, x); }
  Calc calc_;
};

TEST_F(CalcTest, Adds) {
  EXPECT_EQ(twice(2), 4);
  ASSERT_TRUE(calc_.ok());
}

TEST_F(CalcTest, Chains) {
  int v = twice(add(1, 2));
  EXPECT_GT(v, 0);
}
