; Made on Netwide Assembler
; Author Art1kDev
; COMMANDOS-86 version 2.00
; This is assembly code for the boot sector.
bits 16
org 0x7C00
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    mov si, msg
    call print
    mov ah, 0x02
    mov al, 20
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0x00
    mov bx, 0x7E00
    int 0x13
    jc err
    jmp 0x7E00
err:
    mov si, err_msg
    call print
    cli
    hlt
print:
    lodsb
    test al, al
    jz .d
    mov ah, 0x0E
    mov bx, 0x07
    int 0x10
    jmp print
.d:
    ret
msg db 'Loading COMMANDOS-86 v2.00...', 13, 10, 0
err_msg db 'Disk error!', 13, 10, 0
times 510-($-$$) db 0
dw 0xAA55