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
  

void play() {

    display(roswell_string("play", 4));


}


int main() {

  play();
  exit(0);
  

}
