; Made on Netwide Assembler
; Author: Art1kDev
; COMMANDOS-86 v2.00
;
; Minimal 16-bit x86 OS in NASM. Real mode, loads at 0x7E00.
; 80x25 text mode, command shell, in-memory FS (1020 bytes).
;
; Commands: help, dir, cls, info, echo, reboot, mem, col, mkdir, del, ren, copy, type, edit, -doc, shutdown
; .txt support: edit (edit), rename (ren), view (-doc/type), copy
; dir lists names only — no content in console
; File content never leaks to command line
; Full-screen editor/viewer with colors
; 1 char = 10 bits (logical), 1 byte in memory
;
; Educational: BIOS, strings, memory, FS basics
; No DOS, no external libraries
;
; v2.00 | November 15, 2025 | Netherlands
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
	cmp ah, 0x01
	je main_loop
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
	mov di, c_del
	call strcmp_prefix
	jc do_del
	mov di, c_shutdown
	call strcmp
	jc do_shutdown
	mov di, c_edit
	call strcmp_prefix
	jc do_edit
	mov di, c_ren
	call strcmp_prefix
	jc do_ren
	mov di, c_doc
	call strcmp_prefix
	jc do_doc
	mov di, c_copy
	call strcmp_prefix
	jc do_copy
	mov di, c_type
	call strcmp_prefix
	jc do_type
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
	je dir_empty
	mov si, dir_content_start
	call print_dir_names
	jmp main_loop
dir_empty:
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
	jz echo_empty
	mov cx, 70
echo_loop:
	lodsb
	test al, al
	jz echo_done
	cmp cx, 0
	je echo_done
	mov ah, 0x0E
	mov bl, [current_attribute]
	int 0x10
	dec cx
	jmp echo_loop
echo_done:
	call nl
	jmp main_loop
echo_empty:
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
	jb col_error
	cmp al, '4'
	ja col_error
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
col_error:
	mov si, col_err_msg
	call print
	jmp main_loop
do_mkdir:
	mov si, cmd
	add si, 6
	call skip_space
	cmp byte [si], 0
	je mkdir_no_name
	mov di, [dir_content_end]
	cmp di, dir_content_start + 1020
	jae mkdir_full_error
mkdir_copy:
	lodsb
	cmp al, 0
	je mkdir_done_copy
	cmp al, ' '
	je mkdir_done_copy
	cmp di, dir_content_start + 1020
	jae mkdir_done_copy
	stosb
	jmp mkdir_copy
mkdir_done_copy:
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
mkdir_no_name:
	mov si, mkdir_err
	call print
	jmp main_loop
mkdir_full_error:
	mov si, mkdir_full
	call print
	jmp main_loop
get_random:
	push dx
	push cx
	mov ah, 0x00
	mov al, 0x00
	int 0x1A
	mov ax, dx
	pop cx
	pop dx
	ret
do_del:
	mov si, cmd
	add si, 4
	call skip_space
	mov di, temp_filename
	call extract_arg
	cmp byte [temp_filename], 0
	je del_no_name
	mov si, temp_filename
	call find_file_in_dir
	jnc del_not_found
	push di
	mov si, di
	call skip_file_block
	mov bx, si
	pop di
	mov cx, [dir_content_end]
	sub cx, bx
	push si
	push ax
	push es
	push ds
	mov si, bx
	mov ax, cs
	mov ds, ax
	mov es, ax
	rep movsb
	pop ds
	pop es
	pop ax
	pop si
	mov ax, [dir_content_end]
	sub ax, bx
	add ax, di
	mov [dir_content_end], ax
	mov si, del_ok
	call print
	jmp main_loop
del_no_name:
	mov si, del_err
	call print
	jmp main_loop
del_not_found:
	mov si, not_found_msg
	call print
	jmp main_loop
do_shutdown:
	mov si, shutdown_msg
	call print
	cli
	hlt
do_edit:
	mov si, cmd
	add si, 5
	call skip_space
	mov di, notepad_filename
	mov cx, 13
	xor al, al
	rep stosb
	mov di, notepad_filename
	cmp byte [si], 0
	je edit_no_arg
	call copy_filename
