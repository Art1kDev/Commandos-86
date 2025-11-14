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
    mov di, c_date
    call strcmp
    jc do_date
    ; Команда col скрыта из логики проверки команд
    ; mov di, c_col
    ; call strcmp_prefix
    ; jc do_col
    mov di, c_shutdown
    call strcmp
    jc do_shutdown
    mov si, not_found
    call print
    call nl
    jmp main_loop

do_help:
    mov si, help_msg
    call print
    call nl
    jmp main_loop

do_dir:
    mov si, dir_c
    call print
    call nl
    mov si, dir_doc
    call print
    call nl
    jmp main_loop

do_cls:
    mov ax, 0x0003
    int 0x10
    jmp main_loop

do_ver:
    mov si, version_msg
    call print
    call nl
    jmp main_loop

do_echo:
    mov si, cmd
    add si, 5
    call skip_space
    test byte [si], 0xFF
    jz .empty
    call print
    call nl
    jmp main_loop
.empty:
    call nl
    jmp main_loop

do_reboot:
    mov si, reboot_msg
    call print
    call nl
    jmp 0xFFFF:0x0000

do_date:
    mov si, date_msg
    call print
    call nl
    jmp main_loop

; ФУНКЦИЯ COL ОСТАВЛЕНА, НО ВЫКЛЮЧЕНА ИЗ ГЛАВНОГО МЕНЮ
do_col:
    mov si, cmd
    add si, 4
    call skip_space
    lodsb
    sub al, '0'
    cmp al, 4
    ja .error
    
    mov bl, al
    mov bh, 0
    mov al, [color_map + bx]
    
    shl al, 4
    or al, 0x07
    mov bh, al
    
    mov byte [current_attribute], al
    
    mov ah, 0x06
    mov al, 0x00
    mov cx, 0x0000
    mov dx, 0x184f
    int 0x10

    mov si, col_msg
    call print
    call nl
    jmp main_loop
.error:
    mov si, col_err_msg
    call print
    call nl
    jmp main_loop

do_shutdown:
    mov si, shutdown_msg
    call print
    call nl
    cli
    hlt

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

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bl, [current_attribute]
    int 0x10
    jmp print
.done:
    ret

nl:
    mov ah, 0x0E
    mov al, 13
    mov bl, [current_attribute]
    int 0x10
    mov al, 10
    int 0x10
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

init_fs:
    ret

banner        db 'By Art1kDev. Made on Netwide Assembler',13,10,0
welcome       db 'COMMANDOS-86 v1.00',13,10,'Type "help" for commands.',13,10,0
prompt_str    db 'C:>',0
not_found     db 'Not found command',13,10,0
reboot_msg    db 'Rebooting...',13,10,0
shutdown_msg  db 'System shutting down...',13,10,0

help_msg      db 'Available commands:',13,10
              db '  help     - show this message',13,10
              db '  dir      - list directory',13,10
              db '  cls      - clear screen',13,10
              db '  ver      - show version',13,10
              db '  echo X   - print text',13,10
              db '  reboot   - restart system',13,10
              db '  date     - show date',13,10
              db '  shutdown - halts the system',13,10,0

version_msg   db 'COMMANDOS-86 v1.00 by Art1kDev',13,10,0

dir_c         db 'C:',13,10,0
dir_doc       db '  document/',13,10,0

date_msg      db 'Current date: 14/11/2025',13,10,0

color_map     db 0, 4, 2, 1, 5
col_msg       db 'Background color changed.',13,10,0
col_err_msg   db 'Error: color must be 0-4.',13,10,0

c_help        db 'help',0
c_dir         db 'dir',0
c_cls         db 'cls',0
c_ver         db 'ver',0
c_echo        db 'echo',0
c_reboot      db 'reboot',0
c_date        db 'date',0
c_col         db 'col',0
c_shutdown    db 'shutdown',0

current_attribute db 0x07
cmd           times 80 db 0