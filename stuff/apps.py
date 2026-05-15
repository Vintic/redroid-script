import os
import shutil
from stuff.general import General
from tools.helper import bcolors, print_color

class Apps(General):
    copy_dir = "./apps_overlay"
    apks_dir = "./apks"
    
    def __init__(self, android_version="13.0.0"):
        self.android_version = android_version

    def copy(self):
        if os.path.exists(self.copy_dir):
            shutil.rmtree(self.copy_dir)
        
        # 1. Install Chrome and Trichrome
        self.install_chrome()
        
        # 2. Install Air Canada
        self.install_aircanada()
        
        print_color("Apps deployment overlay generated successfully.", bcolors.CYAN)

    def install_chrome(self):
        print_color("Deploying Chrome Browser...", bcolors.GREEN)
        chrome_src = os.path.join(self.apks_dir, "chrome_apks")
        chrome_dest = os.path.join(self.copy_dir, "system", "app", "Chrome")
        os.makedirs(chrome_dest, exist_ok=True)
        
        # Copy Chrome splits
        for item in os.listdir(chrome_src):
            if item.endswith(".apk"):
                shutil.copy2(os.path.join(chrome_src, item), chrome_dest)
        
        # Assemble Trichrome Library from parts
        trichrome_parts_dir = os.path.join(chrome_src, "trichrome")
        trichrome_dest = os.path.join(self.copy_dir, "system", "app", "TrichromeLibrary")
        os.makedirs(trichrome_dest, exist_ok=True)
        target_apk = os.path.join(trichrome_dest, "TrichromeLibrary.apk")
        
        print_color("Assembling Trichrome Library from parts...", bcolors.GREEN)
        try:
            with open(target_apk, 'wb') as wfd:
                for part in ['base.apk.part_aa', 'base.apk.part_ab', 'base.apk.part_ac']:
                    part_path = os.path.join(trichrome_parts_dir, part)
                    if os.path.exists(part_path):
                        with open(part_path, 'rb') as rfd:
                            shutil.copyfileobj(rfd, wfd)
                    else:
                        raise FileNotFoundError(f"Missing part: {part}")
            print_color("Assembled Trichrome Library successfully.", bcolors.GREEN)
        except Exception as e:
            print_color(f"ERROR assembling Trichrome Library: {e}", bcolors.RED)

    def install_aircanada(self):
        print_color("Deploying Air Canada App...", bcolors.GREEN)
        ac_src = os.path.join(self.apks_dir, "aircanada_apks")
        ac_dest = os.path.join(self.copy_dir, "system", "app", "AirCanada")
        os.makedirs(ac_dest, exist_ok=True)
        
        # Copy Air Canada splits
        for item in os.listdir(ac_src):
            if item.endswith(".apk"):
                shutil.copy2(os.path.join(ac_src, item), ac_dest)

    def install(self):
        self.copy()
