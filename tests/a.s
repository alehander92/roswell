.file    ""
.data
nl:
    .string "\n"
i:
    .long 10
s2:
    .string "even\n"
s3:
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

    MOVL   $a,                 %eax
    MOVL   $0,                 %edx
    MOVL   $2,                 %ebx
    DIVL   %ebx
    MOVL   $t0,                %eax
    MOVL   $0,                 %ebx
    CMP    %eax,               %ebx
    JNE    l0
    MOVL   $19,                %edi
    CALL   malloc
    MOVL   $5,                 (%rax)
    MOVL   $s2,                -4(%rax)
    CALL   display
    MOVL   %rax,               %eax
    MOVL   $0,                 %rax
    JMP    name_return
    RET    
    JMP    l1
l0:
    MOVL   $18,                %edi
    CALL   malloc
    MOVL   $4,                 (%rax)
    MOVL   $s3,                -4(%rax)
    CALL   display
    MOVL   %rax,               %eax
    MOVL   $1,                 %rax
    JMP    name_return
    RET    
l1:
name_return:
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
    MOVL   %rax,               %eax
    MOVL   $t4,                %eax
    MOVQ   $a,                 %rdi
    CALL   display
    MOVL   %rax,               %eax
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
    

