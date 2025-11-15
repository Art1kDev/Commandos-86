@echo off
chcp 65001 >nul
cls
cd /d "%~dp0"

echo                                                 .ooooo.       .ooo                      
echo                                                d88'   `8.   .88'                     
echo   .ooooo.   .ooooo.  ooo. .oo.  .oo.           Y88..  .8'  d88'        
echo  d88' `"Y8 d88' `88b `888P"Y88bP"Y88b           `88888b.  d888P"Ybo.    
echo  888       888   888  888   888   888  8888888 .8'  ``88b Y88[   ]88    
echo  888   .o8 888   888  888   888   888          `8.   .88P `Y88   88P    
echo  `Y8bod8P' `Y8bod8P' o888o o888o o888o          `boood8'   `88bod8'     
                                                                                                                                          
                                                                                                                                          
                                                                                                                                          

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

nasm.exe -f bin source/kernel.asm -o kernel.bin -I source/
if errorlevel 1 (
    echo ERROR: Failed to assemble kernel.asm
    pause
    exit /b 1
)

copy /b bootloader.bin + kernel.bin com86.img >nul
if errorlevel 1 (
    echo ERROR: Failed to create com86.img
    pause
    exit /b 1
)

fsutil file createnew temp_pad.img 1474560 >nul
copy /b commandos86.img + temp_pad.img commandos86_full.img >nul
del bootloader.bin kernel.bin temp_pad.img >nul 2>&1
ren commandos86_full.img commandos86.img >nul

echo SUCCESS: commandos86.img created
pause