edit_no_arg:
	mov ah, 0x06
	mov al, 0x00
	mov cx, 0x0000
	mov dx, 0x184f
	mov bh, 0x1F
	int 0x10
	mov ah, 0x02
	mov bh, 0x00
	mov dh, 0x00
	mov dl, 0x00
	int 0x10
	mov si, edit_guide1
	call print
	mov si, edit_guide2
	call print
	mov si, edit_guide3
	call print
	mov di, notepad_buffer
	mov cx, 2048
	xor al, al
	rep stosb
	mov di, notepad_buffer
	cmp byte [notepad_filename], 0
	je edit_input
	call find_file_in_dir
	jnc edit_input
	mov si, di
	call load_file_content
edit_input:
	mov ah, 0x00
	int 0x16
	cmp ah, 0x01
	je edit_save_exit
	cmp al, 27
	je edit_save_exit
	cmp al, 13
	je edit_enter
	cmp al, 8
	je edit_backspace
	cmp di, notepad_buffer + 2047
	jae edit_input
	mov byte [di], al
	mov ah, 0x0E
	mov bl, 0x1F
	int 0x10
	inc di
	jmp edit_input
edit_enter:
	mov ah, 0x0E
	mov al, 13
	mov bl, 0x1F
	int 0x10
	mov al, 10
	int 0x10
	inc di
	mov byte [di], 10
	inc di
	jmp edit_input
edit_backspace:
	cmp di, notepad_buffer
	je edit_input
	dec di
	mov byte [di], 0
	mov ah, 0x0E
	mov al, 8
	mov bl, 0x1F
	int 0x10
	mov al, ' '
	int 0x10
	mov al, 8
	int 0x10
	jmp edit_input
edit_save_exit:
	cmp byte [notepad_filename], 0
	jne edit_save_existing
	mov si, save_prompt
	call print
	mov di, temp_filename
	mov cx, 13
	xor al, al
	rep stosb
	mov di, temp_filename
edit_save_input:
	mov ah, 0x00
	int 0x16
	cmp al, 13
	je edit_save_done
	cmp al, 8
	je edit_save_backspace
	cmp di, temp_filename + 12
	jae edit_save_input
	mov ah, 0x0E
	mov bl, 0x1F
	int 0x10
	stosb
	jmp edit_save_input
edit_save_backspace:
	cmp di, temp_filename
	je edit_save_input
	dec di
	mov ah, 0x0E
	mov al, 8
	mov bl, 0x1F
	int 0x10
	mov al, ' '
	int 0x10
	mov al, 8
	int 0x10
	jmp edit_save_input
edit_save_done:
	mov byte [di], 0
	mov si, temp_filename
	mov di, notepad_filename
	call copy_string
	call nl
edit_save_existing:
	mov si, notepad_filename
	call find_file_in_dir
	jnc edit_save_new
	push di
	mov si, di
	call skip_file_block
	mov bx, si
	pop di
	mov cx, [dir_content_end]
	sub cx, bx
	push si 	
	push ax
	push es
	push ds
	mov si, bx
	mov ax, cs
	mov ds, ax
	mov es, ax
	rep movsb
	pop ds
	pop es
	pop ax
	pop si
	mov ax, [dir_content_end]
	sub ax, bx
	add ax, di
	mov [dir_content_end], ax
edit_save_new:
	mov di, [dir_content_end]
	cmp di, dir_content_start + 1020
	jae edit_save_full
	mov si, notepad_filename
	call copy_filename_to_dir
	mov al, 13
	stosb
	mov al, 10
	stosb
	mov si, notepad_buffer
	mov cx, 2048
edit_save_content:
	lodsb
	test al, al
	jz edit_save_done_content
	cmp di, dir_content_start + 1020
	jae edit_save_done_content
	stosb
	loop edit_save_content
edit_save_done_content:
	mov al, 0
	stosb
	mov [dir_content_end], di
	mov si, save_ok
	call print
	jmp edit_exit
edit_save_full:
	mov si, save_full_msg
	call print
	jmp edit_exit
edit_exit:
	mov di, notepad_buffer
	mov cx, 2048
	xor al, al
	rep stosb
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
do_ren:
	mov si, cmd
	add si, 4
	call skip_space
	mov di, old_name
	call extract_arg
	mov si, cmd
	add si, 4
	call skip_space
	call skip_word
	call skip_space
	mov di, new_name
	call extract_arg
	call rename_file
	mov si, ren_ok
	call print
	jmp main_loop
