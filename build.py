import os
import subprocess
import shutil
import sys
import shutil

NASM_EXECUTABLE = "nasm.exe"
SOURCE_DIR = "source"
BOOTLOADER_ASM = os.path.join(SOURCE_DIR, "bootloader.asm")
KERNEL_ASM = os.path.join(SOURCE_DIR, "kernel.asm")
BOOTLOADER_BIN = "bootloader.bin"
KERNEL_BIN = "kernel.bin"
IMAGE_NAME = "Commandos-86.img"
FLOPPY_SIZE_BYTES = 1474560

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NASM_PATH = os.path.join(SCRIPT_DIR, NASM_EXECUTABLE)

ASCII_ART = r"""
                   ..                                    
                  ::+=-.                                 
                 .-#+####+=:.                            
                :.++##########*-.       .                
                -.*=###############################+=-:- 
                .-#=###############################+#+.: 
                -.*######################%%%#######*#+-. 
                 +################################+*#--. 
                =*###############################**#- :  
               .+#**######################%#####**#+=:.  
               +**##%#+######*#######%####%%###+*#=...   
               ####%##-##%##+=*#%%%##%%%###%%#*#*=:..    
               *%##%++:+#%%#=.:=**%##%%%###%%%#- .:      
           .:. *###%==+*#%#*===+**##%%%%%###+=--:..      
          :...-=:#%%+:**--=:..-*#+%%%#%%%#*====.         
        .....-=-:+#%*............-##%%%%%#%@%%%%%+::     
       .:...=#%%%##%%............-#%%%%%%#%@%####+:.     
      .:..---=+*##*=*#:.........:+*#**%%%#@%%##*- .      
     .:...      .*-==@@@=.....-=%%++#%%%%%%%#=:==.       
    .:..:.      +###%@@#@@@*---=#%##%#-=#---==:          
    -....       -..#*:++=--=---=-+##+++.                 
   :.....     :=.   ::=: .:---:  .++=....                
  :.....--=:   :++  -=. .-.      :-.:...-                
  :.....-:.    .-#-:=. :-==:     =:--...=                
 :.....:+-. .:.-=*:=::*-::=*-   :-:::...++=:             
 -.....--:   :=::*:*+#*=-=*%#- .-:.     ::..:            
 :....-==-.  -..*=*##+--=#%###==::-.  .   :.             
 .::++++=.   -.+###+---:-+#####+-:**+++++-               
   .++++=-: .-.+##-::-:::-=*#######-:::-:.               
   -++++==- :=.+##=:--:::-=*%###%%+.  .  .               
   =++++=: .-- :*###*=---=#####%%==.     -               
  .*++++++=:-:=%%#############%%=.-.     :               
  .*+++++*+-=-*###############%%#--.                     
  .+++++++==:  .+##############%%%=:      .              
  .+++++*+=:   +#*+===++===+*#*#%+--.    ..              
   :++++==:   =###%###########%%@%=..      ..            
    :=++-    =#%%%%#######%%%%%%%%=.        .:           
            +#####%%%%#########%%%=:         .:          
           =##########%########%%%=-          ..         
          :*##################%%%%=-.         ..         
"""

LOG_BUFFER = []


def redraw():
    cols, rows = shutil.get_terminal_size()
    os.system("cls" if os.name == "nt" else "clear")

    for line in LOG_BUFFER:
        print(line)

    art_lines = ASCII_ART.strip("\n").split("\n")
    h = len(art_lines)
    w = max(len(l) for l in art_lines)

    space = rows - h - len(LOG_BUFFER) - 1
    if space > 0:
        print("\n" * space, end="")

    for line in art_lines:
        print(" " * max(cols - w - 1, 0) + line)


def log(msg):
    LOG_BUFFER.append(msg)
    redraw()


def run(command, err):
    try:
        log("> " + " ".join(command))
        r = subprocess.run(
            command,
            check=True,
            shell=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=SCRIPT_DIR,
            text=True
        )
        if r.stdout:
            log(r.stdout.strip())
        return True
    except subprocess.CalledProcessError as e:
        log("ERROR: " + err)
        if e.stderr:
            log(e.stderr.strip())
        return False
    except FileNotFoundError:
        log("ERROR: " + command[0] + " not found")
        return False


def ask_output():
    print("Enter output path relative to this script folder:")
    print("Example:")
    print("  " + IMAGE_NAME)
    print("  out\\" + IMAGE_NAME)
    print()
    p = input("Path: ").strip()
    redraw()

    if p == "":
        return os.path.join(SCRIPT_DIR, IMAGE_NAME)

    return os.path.join(SCRIPT_DIR, p)


def build():
    redraw()
    log("=== BUILD STARTED ===")

    out_path = ask_output()
    log("Output: " + out_path)

    if not os.path.exists(NASM_PATH):
        log("ERROR: nasm.exe not found")
        return

    if not run([NASM_PATH, "-f", "bin", BOOTLOADER_ASM, "-o", BOOTLOADER_BIN], "Bootloader build failed"):
        return

    if not run([NASM_PATH, "-f", "bin", KERNEL_ASM, "-o", KERNEL_BIN], "Kernel build failed"):
        return

    log("Merging...")
    try:
        with open(out_path, "wb") as o:
            shutil.copyfileobj(open(BOOTLOADER_BIN, "rb"), o)
            shutil.copyfileobj(open(KERNEL_BIN, "rb"), o)
    except Exception as e:
        log("ERROR: Failed to create image")
        log(str(e))
        return

    size = os.path.getsize(out_path)
    pad = FLOPPY_SIZE_BYTES - size
    if pad > 0:
        with open(out_path, "ab") as f:
            f.write(b"\x00" * pad)
        log("Padded to floppy size")

    for f in [BOOTLOADER_BIN, KERNEL_BIN]:
        if os.path.exists(f):
            os.remove(f)
            log("Deleted: " + f)

    log("=== BUILD COMPLETE ===")
    log("Created: " + out_path)


if __name__ == "__main__":
    os.chdir(SCRIPT_DIR)
    build()
