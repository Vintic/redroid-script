import lzma
import os
import shutil
from stuff.general import General
from tools.helper import bcolors, download_file, host, print_color, run, get_download_dir

class Frida(General):
    download_loc = get_download_dir()
    version = "17.9.9"
    arch_map = {
        "x86": "x86",
        "x86_64": "x86_64",
        "arm": "arm",
        "arm64": "arm64"
    }
    
    def __init__(self, android_version="11.0.0"):
        self.android_version = android_version
        self.machine = host()
        self.frida_arch = self.arch_map[self.machine[0]]
        self.dl_link = f"https://github.com/frida/frida/releases/download/{self.version}/frida-server-{self.version}-android-{self.frida_arch}.xz"
        self.dl_file_name = os.path.join(self.download_loc, f"frida-server-{self.version}-android-{self.frida_arch}.xz")
        self.extract_to = os.path.join(self.download_loc, f"frida-server-{self.version}-android-{self.frida_arch}")
        self.copy_dir = "./frida_overlay"
        self.bin_dir = os.path.join(self.copy_dir, "system", "bin")
        self.init_dir = os.path.join(self.copy_dir, "system", "etc", "init")

    def download(self):
        print_color(f"Downloading Frida-server {self.version} for {self.frida_arch} now .....", bcolors.GREEN)
        if os.path.isfile(self.dl_file_name):
            print_color(f"Using cached Frida: {self.dl_file_name}", bcolors.GREEN)
            return
        download_file(self.dl_link, self.dl_file_name)

    def extract(self):
        print_color("Extracting Frida-server...", bcolors.GREEN)
        if os.path.isfile(self.extract_to):
             return
        with lzma.open(self.dl_file_name) as f:
            with open(self.extract_to, 'wb') as out:
                shutil.copyfileobj(f, out)

    def copy(self):
        if os.path.exists(self.copy_dir):
            shutil.rmtree(self.copy_dir)
        
        os.makedirs(self.bin_dir, exist_ok=True)
        os.makedirs(self.init_dir, exist_ok=True)

        print_color("Deploying Frida-server...", bcolors.GREEN)
        dest_bin = os.path.join(self.bin_dir, "frida-server")
        shutil.copyfile(self.extract_to, dest_bin)
        run(["chmod", "755", dest_bin])

        # Create init.rc for Frida
        frida_rc = os.path.join(self.init_dir, "frida.rc")
        with open(frida_rc, "w") as f:
            f.write("""
service frida-server /system/bin/frida-server -l 0.0.0.0
    class core
    user root
    group root
    oneshot
""")
        
        print_color("Frida-server deployment scripts generated successfully.", bcolors.CYAN)

    def install(self):
        self.download()
        self.extract()
        self.copy()
