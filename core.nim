const displayDefinition* = """
MOVL   -16(%rbp),          %edx
MOVL   -8(%rbp),           %ecx
MOVL   $1,                 %ebx
MOVL   $4,                 %eax
INT    $0x80
"""

const displayIntDefinition* = """
MOVL  -16(%rbp),           %edx
"""

const exitDefinition* = """
MOVL   $1,                 %eax
MOVL   $0,                 %ebx
INT    $0x80
"""
