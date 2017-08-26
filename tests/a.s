.file    ""
.data
s0:
    .string "even\n"
s1:
    .string "odd\n"
.text

.global display
display:
    PUSHQ  %rbp
    MOVQ   %rsp,               %rbp
    PUSHQ  %rdi
    PUSHQ  %rsi
    PUSHQ  %rdx
    SUBQ   $16,                %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    MOVL   -16(%rbp),          %edx
    MOVL   -8(%rbp),           %ecx
    MOVL   $1,                 %ebx
    MOVL   $4,                 %eax
    INT    $0x80
    
    #after

    POPQ   %r15
    POPQ   %r14
    POPQ   %r13
    POPQ   %r12
    POPQ   %rbx
    MOVQ   %rbp,               %rsp
    POPQ   %rbp
    RET    

.global name
name:
    PUSHQ  %rbp
    MOVQ   %rsp,               %rbp
    PUSHQ  %rdi
    PUSHQ  %rsi
    PUSHQ  %rdx
    SUBQ   $16,                %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    MOVL   -8(%rbp),           %eax
    MOVL   %eax,               %eax
    MOVL   $0,                 %edx
    MOVL   $2,                 %ebx
    DIVL   %ebx
    CMP    $0,                 %edx
    JNE    l0
    MOVQ   $s0,                %rdi
    MOVQ   $6,                 %rsi
    CALL   display
    JMP    l1
l0:
    MOVQ   $s1,                %rdi
    MOVQ   $5,                 %rsi
    CALL   display
l1:
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
    PUSHQ  %rdi
    PUSHQ  %rsi
    PUSHQ  %rdx
    SUBQ   $16,                %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    MOVQ   $2,                 %rdi
    CALL   name
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
    

