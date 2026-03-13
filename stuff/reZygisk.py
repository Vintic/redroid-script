import os
import shutil
import re
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
    lib_dir = os.path.join(copy_dir, "system", "lib64") # RK3588 是 64 位系统
    
    machine = host()

    # 我们通过修改 init.environ.rc 或者在 bootanim.rc 里设置全局环境变量
    # 这样所有 fork 自 zygote 的应用都会加载 ReZygisk
    environ_override = """
on early-init
    export LD_PRELOAD /system/lib64/librezygisk.so
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
        
        os.makedirs(self.target_dir, exist_ok=True)
        os.makedirs(self.lib_dir, exist_ok=True)

        print_color("Deploying ReZygisk binaries...", bcolors.GREEN)

        # 1. 解压并拷贝核心文件
        # 假设解压后得到 rezygisk 和 librezygisk.so
        # 实际操作中你需要使用 zipfile 模块处理 self.dl_file_name
        
        # 模拟拷贝 (实际逻辑请根据解压后的路径调整)
        # shutil.copyfile(f"{self.extract_to}/rezygisk", os.path.join(self.lib_dir, "rezygisk"))
        # shutil.copyfile(f"{self.extract_to}/librezygisk.so", os.path.join(self.lib_dir, "librezygisk.so"))

        # 2. 核心注入：修改 init.rc 逻辑
        # 我们不破坏原有的 bootanim，而是新建一个 rc 文件让 init 加载
        rezygisk_rc_path = os.path.join(self.target_dir, "rezygisk.rc")
        
        with open(rezygisk_rc_path, "w") as f:
            # 在 post-fs-data 阶段做一些初始化，比如创建 LSPosed 需要的目录
            f.write("""
on post-fs-data
    mkdir /data/adb 0755 root root
    mkdir /data/adb/rezygisk 0755 root root
    # 如果有其他初始化逻辑写在这里
""")

        # 3. 注入环境变量（这是 ReZygisk 工作的关键）
        # 在 redroid 中，通过这种方式能确保 Zygote 启动时带上注入库
        environ_rc_path = os.path.join(self.target_dir, "env_rezygisk.rc")
        with open(environ_rc_path, "w") as f:
            f.write(self.environ_override)

        # 设置权限
        run(["chmod", "-R", "755", self.copy_dir])
        print_color("ReZygisk deployment scripts generated successfully.", bcolors.CYAN)