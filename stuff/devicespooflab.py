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

        print_color("DeviceSpoofLab Magisk module deployed successfully.", bcolors.CYAN)

    def install(self):
        print_color("Installing DeviceSpoofLab .....", bcolors.GREEN)
        self.download()
        self.copy()
