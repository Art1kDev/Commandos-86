@echo off
chcp 65001 >nul
cls
cd /d "%~dp0"

echo  dP""b8  dP"Yb  8b    d8 .dP"o.   dP'       88""Yb 88   88 88 88     8888b.  888888 88""Yb
echo dP   `" dP   Yb 88b  d88 `8b.d' .d8'        88__dP 88   88 88 88      8I  Yb 88__   88__dP
echo Yb      Yb   dP 88YbdP88 d'`Y8b 8P"""Yb     88""Yb Y8   8P 88 88  .o  8I  dY 88""   88"Yb
echo  YboodP  YbodP  88 YY 88 `bodP' `YboodP     88oodP `YbodP' 88 88ood8 8888Y"  888888 88  Yb

if not exist nasm.exe (
    echo ERROR: nasm.exe not found!
    pause
    exit /b 1
)

nasm.exe -f bin source/bootloader.asm -o bootloader.bin
if errorlevel 1 (
    echo ERROR: Failed to assemble bootloader.asm
    pause
    exit /b 1
)

nasm.exe -f bin source/kernel.asm -o kernel.bin
if errorlevel 1 (
    echo ERROR: Failed to assemble kernel.asm
    pause
    exit /b 1
)

copy /b bootloader.bin + kernel.bin commandos86.img >nul
if errorlevel 1 (
    echo ERROR: Failed to create commandos86.img
    pause
    exit /b 1
)

fsutil file createnew temp_pad.img 1474560 >nul
copy /b commandos86.img + temp_pad.img commandos86_full.img >nul
del bootloader.bin kernel.bin temp_pad.img >nul 2>&1
ren commandos86_full.img commandos86.img >nul

echo SUCCESS: commandos86.img created
pause
