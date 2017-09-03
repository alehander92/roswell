type
  Predefined* = object
    function*:  string
    f*:         PredefinedLabel
    called*:    bool

  PredefinedLabel* = enum PDisplayDefinition, PDisplayIntDefinition, PExitDefinition, PStringDefinition, PNil

let asmDefinitions*: array[PredefinedLabel, string] = [
  """
MOVQ    -8(%rbp),       %rsp        # int* rsp = *((**int)rbp - 8)
MOVL    (%rsp),         %edx
MOVL    4(%rsp),        %ecx
MOVL    $1,             %ebx
MOVL    $4,             %eax
INT     $0x80
MOVL    $2,             %edx
MOVL    $nl,            %ecx
MOVL    $1,             %ebx
MOVL    $4,             %eax
INT     $0x80
  """, # PDisplayDefinition

  """
MOVL  -16(%rbp),           %edx
  """, # PDisplayIntDefinition

  """
MOVL   $1,                 %eax
MOVL   $0,                 %ebx
INT    $0x80
  """, # PExitDefinition

  "", # PStringDefinition

  ""] # PNil

let cDefinitions*: array[PredefinedLabel, string] = [
  """
void display(RoswellString* s) {
  printf("%s\n", s->chars);
}
  """, # PDisplayDefinition

  """
void display(int s) {
  printf("%d\n", s);
}
  """, # PDisplayIntDefinition

  """
exit(0);
  """, # PExitDefinition

  """
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

  """, # PStringDefinition

  ""] # PNil

let cilDefinitions*: array[PredefinedLabel, string] = [
  "", # PDisplayDefinition
  "", # PDisplayIntDefinition
  "", # PExitDefinition
  "", # PStringDefinition
  ""] # PNil

let jvmDefinitions*: array[PredefinedLabel, string] = [
  "", # PDisplayDefinition
  "", # PDisplayIntDefinition
  "", # PExitDefinition
  "", # PStringDefinition
  ""] # PNil

let llvmDefinitions*: array[PredefinedLabel, string] = [
  "", # PDisplayDefinition
  "", # PDisplayIntDefinition
  "", # PExitDefinition
  "", # PStringDefinition
  ""] # PNil