do_copy:
	mov si, cmd
	add si, 5
	call skip_space
	mov di, old_name
	call extract_arg
	mov si, cmd
	add si, 5
	call skip_space
	call skip_word
	call skip_space
	mov di, new_name
	call extract_arg
	mov si, old_name
	call find_file_in_dir
	jnc copy_not_found
	mov si, di
	call skip_line
	push si
	mov di, copy_buffer
	mov cx, 2048
copy_content_loop:
	lodsb
	test al, al
	jz copy_content_done
	stosb
	loop copy_content_loop
copy_content_done:
	mov byte [di], 0
	pop si
	mov di, [dir_content_end]
	cmp di, dir_content_start + 1020
	jae copy_full
	mov si, new_name
	call copy_filename_to_dir
	mov al, 13
	stosb
	mov al, 10
	stosb
	mov si, copy_buffer
copy_save_content:
	lodsb
	test al, al
	jz copy_save_done
	cmp di, dir_content_start + 1020
	jae copy_save_done
	stosb
	jmp copy_save_content
copy_save_done:
	mov al, 0
	stosb
	mov [dir_content_end], di
	mov si, copy_ok
	call print
	jmp main_loop
copy_full:
	mov si, save_full_msg
	call print
	jmp main_loop
copy_not_found:
	mov si, not_found_msg
	call print
	jmp main_loop
do_type:
	mov si, cmd
	add si, 5
	call skip_space
	mov di, notepad_filename
	mov cx, 13
	xor al, al
	rep stosb
	mov di, notepad_filename
	call copy_filename
	cmp byte [notepad_filename], 0
	je type_exit
	call find_file_in_dir
	jnc type_not_found
	call skip_line
	mov si, di
	call print_file_content
	jmp type_exit
type_not_found:
	mov si, not_found_msg
	call print
type_exit:
	call nl
	jmp main_loop
do_doc:
	mov si, cmd
	add si, 5
	call skip_space
	mov di, notepad_filename
	mov cx, 13
	xor al, al
	rep stosb
	mov di, notepad_filename
	call copy_filename
	cmp byte [notepad_filename], 0
	je doc_exit
	mov ah, 0x06
	mov al, 0x00
	mov cx, 0x0000
	mov dx, 0x184f
	mov bh, 0x1F
	int 0x10
	mov ah, 0x02
	mov bh, 0x00
	mov dh, 0x00
	mov dl, 0x00
	int 0x10
	call find_file_in_dir
	jnc doc_exit
	call skip_line
	mov si, di
	call print_file_content_full
doc_exit:
	mov ah, 0x00
	int 0x16
	mov ah, 0x06
	mov al, 0x00
	mov cx, 0x0000
	mov dx, 0x184f
	mov bh, [current_attribute]
	int 0x10
	mov ah, 0x02
	mov bh, 0x00
	mov dl, 0x00
	int 0x10
	jmp main_loop
print_file_content:
	lodsb
	test al, al
	jz print_file_done
	cmp al, 10
	je print_file_nl
	mov ah, 0x0E
	mov bl, [current_attribute]
	int 0x10
	jmp print_file_content
print_file_nl:
	call nl
	jmp print_file_content
print_file_done:
	ret
print_file_content_full:
	lodsb
	test al, al
	jz print_file_done_full
	cmp al, 10
	je print_file_nl_full
	mov ah, 0x0E
	mov bl, 0x1F
	int 0x10
	jmp print_file_content_full
print_file_nl_full:
	call nl
	jmp print_file_content_full
print_file_done_full:
	ret
print_dir_names:
	push si
dir_names_loop:
	lodsb
	test al, al
	jz dir_names_done
	cmp al, 13
	je dir_names_loop
	cmp al, 10
	je dir_names_nl
	mov ah, 0x0E
	mov bl, [current_attribute]
	int 0x10
	jmp dir_names_loop
dir_names_nl:
	call nl
	jmp dir_names_loop
dir_names_done:
	pop si
	ret
skip_space:
	lodsb
	cmp al, ' '
	je skip_space
	dec si
	ret
skip_word:
	lodsb
	cmp al, ' '
	je skip_word_done
	cmp al, 0
	jne skip_word
skip_word_done:
	dec si
	ret
copy_filename:
	mov cx, 13
copy_filename_loop:
	lodsb
	cmp al, ' '
	je copy_filename_done
	cmp al, 0
	je copy_filename_done
	stosb
	loop copy_filename_loop
copy_filename_done:
	mov byte [di], 0
	ret
copy_filename_to_dir:
	mov cx, 13
