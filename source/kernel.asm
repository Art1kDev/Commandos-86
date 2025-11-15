; Made on Netwide Assembler
; Author Art1kDev
; COMMANDOS-86 version 1.00
; This is assembly code for system. 
bits 16
org 0x7E00
start:
    mov ax, 0x0003
    int 0x10
    mov byte [current_attribute], 0x07
    mov si, banner
    call print
    call nl
    mov si, welcome
    call print
    call nl
    call init_fs
main_loop:
    mov si, prompt_str
    call print
    mov di, cmd
    mov cx, 80
    xor al, al
    rep stosb
    mov di, cmd
input_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je main_loop
    cmp al, 13
    je input_done
    cmp al, 8
    je backspace
    cmp di, cmd+79
    jae input_loop
    mov ah, 0x0E
    mov bl, [current_attribute]
    int 0x10
    stosb
    jmp input_loop
backspace:
    cmp di, cmd
    je input_loop
    dec di
    mov ah, 0x0E
    mov al, 8
    mov bl, [current_attribute]
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp input_loop
input_done:
    call nl
    mov byte [di], 0
    mov si, cmd
    mov di, c_help
    call strcmp
    jc do_help
    mov di, c_dir
    call strcmp
    jc do_dir
    mov di, c_cls
    call strcmp
    jc do_cls
    mov di, c_ver
    call strcmp
    jc do_ver
    mov di, c_echo
    call strcmp_prefix
    jc do_echo
    mov di, c_reboot
    call strcmp
    jc do_reboot
    mov di, c_mem
    call strcmp
    jc do_mem
    mov di, c_col
    call strcmp_prefix
    jc do_col
    mov di, c_mkdir
    call strcmp_prefix
    jc do_mkdir
    mov di, c_hworld
    call strcmp
    jc do_hworld
    mov di, c_shutdown
    call strcmp
    jc do_shutdown
    mov si, not_found
    call print
    jmp main_loop
do_help:
    mov si, help_msg
    call print
    jmp main_loop
do_dir:
    mov si, dir_c
    call print
    mov si, [dir_content_end]
    cmp si, dir_content_start
    je .empty
    mov si, dir_content_start
    call print_dir_content
    jmp main_loop
.empty:
    mov si, empty_dir_msg
    call print
    jmp main_loop
do_cls:
    mov ah, 0x06
    mov al, 0x00
    mov cx, 0x0000
    mov dx, 0x184f
    mov bh, [current_attribute]
    int 0x10
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 0x00
    mov dl, 0x00
    int 0x10
    jmp main_loop
do_ver:
    mov si, version_msg
    call print
    jmp main_loop
do_echo:
    mov si, cmd
    add si, 5
    call skip_space
    test byte [si], 0xFF
    jz .empty
    mov cx, 70
.print_char:
    lodsb
    test al, al
    jz .done
    cmp cx, 0
    je .done
    mov ah, 0x0E
    mov bl, [current_attribute]
    int 0x10
    dec cx
    jmp .print_char
.done:
    call nl
    jmp main_loop
.empty:
    call nl
    jmp main_loop
do_reboot:
    mov si, reboot_msg
    call print
    jmp 0xFFFF:0x0000
do_mem:
    int 0x12
    mov si, mem_msg_prefix
    call print
    call print_decimal
    mov si, mem_msg_suffix
    call print
    jmp main_loop
do_col:
    mov si, cmd
    add si, 4
    call skip_space
    lodsb
    cmp al, '0'
    jb .error
    cmp al, '4'
    ja .error
    sub al, '0'
    mov bl, al
    xor bh, bh
    mov al, [color_map + bx]
    shl al, 4
    or al, 0x07
    mov [current_attribute], al
    mov bh, al
    mov ah, 0x06
    mov al, 0x00
    mov cx, 0x0000
    mov dx, 0x184f
    int 0x10
    mov si, col_msg
    call print
    jmp main_loop
.error:
    mov si, col_err_msg
    call print
    jmp main_loop
do_mkdir:
    mov si, cmd
    add si, 6
    call skip_space
    cmp byte [si], 0
    je .error_no_name
    mov di, [dir_content_end]
    cmp di, dir_content_start + 250
    jae .error_full
.copy_loop:
    lodsb
    cmp al, 0
    je .done_copy
    cmp al, ' '
    je .done_copy
    cmp di, dir_content_start + 250
    jae .done_copy
    stosb
    jmp .copy_loop
.done_copy:
    mov al, '/'
    stosb
    mov al, 13
    stosb
    mov al, 10
    stosb
    mov al, 0
    stosb
    mov [dir_content_end], di
    mov si, mkdir_ok
    call print
    jmp main_loop
.error_no_name:
    mov si, mkdir_err
    call print
    jmp main_loop
