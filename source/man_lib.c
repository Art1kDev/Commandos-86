#include "cmnd86.h"

void cmnd86_putchar(char c, char attr) {
    asm volatile (
        "mov ah, 0x0E\n\t"
        "mov al, %0\n\t"
        "mov bl, %1\n\t"
        "int 0x10"
        : 
        : "r" (c), "r" (attr)
        : "ax", "bx"
    );
}

void cmnd86_puts(const char* str, char attr) {
    while (*str) {
        if (*str == '\n') {
            cmnd86_putchar('\r', attr);
        }
        cmnd86_putchar(*str, attr);
        str++;
    }
}

void cmnd86_exit(int code) {
    asm volatile (
        "int $0x19"
    );
}