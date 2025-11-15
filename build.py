import os
import subprocess
import shutil
import sys
import tkinter as tk
from tkinter import scrolledtext, filedialog, ttk
import threading
from PIL import Image, ImageTk

NASM_EXECUTABLE = "nasm.exe"
SOURCE_DIR = "source"
BOOTLOADER_ASM = os.path.join(SOURCE_DIR, "bootloader.asm")
KERNEL_ASM = os.path.join(SOURCE_DIR, "kernel.asm")
BOOTLOADER_BIN = "bootloader.bin"
KERNEL_BIN = "kernel.bin"
IMAGE_NAME_DEFAULT = "com86.img"
FLOPPY_SIZE_BYTES = 1474560
IMAGE_FILE = "Image.png"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NASM_PATH = os.path.join(SCRIPT_DIR, NASM_EXECUTABLE)


class BuilderApp:
    def __init__(self, master):
        self.master = master
        master.title("Commandos-86 OS Builder")
        master.geometry("640x480")
        master.resizable(False, False)

        BG_COLOR = "#2e2e2e"
        FG_COLOR = "#cccccc"
        ERROR_COLOR = "#ff5555"
        SUCCESS_COLOR = "#50fa7b"

        master.config(bg=BG_COLOR)

        self.output_path = tk.StringVar(value=os.path.join(SCRIPT_DIR, IMAGE_NAME_DEFAULT))

        main_frame = tk.Frame(master, bg=BG_COLOR)
        main_frame.pack(fill='both', expand=True, padx=10, pady=10)

        controls_frame = tk.Frame(main_frame, bg=BG_COLOR)
        controls_frame.pack(fill='x', pady=(0, 5))

        log_image_frame = tk.Frame(main_frame, bg=BG_COLOR)
        log_image_frame.pack(fill='both', expand=True)

        tk.Label(controls_frame, text="Output Image:", width=12, anchor='w', fg=FG_COLOR, bg=BG_COLOR).pack(side=tk.LEFT)
        self.entry_path = tk.Entry(controls_frame, textvariable=self.output_path, width=50, bg="#3c3c3c", fg=FG_COLOR, insertbackground=FG_COLOR)
        self.entry_path.pack(side=tk.LEFT, fill='x', expand=True, padx=(0, 5))

        self.browse_button = ttk.Button(controls_frame, text="Browse...", command=self.ask_output_path)
        self.browse_button.pack(side=tk.RIGHT)

        self.build_button = ttk.Button(main_frame, text="Start Build (Собрать)", command=self.start_build_thread, style='Accent.TButton')
        self.build_button.pack(fill='x', pady=(0, 5))

        self.log_text = scrolledtext.ScrolledText(log_image_frame, height=15, state='disabled', font=('Consolas', 9), bg="#1e1e1e", fg=FG_COLOR, insertbackground=FG_COLOR)
        self.log_text.pack(side=tk.RIGHT, fill='both', expand=True)

        self.image_label = tk.Label(log_image_frame, bg=BG_COLOR)
        self.image_label.pack(side=tk.LEFT, anchor='sw')
        self.load_image(IMAGE_FILE)

        self.tk_log("Ready to build Commandos-86 OS image.")
        self.tk_log(f"Required tools: {NASM_EXECUTABLE} (in script directory).")

        try:
            style = ttk.Style(master)
            style.theme_use('vista')
            style.configure('.', background=BG_COLOR, foreground=FG_COLOR)
            style.configure('Accent.TButton', foreground='black', background=SUCCESS_COLOR, font=('Arial', 10, 'bold'))
            style.map('Accent.TButton', background=[('active', '#33cc55')])
        except tk.TclError:
            pass

        self.log_text.tag_config('error', foreground=ERROR_COLOR)
        self.log_text.tag_config('success', foreground=SUCCESS_COLOR)
        self.log_text.tag_config('normal', foreground=FG_COLOR)

    def load_image(self, file_path):
        full_path = os.path.join(SCRIPT_DIR, file_path)
        if os.path.exists(full_path):
            try:
                img = Image.open(full_path)
                max_size = (150, 150)
                img.thumbnail(max_size, Image.Resampling.LANCZOS)

                self.tk_img = ImageTk.PhotoImage(img)
                self.image_label.config(image=self.tk_img)
                self.tk_log(f"Image '{file_path}' loaded successfully.")
            except Exception as e:
                self.tk_log(f"Warning: Failed to load image '{file_path}': {e}", is_error=True)
        else:
            self.tk_log(f"Note: Image file '{file_path}' not found.", is_error=False)


    def tk_log(self, msg, is_error=False, is_success=False):
        tag = 'error' if is_error else ('success' if is_success else 'normal')

        self.log_text.config(state='normal')
        self.log_text.insert(tk.END, msg + "\n", tag)
        self.log_text.see(tk.END)
        self.log_text.config(state='disabled')
        self.master.update()


    def run_nasm(self, command, error_msg):
        self.tk_log("> " + " ".join(command))

        try:
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
                self.tk_log(r.stdout.strip())
            return True
        except subprocess.CalledProcessError as e:
            self.tk_log("ERROR: " + error_msg, is_error=True)
            if e.stderr:
                self.tk_log(e.stderr.strip(), is_error=True)
            return False
        except FileNotFoundError:
            self.tk_log(f"ERROR: '{command[0]}' not found. Place {NASM_EXECUTABLE} in the script directory.", is_error=True)
            return False

    def ask_output_path(self):
        initial_path = self.output_path.get()
        initial_dir = os.path.dirname(initial_path) if os.path.exists(os.path.dirname(initial_path)) else SCRIPT_DIR
        initial_file = os.path.basename(initial_path) if initial_path else IMAGE_NAME_DEFAULT

        path = filedialog.asksaveasfilename(
            defaultextension=".img",
            initialdir=initial_dir,
            initialfile=initial_file,
            filetypes=[("Disk Image Files", "*.img"), ("All Files", "*.*")]
        )

        if path:
            self.output_path.set(path)
            self.tk_log(f"Output path selected: {path}")

    def start_build_thread(self):
        self.log_text.config(state='normal')
        self.log_text.delete('1.0', tk.END)
        self.log_text.config(state='disabled')

        self.tk_log("=== BUILD STARTED ===")
        self.build_button.config(state='disabled')
        self.browse_button.config(state='disabled')

        threading.Thread(target=self._build_process).start()

    def _build_process(self):
        out_path = self.output_path.get()
        if not out_path:
            self.tk_log("ERROR: Output path is empty.", is_error=True)
            self._cleanup_buttons()
            return

        self.tk_log(f"Target file: {out_path}")

        if not os.path.exists(NASM_PATH):
            self.tk_log(f"ERROR: {NASM_EXECUTABLE} not found at {NASM_PATH}", is_error=True)
            self._cleanup_buttons()
            return

        if not self.run_nasm([NASM_PATH, "-f", "bin", BOOTLOADER_ASM, "-o", BOOTLOADER_BIN], "Bootloader build failed"):
            self._cleanup_and_finish()
            return

        if not self.run_nasm([NASM_PATH, "-f", "bin", KERNEL_ASM, "-o", KERNEL_BIN], "Kernel build failed"):
            self._cleanup_and_finish()
            return

        self.tk_log("Merging bootloader and kernel...")
        success = False
        try:
            with open(out_path, "wb") as o:
                with open(BOOTLOADER_BIN, "rb") as b:
                    shutil.copyfileobj(b, o)
                with open(KERNEL_BIN, "rb") as k:
                    shutil.copyfileobj(k, o)
            success = True
        except Exception as e:
            self.tk_log("ERROR: Failed to create image file.", is_error=True)
            self.tk_log(str(e), is_error=True)
            success = False

        if success:
            size = os.path.getsize(out_path)
            pad = FLOPPY_SIZE_BYTES - size
            if pad > 0:
                with open(out_path, "ab") as f:
                    f.write(b"\x00" * pad)
                self.tk_log(f"Padded to floppy size ({FLOPPY_SIZE_BYTES} bytes).")
                self.tk_log(f"Final image size: {os.path.getsize(out_path)} bytes.")
            else:
                self.tk_log("No padding needed (Image size > Floppy size).")

            self.tk_log("=== BUILD COMPLETE ===", is_success=True)
            self.tk_log(f"Successfully created: **{out_path}**", is_success=True)

        self._cleanup_and_finish()

    def _cleanup_buttons(self):
        self.build_button.config(state='normal')
        self.browse_button.config(state='normal')
        self.tk_log("--- READY ---")


    def _cleanup_and_finish(self):
        for f in [BOOTLOADER_BIN, KERNEL_BIN]:
            full_path = os.path.join(SCRIPT_DIR, f)
            if os.path.exists(full_path):
                try:
                    os.remove(full_path)
                    self.tk_log("Deleted temporary file: " + f)
                except Exception as e:
                    self.tk_log(f"Warning: Failed to delete {f}: {e}", is_error=True)

        self._cleanup_buttons()


if __name__ == "__main__":
    try:
        from PIL import Image, ImageTk
    except ImportError:
        print("Error: Pillow library (PIL) is required for image support.")
        print("Please install it using: pip install pillow")
        sys.exit(1)

    os.chdir(SCRIPT_DIR)

    root = tk.Tk()
    app = BuilderApp(root)

    root.mainloop()