.error_full:
    mov si, mkdir_full
    call print
    jmp main_loop
do_shutdown:
    mov si, shutdown_msg
    call print
    cli
    hlt

do_hworld:
    mov si, msg_c
    call print
    jmp main_loop

skip_space:
    lodsb
    cmp al, ' '
    je skip_space
    dec si
    ret
strcmp_prefix:
    push si
    push di
.loop:
    lodsb
    mov ah, [di]
    inc di
    test ah, ah
    jz .match
    cmp al, ah
    jne .no
    jmp .loop
.match:
    pop di
    pop si
    stc
    ret
.no:
    pop di
    pop si
    clc
    ret
strcmp:
    push si
    push di
.loop:
    lodsb
    mov ah, [di]
    inc di
    cmp al, ah
    jne .no
    test al, al
    jnz .loop
    pop di
    pop si
    stc
    ret
.no:
    pop di
    pop si
    clc
    ret
print:
    lodsb
    test al, al
    jz .done
    cmp al, 13
    je print
    cmp al, 10
    je .nl
    mov ah, 0x0E
    mov bl, [current_attribute]
    int 0x10
    jmp print
.nl:
    call nl
    jmp print
.done:
    ret
print_dir_content:
    push si
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 13
    je .loop
    cmp al, 10
    je .nl
    mov ah, 0x0E
    mov bl, [current_attribute]
    int 0x10
    jmp .loop
.nl:
    call nl
    jmp .loop
.done:
    pop si
    ret
nl:
    mov ah, 0x0E
    mov al, 13
    mov bl, [current_attribute]
    int 0x10
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    cmp dh, 24
    je .scroll
    inc dh
    mov ah, 0x02
    mov bh, 0x00
    mov dl, 0x00
    int 0x10
    ret
.scroll:
    mov ah, 0x06
    mov al, 0x01
    mov cx, 0x0000
    mov dx, 0x184f
    mov bh, [current_attribute]
    int 0x10
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 24
    mov dl, 0x00
    int 0x10
    ret
print_decimal:
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
    test ax, ax
    jnz .divide
    mov al, '0'
    mov ah, 0x0E
    mov bl, [current_attribute]
    int 0x10
    jmp .done
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
.print:
    pop dx
    add dl, '0'
    mov ah, 0x0E
    mov al, dl
    mov bl, [current_attribute]
    int 0x10
    loop .print
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
init_fs:
    mov word [dir_content_end], dir_content_start
    mov si, initial_dir_content
    mov di, dir_content_start
.copy:
    lodsb
    test al, al
    jz .done
    stosb
    jmp .copy
.done:
    mov [dir_content_end], di
    ret
initial_dir_content db '  document/',13,10,0
empty_dir_msg db ' <DIR> (empty)',13,10,0
banner db 'By Art1kDev. Made on Netwide Assembler',13,10,0
welcome db 'COMMANDOS-86 v1.01',13,10,'Type "help" for commands.',13,10,0
prompt_str db 'C:>',0
not_found db 'Not found command',13,10,0
reboot_msg db 'Rebooting...',13,10,0
shutdown_msg db 'System shutting down...',13,10,0
help_msg db 'Available commands:',13,10,' help - show this message',13,10,' dir - list directory',13,10,' cls - clear screen',13,10,' ver - show version',13,10,' echo X - print text',13,10,' reboot - restart system',13,10,' mem - show memory size',13,10,' col X - change background color (0-4)',13,10,' mkdir X - create directory',13,10,' Hworld - runs the Hello World program',13,10,' shutdown - halts the system',13,10,0
version_msg db 'COMMANDOS-86 v1.01 by Art1kDev',13,10,0
dir_c db 'C:',13,10,0
mem_msg_prefix db 'Base memory: ',0
mem_msg_suffix db ' KB',13,10,0
color_map db 0, 4, 2, 1, 5
col_msg db 'Background color changed.',13,10,0
col_err_msg db 'Error: color must be 0-4.',13,10,0
mkdir_ok db 'Directory created.',13,10,0
mkdir_err db 'Error: specify directory name (e.g., mkdir myfolder).',13,10,0
mkdir_full db 'Error: directory list is full.',13,10,0

c_hworld db 'Hworld',0
c_help db 'help',0
c_dir db 'dir',0
c_cls db 'cls',0
c_ver db 'ver',0
c_echo db 'echo',0
c_reboot db 'reboot',0
c_mem db 'mem',0
c_col db 'col',0
c_mkdir db 'mkdir',0
c_shutdown db 'shutdown',0
current_attribute db 0x07
cmd times 80 db 0
dir_content_start:
dir_content_end dw dir_content_start
    times 256 db 0
msg_c db "Hello world!",13,10,0
