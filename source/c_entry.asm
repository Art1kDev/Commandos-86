bits 16

extern _main

section .text
global _start

_start:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax
    
    mov ss, ax
    mov sp, 0x7E00
    
    sti

    call _main

_exit:
    mov ah, 0x06
    mov al, 0x00
    mov cx, 0x0000
    mov dx, 0x184f
    mov bh, 0x07
    int 0x10
    
    jmp 0xFFFF:0x0000