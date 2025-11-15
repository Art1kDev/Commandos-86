#include "cmnd86.h"

void print_char(char c) {
    __asm {
        mov ah, 0x0E
        mov al, c
        mov bl, 0x07 
        int 0x10
    }
}

void main() {
    char* msg = "It's first programm made on C!\r\n";
    while (*msg) {
        print_char(*msg++);
    }
    __asm {
        jmp 0x7E00:0x0055 
    }
}