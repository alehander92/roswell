const displayDefinition* = """
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
"""

const displayIntDefinition* = """
MOVL  -16(%rbp),           %edx
"""

const exitDefinition* = """
MOVL   $1,                 %eax
MOVL   $0,                 %ebx
INT    $0x80
"""
