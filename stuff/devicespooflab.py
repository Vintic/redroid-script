import os
import shutil
import zipfile
from stuff.general import General
from tools.helper import bcolors, download_file, print_color, run, get_download_dir

class DeviceSpoofLab(General):
    download_loc = get_download_dir()
    dl_link = "https://github.com/yubunus/DeviceSpoofLab-Magisk/releases/download/v2.3/devicespooflab-v2.3.zip"
    dl_file_name = os.path.join(download_loc, "devicespooflab.zip")
    extract_to = "/tmp/devicespooflab_unpack"
    copy_dir = "./devicespooflab_overlay"
    
    module_dir = os.path.join(copy_dir, "data", "adb", "modules", "devicespooflab")

    def __init__(self, android_version="13.0.0"):
        self.android_version = android_version

    def download(self):
        print_color("Downloading DeviceSpoofLab now .....", bcolors.GREEN)
        if os.path.isfile(self.dl_file_name):
            print_color(f"Using cached DeviceSpoofLab: {self.dl_file_name}", bcolors.GREEN)
            return
        download_file(self.dl_link, self.dl_file_name)

    def copy(self):
        if os.path.exists(self.copy_dir):
            shutil.rmtree(self.copy_dir)
        if os.path.exists(self.extract_to):
            shutil.rmtree(self.extract_to)
        
        os.makedirs(self.module_dir, exist_ok=True)

        print_color("Extracting DeviceSpoofLab...", bcolors.GREEN)
        with zipfile.ZipFile(self.dl_file_name, 'r') as zip_ref:
            zip_ref.extractall(self.extract_to)

        print_color("Deploying DeviceSpoofLab as Magisk module...", bcolors.GREEN)

        for item in os.listdir(self.extract_to):
            s = os.path.join(self.extract_to, item)
            d = os.path.join(self.module_dir, item)
            if os.path.isdir(s):
                shutil.copytree(s, d, dirs_exist_ok=True)
            else:
                shutil.copy2(s, d)

        for script in ["service.sh", "post-fs-data.sh", "uninstall.sh", "verify.sh", "customize.sh"]:
            script_path = os.path.join(self.module_dir, script)
            if os.path.exists(script_path):
                run(["chmod", "755", script_path])

        for root, dirs, files in os.walk(self.module_dir):
            for file in files:
                if file == "zygiskd" or file == "rezygiskd" or file.endswith(".so") or file.endswith(".sh"):
                    run(["chmod", "755", os.path.join(root, file)])

        # Apply automatic spoofing configuration
        self.spoof()
        print_color("DeviceSpoofLab Magisk module deployed successfully.", bcolors.CYAN)

    def spoof(self):
        """
        Configure DSL to automatically spoof a Pixel 7 (Android 13).
        """
        config_dir = os.path.join(self.module_dir, "config")
        os.makedirs(config_dir, exist_ok=True)

        # Pixel 7 (panther) Android 13 props
        fingerprint = "google/panther/panther:13/TQ3A.230901.001/10750268:user/release-keys"
        build_id = "TQ3A.230901.001"
        incremental = "10750268"
        
        # 1. build_info.conf
        with open(os.path.join(config_dir, "build_info.conf"), "w") as f:
            f.write(f"""# BUILD INFORMATION
FILE_ENABLED
ENABLED,ro.build.fingerprint,{fingerprint}
ENABLED,ro.build.id,{build_id}
ENABLED,ro.build.display.id,{build_id}
ENABLED,ro.build.version.incremental,{incremental}
ENABLED,ro.build.type,user
ENABLED,ro.build.tags,release-keys
ENABLED,ro.build.description,panther-user 13 {build_id} {incremental} release-keys
ENABLED,ro.build.product,panther
ENABLED,ro.build.device,panther
ENABLED,ro.product.build.fingerprint,{fingerprint}
ENABLED,ro.product.build.id,{build_id}
ENABLED,ro.product.build.tags,release-keys
ENABLED,ro.product.build.type,user
ENABLED,ro.product.build.version.incremental,{incremental}
ENABLED,ro.system.build.fingerprint,{fingerprint}
ENABLED,ro.system_ext.build.fingerprint,{fingerprint}
ENABLED,ro.build.flavor,panther-user
""")

        # 2. device_identity.conf
        with open(os.path.join(config_dir, "device_identity.conf"), "w") as f:
            f.write(f"""# DEVICE IDENTITY
FILE_ENABLED
ENABLED,ro.product.brand,google
ENABLED,ro.product.manufacturer,Google
ENABLED,ro.product.model,Pixel 7
ENABLED,ro.product.name,panther
ENABLED,ro.product.device,panther
ENABLED,ro.product.board,panther
ENABLED,ro.product.product.brand,google
ENABLED,ro.product.product.manufacturer,Google
ENABLED,ro.product.product.model,Pixel 7
ENABLED,ro.product.product.name,panther
ENABLED,ro.product.product.device,panther
ENABLED,ro.product.system.brand,google
ENABLED,ro.product.system.manufacturer,Google
ENABLED,ro.product.system.model,Pixel 7
ENABLED,ro.product.system.name,panther
ENABLED,ro.product.system.device,panther
ENABLED,ro.product.system_ext.brand,google
ENABLED,ro.product.system_ext.manufacturer,Google
ENABLED,ro.product.system_ext.model,Pixel 7
ENABLED,ro.product.system_ext.name,panther
ENABLED,ro.product.system_ext.device,panther
""")

        # 3. early_boot.conf (Crucial for post-fs-data stage)
        with open(os.path.join(config_dir, "early_boot.conf"), "w") as f:
            f.write(f"""# EARLY BOOT SPOOFING
FILE_ENABLED
ENABLED,ro.build.fingerprint,{fingerprint}
ENABLED,ro.product.brand,google
ENABLED,ro.product.model,Pixel 7
ENABLED,ro.product.name,panther
ENABLED,ro.product.device,panther
ENABLED,ro.product.manufacturer,Google
""")
        
        # 4. Enable spoofing by creating persona_active flag
        with open(os.path.join(config_dir, "persona_active"), "w") as f:
            f.write("pixel7")
            
        print_color("Applied automatic Pixel 7 (Android 13) spoofing config", bcolors.GREEN)

    def install(self):
        print_color("Installing DeviceSpoofLab .....", bcolors.GREEN)
        self.download()
        self.copy()
