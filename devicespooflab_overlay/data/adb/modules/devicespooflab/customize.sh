#!/system/bin/sh
# Module installer - runs under Magisk, KernelSU, or APatch

SKIPUNZIP=0

ui_print " "
ui_print "********************************"
ui_print "   DeviceSpoofLabs v2.3"
ui_print "********************************"
ui_print " "

# Detect root manager (env vars are exported by Magisk/KSU/APatch installers)
if [ -n "$KSU" ]; then
    ui_print "- KernelSU $KSU_VER ($KSU_KERNEL_VER_CODE) detected"
    ROOT_MGR="ksu"
elif [ -n "$APATCH" ]; then
    ui_print "- APatch $APATCH_VER detected"
    ROOT_MGR="apatch"
elif [ -n "$MAGISK_VER_CODE" ]; then
    ui_print "- Magisk $MAGISK_VER ($MAGISK_VER_CODE) detected"
    ROOT_MGR="magisk"
    [ "$MAGISK_VER_CODE" -lt 20400 ] && abort "! Requires Magisk 20.4 or newer"
else
    abort "! Unsupported environment - install via Magisk, KernelSU, or APatch manager"
fi

ui_print "- Installing module files..."

set_permissions() {
    ui_print "- Setting permissions"
    set_perm_recursive "$MODPATH" 0 0 0755 0644
    set_perm_recursive "$MODPATH/common" 0 0 0755 0755
    set_perm "$MODPATH/system/bin/devicespooflabs" 0 2000 0755
    set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
    set_perm "$MODPATH/service.sh" 0 0 0755
}
