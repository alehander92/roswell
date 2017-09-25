type
  Predefined* = object
    function*:  string
    f*:         PredefinedLabel
    called*:    bool

  PredefinedLabel* = enum PDisplayDefinition, PTextDefinition, PTextIntDefinition, PTextDefaultDefinition, PExitDefinition, PStringDefinition, PNil

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
MOVQ    -8(%rbp),       %rax
RET
  """, # PTextDefinition

  """
MOVL    -4(%rbp),       %eax
# do some stuff
CALL    sprintf
  """, # PTextIntDefinition

  """
MOVL    $empty,         %eax
  """, # PDefaultDefinition

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
  printf("'%s'\n", s->chars);
}
  """, # PDisplayDefinition

  """
RoswellString* text_0_string(RoswellString* s) {
  return s;
}
  """, # PTextDefinition

  """
RoswellString* text_1_int(int s) {
  char t[14];
  sprintf(t, "%d", s);
  return roswell_string(t, strlen(t));
}
  """, # PTextIntDefinition

  """
RoswellString* text_2_default(int s) {
  return roswell_string("", 0);
}
  """, # PTextDefaultDefinition

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
  "", # PTextDefinition
  "", # PTextIntDefinition
  "", # PTextDefaultDefinition
  "", # PExitDefinition
  "", # PStringDefinition
  ""] # PNil

let jvmDefinitions*: array[PredefinedLabel, string] = [
  "", # PDisplayDefinition
  "", # PTextDefinition
  "", # PTextIntDefinition
  "", # PTextDefaultDefinition
  "", # PExitDefinition
  "", # PStringDefinition
  ""] # PNil

let llvmDefinitions*: array[PredefinedLabel, string] = [
  "", # PDisplayDefinition
  "", # PTextDefinition
  "", # PTextIntDefinition
  "", # PTextDefaultDefinition
  "", # PExitDefinition
  "", # PStringDefinition
  ""] # PNil

