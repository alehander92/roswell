

# def play:
#  display('play')

#def main:
#  play()


.file   "play.roswell"
.data
s0:
    .string "play\n"

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

    # after

    POPQ %r15            # restore callee-saved registers
    POPQ %r14
    POPQ %r13
    POPQ %r12
    POPQ %rbx
    MOVQ %rbp, %rsp      # reset stack to previous base pointer
    POPQ %rbp            # recover previous base pointer
    RET

.global play
play:
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

    MOVQ    $s0,    %rdi
    MOVQ    $6,     %rsi
    CALL    display

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
    CALL    play
    POPQ    %r11
    POPQ    %r10
    MOVL    $1,     %eax
    MOVL    $0,     %ebx
    INT     $0x80

