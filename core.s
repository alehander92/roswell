
.file "core.s"

.data
nl:
    .string "\n"
i:
    .long   10
s0:
    .string "play"

.text

.global display
display:
    PUSHQ %rbp          # save the base pointer
    MOVQ  %rsp, %rbp    # set new base pointer
    PUSHQ %rdi          # save first argument on the stack
    PUSHQ %rsi          # save second argument on the stack
    PUSHQ %rdx          # save third argument on the stack
    SUBQ  $16, %rsp     # allocate two more local variables
    PUSHQ %rbx          # save callee-saved registers
    PUSHQ %r12
    PUSHQ %r13
    PUSHQ %r14
    PUSHQ %r15

    # before

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

    # after

    POPQ %r15            # restore callee-saved registers
    POPQ %r14
    POPQ %r13
    POPQ %r12
    POPQ %rbx
    MOVQ %rbp, %rsp      # reset stack to previous base pointer
    POPQ %rbp            # recover previous base pointer
    RET

.global a
a:
    PUSHQ %rbp          # save the base pointer
    MOVQ  %rsp, %rbp    # set new base pointer
    PUSHQ %rdi          # save first argument on the stack
    PUSHQ %rsi          # save second argument on the stack
    PUSHQ %rdx          # save third argument on the stack
    SUBQ  $16, %rsp     # allocate two more local variables
    PUSHQ %rbx          # save callee-saved registers
    PUSHQ %r12
    PUSHQ %r13
    PUSHQ %r14
    PUSHQ %r15

    # before    
    
    MOVL   $19,   %edi
    CALL   malloc
    MOVL   $5,    (%rax)
    MOVL   $s0,   4(%rax)
    MOVQ   %rax,  %rdi
    CALL   display
    MOV    %rdi,  %rax

    # after

    POPQ %r15            # restore callee-saved registers
    POPQ %r14
    POPQ %r13
    POPQ %r12
    POPQ %rbx
    MOVQ %rbp, %rsp      # reset stack to previous base pointer
    POPQ %rbp            # recover previous base pointer
    RET

.global _start
_start:
    PUSHQ   %r10
    PUSHQ   %r11
    CALL    a
    MOVQ    %rax,   %rdi
    CALL    display
    POPQ    %r11
    POPQ    %r10
    MOVL    $1,     %eax
    MOVL    $0,     %ebx
    INT     $0x80


