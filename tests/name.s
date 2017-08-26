# Int -> String
# def name(a):
#   if ==(%(a 2) 0):
#     return 'even'
#   else:
#     return 'odd'

# def main:
#   var a = name(2)
#   display(a)

.file   "name.roswell"
.data
s0:
    .string "even"
s1:
    .string "odd"
s2:
    .string "\n"

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

    MOVL    -16(%rbp),      %edx
    MOVL    -8(%rbp),       %ecx
    MOVL    $1,             %ebx
    MOVL    $4,             %eax
    INT     $0x80
    MOVL    $2,             %edx
    MOVL    $s2,            %ecx
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

.global name
name:
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

    MOVL    -8(%rbp),    %eax
    MOVL    $0,          %edx
    MOVL    $2,          %ebx
    DIVL    %ebx
    CMP     $0,          %edx
    JNE     l0
    MOVQ    $s0,        %rdi
    MOVQ    $5,         %rsi
    CALL    display
    JMP     l1
l0:
    MOVQ    $s1,         %rdi
    MOVQ    $4,          %rsi
    CALL    display
l1:

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
    MOVQ    $2,     %rdi
    CALL    name
    POPQ    %r11
    POPQ    %r10
    MOVL    $1,     %eax
    MOVL    $0,     %ebx
    INT     $0x80

