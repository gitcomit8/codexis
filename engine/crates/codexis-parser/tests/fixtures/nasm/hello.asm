BITS 64
DEFAULT REL

global _start
extern puts

section .text
_start:
    lea rdi, [rel message]
    call puts
    xor eax, eax
.done:
    ret

section .rodata
message: db "Codexis", 0
