# DeviceSpoofLabs

A Magisk module for spoofing device identity properties. Spoofs device identity toward a Google Pixel 7 Pro profile with persona management. For development and testing purposes only. Best if used with [DeviceSpoofLab-Hooks](https://github.com/yubunus/DeviceSpoofLab-Hooks)

## Features

1. **Interactive CLI** (`devicespooflabs` command)
   - Persona management menu
   - App data/cache clearing tools
   - Validation and status checks

2. **Automatic Persona Persistence**
   - Persona saves across reboots
   - Auto-applies on every boot
   - No manual intervention needed after setup

3. **Backup & Restore**
   - Original device identity backed up on first boot
   - Easy restore to original state

4. **App Data Cleaner**
   - Clear all third-party app data
   - Clear Chrome/WebView/Google Play Services
   - Reset app-specific identifiers

### Spoofed Properties Include

- Device brand, model, manufacturer, name
- Hardware platform
- Build fingerprint (Pixel 7 Pro Android 15 fingerprint)
- Security patch level (2024-12-05)
- System partition props
- Vendor, ODM, boot, framework-version, and anti-emulator props
- Serial number (randomized per persona)
- ANDROID_ID (randomized per persona)
- Screen size/density (1440x3120 @ 512dpi, disabled by default)

## Limitations (Cannot Be Spoofed with Pure Magisk)

1. Props
   There are 2 ways to spoof props. One is spoofing them at boot runtime, and the other is spoofing them after boot. The problem with spoofing props at boot runtime is that it directly affects your systems Hardware Abstraction Layer(HAL), so if you change props such as ro.hardware, it will corrupt your boot process and prevent your device from booting. The second problem which is spoofing these after "HAL" and after boot is that many apps capture your props and device data at boot runtime, so if you change props after boot, it will not affect the apps that have already captured your props. An example is apps that use Cronet.
2. Framework level identifiers
   Some identifiers that apps track, such as IMEI, IMSI, MediaDrm Id, GAID, Keystore Ids, etc. are stored in the framework layer, and are not accessible to Magisk. Pretty much means that using magisk alone you cannot spoof or edit these variables

## Solutions

For that reason, many people use tools that inject code into the targetted app's runtime, so it spoofs what they see. The ids in your system remain the same, but using these spoofs you can alter what the apps see, and to them it would look different. One popular one is called [LSPOSED](https://github.com/LSposed/LSposed). Due to the problem of unable to spoof using Magisk only, I made a seperate LSPosed module that will spoof everything that purely Magisk cannot. You can find it here: [DeviceSpoofLab-Hooks](https://github.com/yubunus/DeviceSpoofLab-Hooks)

## Legal Disclaimer

**THIS MODULE IS FOR EDUCATIONAL, TESTING, AND DEVELOPMENT PURPOSES ONLY.**

- Use this module responsibly and only on devices you own
- Do NOT use to bypass app restrictions, violate terms of service, or engage in fraudulent activity
- The author (@yubunus) is NOT responsible for any misuse or damage
- Changing device identifiers may violate app terms of service
- Some apps may ban accounts for device spoofing
- Use at your own risk

## Installation

### Prerequisites

- Rooted Android device
- [Magisk](https://github.com/topjohnwu/Magisk) v24.0 or higher
- Magisk Manager app

### Installation Steps

1. **Download the module**
   - Download `devicespooflab-v2.3.zip` from Releases

2. **Install via Magisk Manager**
   - Open Magisk Manager
   - Tap **Modules** (bottom navigation)
   - Tap **Install from storage**
   - Select the downloaded zip file(push using adb push devicespooflab-v2.1.zip /sdcard/Download/)
   - Wait for installation
   - **Reboot** when prompted

3. **First Boot**
   - Module automatically backs up your original device identity
   - **No spoofing is applied yet** - your device remains unchanged
   - Run `devicespooflabs` to set up your first persona

4. **Set Up Persona**

   ```bash
   adb shell
   su
   devicespooflabs
   # Select [1] Persona Management
   # Select [2] Generate NEW persona
   # Select [1] or [2] to generate
   # Reboot when prompted
   ```

5. **Verify Installation** (after persona is set up and reboot)

   ```bash
   adb shell su -c 'getprop ro.product.model'
   # Should output: Pixel 7 Pro

   adb shell su -c 'getprop ro.build.fingerprint'
   # Should output: google/cheetah/cheetah:15/AP4A.241205.013/12621605:user/release-keys
   ```

## Flow

1. **Install module** → Reboot
2. **First boot**:
   - Original device backed up to `personas/backup.conf`
   - **No spoofing applied** - device identity unchanged
3. **Run `devicespooflabs`** to set up:
   - Generate NEW persona (creates random serial/ANDROID_ID)
   - Reboot to apply
4. **After setup, run `devicespooflabs`** when you want to:
   - View current persona status
   - Generate a completely new identity
   - Clear app data
   - Restore to original device
5. **Reboot** after generating new persona for full effect
6. **Persona persists** across all future reboots until changed

## Verification Commands

```bash
# Check model
getprop ro.product.model

# Check fingerprint
getprop ro.build.fingerprint

# Check security patch
getprop ro.build.version.security_patch

# Check Android version
getprop ro.build.version.release

# Check ANDROID_ID
settings get secure android_id

# Check serial
getprop ro.serialno

# View module logs
cat /data/local/tmp/devicespooflab.log
```

## Reverting Changes

### Restore Original Device

```bash
su
devicespooflabs
# Select [1] Persona Management
# Select [3] Restore default persona
# Reboot
```

Or completely remove:

1. Open Magisk Manager
2. Go to **Modules**
3. Uninstall "DeviceSpoofLabs"
4. Reboot

## Troubleshooting

### Props Not Changing

1. Verify module is enabled in Magisk Manager
2. Check logs: `cat /data/local/tmp/devicespooflab.log`
3. Ensure no conflicting modules (MagiskHide Props Config)
4. Reboot device
5. If it still fails, make an issue and send logs

### devicespooflabs Command Not Found

```bash
# Direct path
/data/adb/modules/devicespooflab/common/devicespooflabs.sh

# Or wait for next reboot (symlink created by service.sh)
```

### ANDROID_ID Not Changing

1. ANDROID_ID is applied after boot completes (service.sh)
2. Some ROMs protect ANDROID_ID changes
3. Check logs for errors
4. Try generating new persona and rebooting

### Apps Still Detecting Original Device

- Some apps cache device info - clear their data
- Some apps use hardware-level identifiers (see Limitations)
- Use Shamiko/LSPosed for additional hiding

## Complementary Tools

For best results, consider using:

- [Shamiko](https://github.com/LSPosed/LSPosed.github.io/releases) - Hide root from apps
- [Play Integrity Fix](https://github.com/chiteroman/PlayIntegrityFix) - Pass Play Integrity
- [LSPosed](https://github.com/LSPosed/LSPosed) - For additional spoofing via Xposed modules. Or forks for later android versions and actively maintained modules.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
