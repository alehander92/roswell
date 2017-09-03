#include <stdio.h>
#include <stdlib.h>

typedef struct {
    char* chars;
    int   size;
    int   capacity;
} RoswellString;

RoswellString* roswell_string(char* c, int size) {
    RoswellString* s = (RoswellString*)malloc(sizeof(RoswellString));
    s->size = size;
    s->chars = c;
    s->capacity = size;
    return s;
}

  int a(int* b) {
  int result;
  int t0;
  int t1;
  int t2;

  t0 = b[0];
  t1 = b[1];
  t2 = t0 + t1;
  result = t2;

  return result;
}


int main() {
  int* t3;
  int t4;
  int t5;
  int* b;

  t3 = (int*)malloc(sizeof(int) * 2);
  t3[0] = 2;t4 = t3[0];
  t3[1] = 8;t5 = t3[1];
  b = t3;
    a(b);
  exit(0);
  

}
