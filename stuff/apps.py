import os
import shutil
from stuff.general import General
from tools.helper import bcolors, print_color, run

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
        
        # 3. Install FitPass
        self.install_fitpass()
        
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

    def install_fitpass(self):
        print_color("Deploying FitPass App and data...", bcolors.GREEN)
        fp_src = os.path.join(self.apks_dir, "fitpass_apks")
        fp_dest = os.path.join(self.copy_dir, "system", "app", "FitPass")
        os.makedirs(fp_dest, exist_ok=True)
        
        # Copy FitPass splits
        if os.path.exists(fp_src):
            for item in os.listdir(fp_src):
                if item.endswith(".apk"):
                    shutil.copy2(os.path.join(fp_src, item), fp_dest)
        
        # Copy data
        fp_data_src = "extracted_data/data/rs.abstract.fitpass"
        fp_data_dest = os.path.join(self.copy_dir, "data", "data", "rs.abstract.fitpass")
        if os.path.exists(fp_data_src):
            os.makedirs(fp_data_dest, exist_ok=True)
            # Use cp -a to preserve as much as possible, though we'll need to fix permissions later
            run(["cp", "-a", f"{fp_data_src}/.", fp_data_dest])
        
        # Create an init script to fix permissions on boot
        init_dir = os.path.join(self.copy_dir, "system", "etc", "init")
        os.makedirs(init_dir, exist_ok=True)
        with open(os.path.join(init_dir, "fitpass_data.rc"), "w") as f:
            f.write("""
on property:sys.boot_completed=1
    exec -- /system/bin/sh -c "PKG=rs.abstract.fitpass; DATA_DIR=/data/data/$PKG; if [ -d $DATA_DIR ]; then APP_UID=$(pm list packages -U | grep $PKG | cut -d: -f3); if [ ! -z $APP_UID ]; then chown -R $APP_UID:$APP_UID $DATA_DIR; chmod -R 700 $DATA_DIR; fi; fi"
""")

    def install(self):
        self.copy()
