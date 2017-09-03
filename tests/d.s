.file    "tests/d.s"
.data
nl:
    .string "\n"
i:
    .long 10
.text

.global a
a:
    PUSHQ  %rbp
    MOVQ   %rsp,               %rbp
    PUSHQ  %rdi
    SUBQ   $8,                 %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    MOVL   $0,                 %eax
    MOVL   -8(%rbp, %eax, 4),  %r8d
    MOVL   $1,                 %eax
    MOVL   -8(%rbp, %eax, 4),  %r9d
    MOVL   %r10d,              %eax
    JMP    a_return
a_return:
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
    SUBQ   $16,                %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    MOVL   $8,                 %edi
    CALL   malloc
    MOVL   %rax,               %r8d
    MOVL   $0,                 %eax
    MOVL   $2,                 (%r8d, %eax, 4)
    MOVL   (%r8d, %eax, 4),    %r9d
    MOVL   $1,                 %eax
    MOVL   $4,                 (%r8d, %eax, 4)
    MOVL   (%r8d, %eax, 4),    %r10d
    MOVL   %r8d,               %r11d
    MOVQ   %r11d,              %rdi
    CALL   a
    MOVL   %eax,               -8(%rbp)
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
      

