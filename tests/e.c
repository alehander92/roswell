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

  int name(int a) {
  int result;
  int s;

  s = 840;
  result = a;

  return result;
}


int main() {

    name(2);
  exit(0);
  

}