copy_to_dir_loop:
	lodsb
	test al, al
	jz copy_to_dir_done
	cmp al, ' '
	je copy_to_dir_done
	stosb
	loop copy_to_dir_loop
copy_to_dir_done:
	ret
extract_arg:
	mov cx, 13
extract_loop:
	lodsb
	cmp al, ' '
	je extract_done
	cmp al, 0
	je extract_done
	stosb
	loop extract_loop
extract_done:
	mov byte [di], 0
	ret
find_file_in_dir:
	push si
	mov si, dir_content_start
find_loop:
	cmp si, [dir_content_end]
	jae find_not_found
	mov di, si
	call strcmp_filename
	jc find_found
	push si
	mov si, di
	call skip_file_block
	mov si, di
	pop di
	mov si, di
	jmp find_loop
find_not_found:
	pop si
	clc
	ret
find_found:
	pop si
	stc
	ret
strcmp_filename:
	push si
	push di
	mov cx, 13
strcmp_filename_loop:
	lodsb
	mov ah, [di]
	inc di
	cmp al, ah
	jne strcmp_filename_no
	test al, al
	jz strcmp_filename_match_end
	cmp ah, 13
	je strcmp_filename_match_end
	loop strcmp_filename_loop
strcmp_filename_match_end:
	cmp ah, 13
	je strcmp_filename_yes
	cmp ah, 10
	je strcmp_filename_yes
	cmp ah, '/'
	je strcmp_filename_yes
	jmp strcmp_filename_no
strcmp_filename_yes:
	pop di
	pop si
	stc
	ret
strcmp_filename_no:
	pop di
	pop si
	clc
	ret
skip_line:
	lodsb
	cmp al, 10
	jne skip_line
	ret
skip_file_block:
skip_block_name:
	lodsb
	cmp al, 10
	jne skip_block_name
skip_block_content:
	lodsb
	test al, al
	jnz skip_block_content
	ret
load_file_content:
	call skip_line
	mov di, notepad_buffer
	mov cx, 2048
load_loop:
	lodsb
	test al, al
	jz load_done
	cmp al, 10
	je load_store
	cmp al, 13
	je load_loop
	cmp cx, 1
	je load_done
	stosb
	dec cx
	jmp load_loop
load_store:
	mov al, 10
	stosb
	dec cx
	jmp load_loop
load_done:
	mov byte [di], 0
	ret
rename_file:
	mov si, old_name
	call find_file_in_dir
	jnc rename_exit
	push di
	mov di, si
	call skip_line
	pop si
	mov di, si
	mov si, new_name
	call copy_filename_to_dir
rename_exit:
	ret
copy_string:
	lodsb
	test al, al
	jz copy_string_done
	stosb
	jmp copy_string
copy_string_done:
	ret
strcmp_prefix:
	push si
	push di
strcmp_prefix_loop:
	lodsb
	mov ah, [di]
	inc di
	test ah, ah
	jz strcmp_prefix_match
	cmp al, ah
	jne strcmp_prefix_no
	jmp strcmp_prefix_loop
strcmp_prefix_match:
	pop di
	pop si
	stc
	ret
strcmp_prefix_no:
	pop di
	pop si
	clc
	ret
strcmp:
	push si
	push di
strcmp_loop:
	lodsb
	mov ah, [di]
	inc di
	cmp al, ah
	jne strcmp_no
	test al, al
	jnz strcmp_loop
	pop di
	pop si
	stc
	ret
strcmp_no:
	pop di
	pop si
	clc
	ret
print:
	lodsb
	test al, al
	jz print_done
	cmp al, 13
	je print
	cmp al, 0x0A
	je print_nl
	mov ah, 0x0E
	mov bl, [current_attribute]
	int 0x10
	jmp print
print_nl:
	call nl
	jmp print
print_done:
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
	je nl_scroll
	inc dh
	mov ah, 0x02
	mov bh, 0x00
	mov dl, 0x00
	int 0x10
	ret
nl_scroll:
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
	jnz print_dec_divide
	mov al, '0'
	mov ah, 0x0E
	mov bl, [current_attribute]
	int 0x10
	jmp print_dec_done
print_dec_divide:
	xor dx, dx
	div bx
	push dx
	inc cx
	test ax, ax
	jnz print_dec_divide
print_dec_print:
	pop dx
	add dl, '0'
	mov ah, 0x0E
	mov al, dl
	mov bl, [current_attribute]
	int 0x10
	loop print_dec_print
