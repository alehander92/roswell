.file    "tests/b.s"
.data
nl:
    .string "\n"
i:
    .long 10
s2:
    .string "play\n"
.text

.global display
display:
    PUSHQ  %rbp
    MOVQ   %rsp,               %rbp
    PUSHQ  %rdi
    PUSHQ  %rsi
    SUBQ   $16,                %rsp
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

.global play
play:
    PUSHQ  %rbp
    MOVQ   %rsp,               %rbp
    SUBQ   $8,                 %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    MOVL   $19,                %edi
    CALL   malloc
    MOVL   $5,                 (%rax)
    MOVL   $s2,                4(%rax)
    MOVQ   %rax,               %rdi
    CALL   display
    MOVL   %eax,               %r8d
play_return:
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
    SUBQ   $8,                 %rsp
    PUSHQ  %rbx
    PUSHQ  %r12
    PUSHQ  %r13
    PUSHQ  %r14
    PUSHQ  %r15
    #before

    CALL   play
    MOVL   %eax,               %r8d
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
      

