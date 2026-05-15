import gzip
import os
import shutil
import re
from stuff.general import General
from tools.helper import bcolors, download_file, host, print_color, run, get_download_dir

class Magisk(General):
    download_loc = get_download_dir()
    dl_link = "https://github.com/ayasa520/Magisk/releases/download/v30.6/app-debug.apk"
    dl_file_name = os.path.join(download_loc, "magisk.apk")
    act_md5 = "77ef9f3538c0767ea45ee5c946f84bc6"
    extract_to = "/tmp/magisk_unpack"
    copy_dir = "./magisk"
    magisk_dir = os.path.join(copy_dir, "system", "etc", "init", "magisk")
    machine = host()
    oringinal_bootanim = """
service bootanim /system/bin/bootanimation
    class core animation
    user graphics
    group graphics audio
    disabled
    oneshot
    ioprio rt 0
    task_profiles MaxPerformance
    
"""
    bootanim_component = """
on post-fs-data
    start logd
    exec u:r:su:s0 root root -- {MAGISKSYSTEMDIR}/{magisk_name} --auto-selinux --setup-sbin {MAGISKSYSTEMDIR} {MAGISKTMP}
    exec u:r:su:s0 root root -- {MAGISKTMP}/magisk --auto-selinux --post-fs-data
    # Manually trigger module post-fs-data scripts
    exec -- /system/bin/sh {MAGISKSYSTEMDIR}/setup_modules.sh post-fs-data

on nonencrypted
    exec u:r:su:s0 root root -- {MAGISKTMP}/magisk --auto-selinux --service
    # Manually trigger module service scripts
    exec -- /system/bin/sh {MAGISKSYSTEMDIR}/setup_modules.sh service

on property:vold.decrypt=trigger_restart_framework
    exec u:r:su:s0 root root -- {MAGISKTMP}/magisk --auto-selinux --service

on property:sys.boot_completed=1
    mkdir /data/adb/magisk 755
    exec u:r:su:s0 root root -- {MAGISKTMP}/magisk --auto-selinux --boot-complete
    exec -- /system/bin/sh -c "if [ ! -e /data/data/com.topjohnwu.magisk ] && [ ! -e /data/data/io.github.huskydg.magisk ] ; then pm install /system/etc/init/magisk/magisk.apk ; fi"
   
on property:init.svc.zygote=restarting
    exec u:r:su:s0 root root -- {MAGISKTMP}/magisk --auto-selinux --zygote-restart
   
on property:init.svc.zygote=stopped
    exec u:r:su:s0 root root -- {MAGISKTMP}/magisk --auto-selinux --zygote-restart
    """.format(MAGISKSYSTEMDIR="/system/etc/init/magisk", MAGISKTMP="/sbin", magisk_name="magisk")

    def download(self):
        print_color("Downloading latest Magisk now .....", bcolors.GREEN)
        super().download()   

    def copy(self):
        if os.path.exists(self.copy_dir):
            shutil.rmtree(self.copy_dir)
        if not os.path.exists(self.magisk_dir):
            os.makedirs(self.magisk_dir, exist_ok=True)

        if not os.path.exists(os.path.join(self.copy_dir, "sbin")):
            os.makedirs(os.path.join(self.copy_dir, "sbin"), exist_ok=True)

        print_color("Copying magisk libs now ...", bcolors.GREEN)
        
        arch_map = {
            "x86": "x86",
            "x86_64": "x86_64",
            "arm": "armeabi-v7a",
            "arm64": "arm64-v8a"
        }
        lib_dir = os.path.join(self.extract_to, "lib", arch_map[self.machine[0]])
        for parent, dirnames, filenames in os.walk(lib_dir):
            for filename in filenames:
                o_path = os.path.join(lib_dir, filename)  
                filename = re.search('lib(.*)\.so', filename)
                n_path = os.path.join(self.magisk_dir, filename.group(1))
                shutil.copyfile(o_path, n_path)
                run(["chmod", "+x", n_path])
        shutil.copyfile(self.dl_file_name, os.path.join(self.magisk_dir,"magisk.apk") )

        # Create module setup script
        setup_script_path = os.path.join(self.magisk_dir, "setup_modules.sh")
        with open(setup_script_path, "w") as f:
            f.write("""#!/system/bin/sh
# Bridge script to run Magisk module scripts in redroid
STAGE=$1
LOG_FILE="/data/local/tmp/setup_modules.log"
# Set PATH to include magisk applets
export PATH=/sbin:/system/bin:/system/xbin:$PATH

echo "[$(date)] Stage: $STAGE" >> "$LOG_FILE"

if [ "$STAGE" = "post-fs-data" ]; then
    # Populate /data/adb/magisk with binaries
    mkdir -p /data/adb/magisk
    for b in magisk magiskinit magiskpolicy busybox magiskboot; do
        if [ -f "/system/etc/init/magisk/$b" ]; then
            cp "/system/etc/init/magisk/$b" "/data/adb/magisk/$b"
            chmod 755 "/data/adb/magisk/$b"
        fi
    done

    # Create symlinks in /system/bin and /system/xbin for better compatibility
    # Ensure we replace existing su binaries to avoid confusion
    [ -L /system/bin/magisk ] || ln -sf /sbin/magisk /system/bin/magisk
    
    for su_path in /system/bin/su /system/xbin/su; do
        if [ -f "$su_path" ] && [ ! -L "$su_path" ]; then
            mv "$su_path" "${su_path}.orig"
        fi
        ln -sf /sbin/su "$su_path"
    done
    
    # Initialize magisk.db if it doesn't exist or is empty
    if [ ! -s /data/adb/magisk.db ]; then
        magisk --sqlite "VACUUM;"
        chmod 600 /data/adb/magisk.db
    fi

    for s in /data/adb/modules/*/post-fs-data.sh; do
        if [ -f "$s" ]; then
            echo "Running post-fs-data: $s" >> "$LOG_FILE"
            # Ensure script is executable
            chmod 755 "$s"
            sh "$s" >> "$LOG_FILE" 2>&1
        fi
    done
elif [ "$STAGE" = "service" ]; then
    for s in /data/adb/modules/*/service.sh; do
        if [ -f "$s" ]; then
            echo "Running service: $s" >> "$LOG_FILE"
            chmod 755 "$s"
            # Try to run in background in a way that escapes init cleanup
            (sh "$s" >> "$LOG_FILE" 2>&1 &)
        fi
    done
fi
""")
        run(["chmod", "+x", setup_script_path])

        # Pre-create /data/adb/magisk to help modules detect Magisk
        magisk_adb_dir = os.path.join(self.copy_dir, "data", "adb", "magisk")
        os.makedirs(magisk_adb_dir, exist_ok=True)

        # Updating Magisk from Magisk manager will modify bootanim.rc, 
        # So it is necessary to backup the original bootanim.rc.
        bootanim_path = os.path.join(self.copy_dir, "system", "etc", "init", "bootanim.rc")
        gz_filename = os.path.join(bootanim_path)+".gz"
        with gzip.open(gz_filename,'wb') as f_gz:
            f_gz.write(self.oringinal_bootanim.encode('utf-8'))
        with open(bootanim_path, "w") as initfile:
            initfile.write(self.oringinal_bootanim+self.bootanim_component)

        os.chmod(bootanim_path, 0o644)