print_dec_done:
	pop dx
	pop cx
	pop bx
	pop ax
	ret
char_to_num:
	push bx
	push cx
	push si
	mov ax, 0
	mov dx, 0
	mov bx, 10
	mov cx, 0
.c2n_loop:
	lodsb
	cmp al, '0'
	jb .c2n_done
	cmp al, '9'
	ja .c2n_done
	sub al, '0'
	push ax
	mov ax, dx
	mul bx
	pop cx
	add ax, cx
	mov dx, ax
	jmp .c2n_loop
.c2n_done:
	mov ax, dx
	pop si
	pop cx
	pop bx
	ret
init_fs:
	mov word [dir_content_end], dir_content_start
	mov si, initial_dir_content
	mov di, dir_content_start
init_copy:
	lodsb
	test al, al
	jz init_done
	stosb
	jmp init_copy
init_done:
	mov [dir_content_end], di
	ret
initial_dir_content db ' document/',13,10,0, ' note1.txt',13,10,'Test content',13,10,0
empty_dir_msg db ' <DIR> (empty)',13,10,0
banner db 'By Art1kDev. Made on Netwide Assembler',13,10,0
welcome db 'COMMANDOS-86 v2.00',13,10,'Type "help" for commands.',13,10,0
prompt_str db 'C:>',0
not_found db 'Not found command',13,10,0
not_found_msg db 'File not found.',13,10,0
reboot_msg db 'Rebooting...',13,10,0
shutdown_msg db 'System shutting down...',13,10,0
help_msg db 'Available commands:',13,10,13,10,' help - Show this list',13,10,' dir - List files and directories',13,10,' cls - Clear the screen',13,10,' ver - Show OS version information',13,10,' echo [text] - Display text on screen',13,10,' reboot - Restart the system',13,10,' mem - Display base memory size (KB)',13,10,' col [0-4] - Change background color',13,10,' mkdir [name] - Create a new directory',13,10,' del [file] - Delete a file or directory',13,10,' ren [old] [new] - Rename a file',13,10,' copy [src] [dst] - Copy file content',13,10,' type [file] - View file content in console',13,10,' edit [file] - Open file in full-screen editor (F1/ESC to save)',13,10,' -doc [file] - View file in full-screen reader',13,10,' shutdown - Power off the system',13,10,0
version_msg db 'COMMANDOS-86 v2.00 by Art1kDev',13,10,0
dir_c db 'C:',13,10,0
mem_msg_prefix db 'Base memory: ',0
mem_msg_suffix db ' KB',13,10,0
color_map db 0, 4, 2, 1, 5
col_msg db 'Background color changed.',13,10,0
col_err_msg db 'Error: color must be 0-4.',13,10,0
mkdir_ok db 'Directory created.',13,10,0
mkdir_err db 'Error: specify directory name.',13,10,0
mkdir_full db 'Error: storage full.',13,10,0
save_prompt db 'Save as: ',0
save_ok db 'File saved.',13,10,0
save_full_msg db 'Error: storage full.',13,10,0
ren_ok db 'File renamed.',13,10,0
del_ok db 'File deleted.',13,10,0
del_err db 'Error: Specify file name.',13,10,0
copy_ok db 'File copied.',13,10,0
edit_guide1 db ' EDIT - F1/ESC: Save & Exit | ENTER: New line | BACKSPACE: Delete',13,10,0
edit_guide2 db ' Max 2047 chars. Type your text below.',13,10,0
edit_guide3 db '-------------------------------------------------------------------------------',13,10,0
c_help db 'help',0
c_dir db 'dir',0
c_cls db 'cls',0
c_ver db 'ver',0
c_echo db 'echo',0
c_reboot db 'reboot',0
c_mem db 'mem',0
c_col db 'col',0
c_mkdir db 'mkdir',0
c_del db 'del',0
c_shutdown db 'shutdown',0
c_edit db 'edit',0
c_ren db 'ren',0
c_doc db '-doc',0
c_copy db 'copy',0
c_type db 'type',0
current_attribute db 0x07
cmd times 80 db 0
dir_content_start:
dir_content_end dw dir_content_start
times 1024 db 0
notepad_buffer times 2048 db 0
copy_buffer times 2048 db 0
notepad_filename times 13 db 0
temp_filename times 13 db 0
old_name times 13 db 0
new_name times 13 db 0
num1_char db 0
num2_char db 0
op_char db 0
word_val dw 0