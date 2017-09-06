.file    "tests/f.s"
.data
nl:
    .string "\n"
i:
    .long 10
.text

.global display
display:
    PUSHQ  %rbp
    MOVQ   %rsp,               %rbp
    PUSHQ  %rdi
    PUSHQ  %rsi
    SUBQ   $0x10,              %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

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
      
display_return:
    #after

    POPQ   %r15
    POPQ   %r14
    POPQ   %r13
    POPQ   %r12
    POPQ   %rbx
    MOVQ   %rbp,               %rsp
    POPQ   %rbp
    RET    

.global _start
_start:
    PUSHQ  %rbp
    MOVQ   %rsp,               %rbp
    SUBQ   $0x20,              %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    MOVL   $0x4,               -0x8(%rbp)
    MOVQ   -0x8(%rbp),         %rax
    MOVL   $0x2,               (%rax)
    MOVQ   -0x10(%rbp),        %rax
    MOVQ   (%rax),             %rax
    MOVQ   %rax,               -0x18(%rbp)
    MOVQ   -0x18(%rbp),        %rdi
    CALL   display
    MOVL   %eax,               -0x1c(%rbp)
    MOVL   $1,                 %eax
    MOVL   $0,                 %ebx
    INT    $0x80
      
main_return:
    #after

    POPQ   %r15
    POPQ   %r14
    POPQ   %r13
    POPQ   %r12
    POPQ   %rbx
    MOVQ   %rbp,               %rsp
    POPQ   %rbp
    MOVL   $1,                 %eax
    MOVL   $0,                 %ebx
    INT    $0x80
      

