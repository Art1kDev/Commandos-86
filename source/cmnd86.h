#ifndef CMND86_H
#define CMND86_H

void cmnd86_putchar(char c, char attr);
void cmnd86_puts(const char* str, char attr);
void cmnd86_exit(int code);

#endif