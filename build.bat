@echo off
chcp 65001 >nul
cls
cd /d "%~dp0"
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