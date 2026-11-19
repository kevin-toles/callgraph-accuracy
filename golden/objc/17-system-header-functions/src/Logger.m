#import <Foundation/Foundation.h>
#include <stdio.h>

void logIt(int v) {
  NSLog(@"%d", v);
  printf("%d\n", v);
  int m = MAX(v, 3);
}
