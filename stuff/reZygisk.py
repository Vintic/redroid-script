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
    target_dir = os.path.join(copy_dir, "system", "etc", "init")
    lib_dir = os.path.join(copy_dir, "system", "lib")
    lib64_dir = os.path.join(copy_dir, "system", "lib64")
    bin_dir = os.path.join(copy_dir, "system", "bin")
    
    machine = host()

    # 我们通过修改 init.environ.rc 或者在 bootanim.rc 里设置全局环境变量
    # 这样所有 fork 自 zygote 的应用都会加载 ReZygisk
    environ_override = """
on early-init
    export LD_PRELOAD /system/lib64/librezygisk.so:/system/lib/librezygisk.so
"""

    def download(self):
        print_color("Downloading ReZygisk for RK3588 now .....", bcolors.GREEN)
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
        
        os.makedirs(self.target_dir, exist_ok=True)
        os.makedirs(self.lib_dir, exist_ok=True)
        os.makedirs(self.lib64_dir, exist_ok=True)
        os.makedirs(self.bin_dir, exist_ok=True)

        print_color("Extracting ReZygisk...", bcolors.GREEN)
        with zipfile.ZipFile(self.dl_file_name, 'r') as zip_ref:
            zip_ref.extractall(self.extract_to)

        print_color("Deploying ReZygisk binaries...", bcolors.GREEN)

        # 1. 拷贝核心库和守护进程
        if self.machine[0] == "arm64":
            arch_map = {
                "64": "arm64-v8a",
                "32": "armeabi-v7a"
            }
        else:
            arch_map = {
                "64": "x86_64",
                "32": "x86"
            }

        # 64-bit deployment
        src_lib64_dir = os.path.join(self.extract_to, "lib", arch_map["64"])
        if os.path.exists(src_lib64_dir):
            # libzygisk.so -> librezygisk.so (to match LD_PRELOAD config)
            shutil.copyfile(os.path.join(src_lib64_dir, "libzygisk.so"), 
                            os.path.join(self.lib64_dir, "librezygisk.so"))
            # Also copy ptrace helper
            if os.path.exists(os.path.join(src_lib64_dir, "libzygisk_ptrace.so")):
                shutil.copyfile(os.path.join(src_lib64_dir, "libzygisk_ptrace.so"), 
                                os.path.join(self.lib64_dir, "libzygisk_ptrace.so"))
            print_color(f"Copied 64-bit libraries ({arch_map['64']})", bcolors.GREEN)
        
        src_bin64_dir = os.path.join(self.extract_to, "bin", arch_map["64"])
        if os.path.exists(src_bin64_dir):
            # Check for zygiskd (v1.0.0-rc.4+) or rezygiskd (older)
            daemon_name = "zygiskd" if os.path.exists(os.path.join(src_bin64_dir, "zygiskd")) else "rezygiskd"
            shutil.copyfile(os.path.join(src_bin64_dir, daemon_name), 
                            os.path.join(self.bin_dir, "rezygiskd"))
            print_color(f"Copied 64-bit {daemon_name} (as rezygiskd)", bcolors.GREEN)

        # 32-bit deployment (libraries only, usually daemon is 64-bit)
        src_lib32_dir = os.path.join(self.extract_to, "lib", arch_map["32"])
        if os.path.exists(src_lib32_dir):
            shutil.copyfile(os.path.join(src_lib32_dir, "libzygisk.so"), 
                            os.path.join(self.lib_dir, "librezygisk.so"))
            if os.path.exists(os.path.join(src_lib32_dir, "libzygisk_ptrace.so")):
                shutil.copyfile(os.path.join(src_lib32_dir, "libzygisk_ptrace.so"), 
                                os.path.join(self.lib_dir, "libzygisk_ptrace.so"))
            print_color(f"Copied 32-bit libraries ({arch_map['32']})", bcolors.GREEN)

        # 3. 核心注入：修改 init.rc 逻辑
        rezygisk_rc_path = os.path.join(self.target_dir, "rezygisk.rc")
        with open(rezygisk_rc_path, "w") as f:
            f.write("""
on post-fs-data
    mkdir /data/adb 0755 root root
    mkdir /data/adb/rezygisk 0755 root root

service rezygiskd /system/bin/rezygiskd
    class main
    user root
    group root
    capabilities SYS_ADMIN
    oneshot
""")

        # 4. 注入环境变量
        environ_rc_path = os.path.join(self.target_dir, "env_rezygisk.rc")
        with open(environ_rc_path, "w") as f:
            f.write(self.environ_override)

        # 设置权限
        run(["chmod", "-R", "755", self.copy_dir])
        # Ensure rezygiskd is executable
        daemon_path = os.path.join(self.bin_dir, "rezygiskd")
        if os.path.exists(daemon_path):
            run(["chmod", "755", daemon_path])
            
        print_color("ReZygisk deployment scripts generated successfully.", bcolors.CYAN)

    def install(self):
        print_color("Installing ReZygisk .....", bcolors.GREEN)
        self.download()
        self.copy()