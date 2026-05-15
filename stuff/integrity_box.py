import os
import shutil
import zipfile
from stuff.general import General
from tools.helper import bcolors, download_file, print_color, run, get_download_dir

class IntegrityBox(General):
    download_loc = get_download_dir()
    dl_link = "https://github.com/MeowDump/Integrity-Box/releases/download/v35/v35-Integrity-Box-01-05-2026.zip"
    dl_file_name = os.path.join(download_loc, "integrity_box.zip")
    extract_to = "/tmp/integrity_box_unpack"
    copy_dir = "./integrity_box_overlay"
    
    module_dir = os.path.join(copy_dir, "data", "adb", "modules", "integrity_box")

    def __init__(self, android_version="13.0.0"):
        self.android_version = android_version

    def download(self):
        print_color("Downloading Integrity-Box now .....", bcolors.GREEN)
        if os.path.isfile(self.dl_file_name):
            print_color(f"Using cached Integrity-Box: {self.dl_file_name}", bcolors.GREEN)
            return
        download_file(self.dl_link, self.dl_file_name)

    def copy(self):
        if os.path.exists(self.copy_dir):
            shutil.rmtree(self.copy_dir)
        if os.path.exists(self.extract_to):
            shutil.rmtree(self.extract_to)
        
        os.makedirs(self.module_dir, exist_ok=True)

        print_color("Extracting Integrity-Box...", bcolors.GREEN)
        with zipfile.ZipFile(self.dl_file_name, 'r') as zip_ref:
            zip_ref.extractall(self.extract_to)

        print_color("Deploying Integrity-Box as Magisk module...", bcolors.GREEN)

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
        print_color("Integrity-Box Magisk module deployed successfully.", bcolors.CYAN)

    def spoof(self):
        """
        Configure IntegrityBox to automatically spoof a Pixel 7 (Android 13).
        """
        fingerprint_dir = os.path.join(self.module_dir, "fingerprint")
        os.makedirs(fingerprint_dir, exist_ok=True)

        # Pixel 7 (panther) Android 13 props
        fingerprint = "google/panther/panther:13/TQ3A.230901.001/10750268:user/release-keys"
        build_id = "TQ3A.230901.001"
        incremental = "10750268"
        security_patch = "2023-09-01"

        with open(os.path.join(fingerprint_dir, "custom.pif.prop"), "w") as f:
            f.write(f"""# Build Fields
MANUFACTURER=Google
MODEL=Pixel 7
FINGERPRINT={fingerprint}
BRAND=google
PRODUCT=panther
DEVICE=panther
RELEASE=13
ID={build_id}
INCREMENTAL={incremental}
TYPE=user
TAGS=release-keys
SECURITY_PATCH={security_patch}
DEVICE_INITIAL_SDK_INT=33

# System Properties
*.build.id={build_id}
*.security_patch={security_patch}
*api_level=33

# Advanced Settings
spoofBuild=1
spoofProps=1
spoofProvider=0
spoofSignature=1
spoofVendingFinger=1
spoofVendingSdk=0
spoofPixel=1
""")
        print_color("Applied automatic Pixel 7 (Android 13) integrity spoofing config", bcolors.GREEN)

    def install(self):
        print_color("Installing Integrity-Box .....", bcolors.GREEN)
        self.download()
        self.copy()
