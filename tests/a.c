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

  void display(RoswellString* s) {
  printf("%s\n", s->chars);
}
  

int name(int a) {
  int result;
  int t0;
  int t1;

  t0 = a % 2;
  t1 = t0 == 0;
  if (t1 != 1) goto l0;
    display(roswell_string("even", 4));
  result = 0;
  goto l1;
  l0:
    display(roswell_string("odd", 3));
  result = 1;
  l1:

  return result;
}


int main() {

    name(2);
  exit(0);
  

}
