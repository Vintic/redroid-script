import os
import shutil
import hashlib
from stuff.general import General
from tools.helper import get_download_dir, host, print_color, run, bcolors, download_file


class MicroG(General):
    dl_links = {
        "0.3.13": {
            "gmscore": {
                "url": "https://github.com/microg/GmsCore/releases/download/v0.3.13.250932/com.google.android.gms-250932026.apk",
                "md5": "7beef8f879f61ac25029e67e45315ba5",
            },
            "gsfproxy": {
                "url": "https://github.com/microg/GsfProxy/releases/download/v0.1.0/GsfProxy.apk",
                "md5": "b2b4ea3642df6158e14689a4b2a246d4",  
            },
            "fakestore": {
                "url": "https://github.com/microg/GmsCore/releases/download/v0.3.13.250932/com.android.vending-84022626.apk",
                "md5": "76116129cbbdcb443fff1a7dc3211980", 
            },
        },
    }
    arch = host()
    download_loc = get_download_dir()
    copy_dir = "./microg"
    extract_to = "/tmp/microg/extract"

    def __init__(self, version):
        self.version = version
        # APK files configuration
        self.apks = {
            "gmscore": {
                "file": os.path.join(self.download_loc, "gmscore.apk"),
                "dest_dir": os.path.join(self.copy_dir, "system", "priv-app", "GmsCore"),
                "dest_file": "GmsCore.apk",
            },
            "gsfproxy": {
                "file": os.path.join(self.download_loc, "gsfproxy.apk"),
                "dest_dir": os.path.join(self.copy_dir, "system", "priv-app", "GsfProxy"),
                "dest_file": "GsfProxy.apk",
            },
            "fakestore": {
                "file": os.path.join(self.download_loc, "fakestore.apk"),
                "dest_dir": os.path.join(self.copy_dir, "system", "priv-app", "Phonesky"),
                "dest_file": "Phonesky.apk",
            },
        }

    def _download_apk(self, apk_key):
        """
        Download a single APK with MD5 verification.
        If configured MD5 is empty, it will calculate and save the MD5.
        """
        apk_config = self.apks[apk_key]
        link_config = self.dl_links[self.version][apk_key]
        file_path = apk_config["file"]
        url = link_config["url"]
        expected_md5 = link_config["md5"]
        
        # Check if file exists and validate
        if os.path.isfile(file_path):
            with open(file_path, "rb") as f:
                bytes_content = f.read()
                local_md5 = hashlib.md5(bytes_content).hexdigest()
            
            # If expected_md5 is set and matches, use existing file
            if expected_md5 and local_md5 == expected_md5:
                print_color(f"Using cached {apk_key} APK", bcolors.GREEN)
                return
            # If expected_md5 is empty, accept the file
            elif not expected_md5:
                print_color(f"Using cached {apk_key} APK (MD5 not verified)", bcolors.GREEN)
                return
            # Otherwise redownload
            else:
                print_color(f"MD5 mismatch for {apk_key}, redownloading...", bcolors.YELLOW)
                os.remove(file_path)
        
        # Download the file
        print_color(f"Downloading {apk_key}...", bcolors.GREEN)
        calculated_md5 = download_file(url, file_path)
        
        # If we had an expected MD5, verify it
        if expected_md5 and calculated_md5 != expected_md5:
            print_color(f"MD5 mismatch for {apk_key}! Expected {expected_md5}, got {calculated_md5}", bcolors.YELLOW)
            raise ValueError(f"MD5 verification failed for {apk_key}")

    def download(self):
        print_color("Downloading MicroG components now .....", bcolors.GREEN)
        self._download_apk("gmscore")
        self._download_apk("gsfproxy")
        self._download_apk("fakestore")

    def copy(self):
        """
        Copy MicroG APK files (GmsCore, GsfProxy, Phonesky) to the target directory structure.
        """
        if os.path.exists(self.copy_dir):
            shutil.rmtree(self.copy_dir)
        
        # Copy each APK to its destination
        for apk_key, config in self.apks.items():
            src_file = config["file"]
            dest_dir = config["dest_dir"]
            dest_file = config["dest_file"]
            
            # Create destination directory
            os.makedirs(dest_dir, exist_ok=True)
            
            # Copy the APK file
            dest_path = os.path.join(dest_dir, dest_file)
            shutil.copy(src_file, dest_path)
            print_color(f"Copied {apk_key} to {dest_path}", bcolors.GREEN)

        # Add privapp-permissions XML
        permissions_dir = os.path.join(self.copy_dir, "system", "etc", "permissions")
        os.makedirs(permissions_dir, exist_ok=True)
        permissions_file = os.path.join(permissions_dir, "privapp-permissions-microg.xml")
        
        with open(permissions_file, "w") as f:
            f.write("""<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <privapp-permissions package="com.google.android.gms">
        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE"/>
        <permission name="android.permission.INSTALL_LOCATION_PROVIDER"/>
        <permission name="android.permission.INTERACT_ACROSS_USERS"/>
        <permission name="android.permission.READ_PRIVILEGED_PHONE_STATE"/>
        <permission name="android.permission.UPDATE_DEVICE_STATS"/>
        <permission name="android.permission.UPDATE_APP_OPS_STATS"/>
        <permission name="android.permission.DUMP"/>
        <permission name="android.permission.GET_ACCOUNTS_PRIVILEGED"/>
    </privapp-permissions>
    <privapp-permissions package="com.android.vending">
        <permission name="android.permission.FAKE_PACKAGE_SIGNATURE"/>
        <permission name="android.permission.INSTALL_PACKAGES"/>
        <permission name="android.permission.DELETE_PACKAGES"/>
        <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
    </privapp-permissions>
</permissions>
""")
        print_color("Created privapp-permissions-microg.xml", bcolors.GREEN)

    def install(self):
        """
        Install MicroG components (GmsCore, GsfProxy, Phonesky APKs).
        """
        print_color("Installing MicroG components .....", bcolors.GREEN)
        self.download()
        self.copy()
