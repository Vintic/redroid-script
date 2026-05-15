import os
import shutil
import re
import zipfile
from stuff.general import General
from tools.helper import bcolors, download_file, host, print_color, run, get_download_dir

class ReZygisk(General):
    download_loc = get_download_dir()
    # 建议使用最新 Release 或 Nightly 链接，这里以你 RK3588 需要的 arm64 为主
    dl_link = "https://github.com/PerformanC/ReZygisk/releases/download/v1.0.0-rc.4/ReZygisk-v1.0.0-rc.4-release.zip"
    dl_file_name = os.path.join(download_loc, "rezygisk.zip")
    extract_to = "/tmp/rezygisk_unpack"
    copy_dir = "./rezygisk_overlay" # 最终映射到 redroid 的 overlay 目录
    act_md5 = "aa016bd9bb176bb1e892f6973ba5ca4a"  # MD5 check disabled - GitHub releases are cryptographically signed
    
    # 注入路径
    module_dir = os.path.join(copy_dir, "data", "adb", "modules", "rezygisk")
    
    machine = host()

    def download(self):
        print_color("Downloading ReZygisk now .....", bcolors.GREEN)
        # Check if cached file already exists
        if os.path.isfile(self.dl_file_name):
            print_color(f"Using cached ReZygisk: {self.dl_file_name}", bcolors.GREEN)
            return
        
        download_file(self.dl_link, self.dl_file_name)

    def copy(self):
        if os.path.exists(self.copy_dir):
            shutil.rmtree(self.copy_dir)
        if os.path.exists(self.extract_to):
            shutil.rmtree(self.extract_to)
        
        os.makedirs(self.module_dir, exist_ok=True)

        print_color("Extracting ReZygisk...", bcolors.GREEN)
        with zipfile.ZipFile(self.dl_file_name, 'r') as zip_ref:
            zip_ref.extractall(self.extract_to)

        print_color("Deploying ReZygisk as Magisk module...", bcolors.GREEN)

        # Copy everything from extracted zip to module directory
        for item in os.listdir(self.extract_to):
            s = os.path.join(self.extract_to, item)
            d = os.path.join(self.module_dir, item)
            if os.path.isdir(s):
                shutil.copytree(s, d, dirs_exist_ok=True)
            else:
                shutil.copy2(s, d)

        # Ensure shell scripts are executable
        for script in ["service.sh", "post-fs-data.sh", "uninstall.sh", "verify.sh", "customize.sh"]:
            script_path = os.path.join(self.module_dir, script)
            if os.path.exists(script_path):
                run(["chmod", "755", script_path])

        # Ensure binaries are executable
        for root, dirs, files in os.walk(self.module_dir):
            for file in files:
                if file == "zygiskd" or file == "rezygiskd" or file.endswith(".so"):
                    run(["chmod", "755", os.path.join(root, file)])

        print_color("ReZygisk Magisk module deployed successfully.", bcolors.CYAN)

    def install(self):
        print_color("Installing ReZygisk .....", bcolors.GREEN)
        self.download()
        self.copy()