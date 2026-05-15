#!/system/bin/sh
# Shared compatibility guard for props that can destabilize non-Pixel ROMs.

ALLOW_UNSAFE_PROPS_FILE="${CONFIG_DIR}/allow_unsafe_props"
_DEVICESPOOFLAB_IS_GOOGLE_CACHE=""

safety_log() {
    if type log >/dev/null 2>&1; then
        log "$1"
    fi
}

read_backup_prop() {
    local PROP="$1"
    local BACKUP_FILE="${CONFIG_DIR}/backup.conf"

    [ ! -f "$BACKUP_FILE" ] && return 1

    while IFS='=' read -r KEY VALUE || [ -n "$KEY" ]; do
        [ "$KEY" = "$PROP" ] && {
            echo "$VALUE"
            return 0
        }
    done < "$BACKUP_FILE"

    return 1
}

get_original_prop() {
    local PROP="$1"
    local VALUE

    VALUE=$(read_backup_prop "$PROP")
    if [ -n "$VALUE" ]; then
        echo "$VALUE"
        return 0
    fi

    getprop "$PROP" 2>/dev/null
}

unsafe_props_allowed() {
    [ -f "$ALLOW_UNSAFE_PROPS_FILE" ] && return 0
    [ "$(getprop persist.devicespooflab.allow_unsafe 2>/dev/null)" = "1" ] && return 0
    return 1
}

is_google_device() {
    case "$_DEVICESPOOFLAB_IS_GOOGLE_CACHE" in
        yes) return 0 ;;
        no) return 1 ;;
    esac

    local BRAND MANUFACTURER FP VENDOR_FP

    BRAND=$(get_original_prop ro.product.brand | tr '[:upper:]' '[:lower:]')
    [ "$BRAND" = "google" ] && { _DEVICESPOOFLAB_IS_GOOGLE_CACHE=yes; return 0; }

    MANUFACTURER=$(get_original_prop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
    [ "$MANUFACTURER" = "google" ] && { _DEVICESPOOFLAB_IS_GOOGLE_CACHE=yes; return 0; }

    FP=$(get_original_prop ro.build.fingerprint | tr '[:upper:]' '[:lower:]')
    case "$FP" in
        google/*) _DEVICESPOOFLAB_IS_GOOGLE_CACHE=yes; return 0 ;;
    esac

    VENDOR_FP=$(get_original_prop ro.vendor.build.fingerprint | tr '[:upper:]' '[:lower:]')
    case "$VENDOR_FP" in
        google/*) _DEVICESPOOFLAB_IS_GOOGLE_CACHE=yes; return 0 ;;
    esac

    _DEVICESPOOFLAB_IS_GOOGLE_CACHE=no
    return 1
}

is_framework_version_prop() {
    case "$1" in
        ro.build.version.sdk|\
        ro.build.version.release|\
        ro.build.version.release_or_codename|\
        ro.build.version.codename|\
        ro.product.build.version.sdk|\
        ro.product.build.version.release|\
        ro.product.build.version.release_or_codename|\
        ro.*.build.version.sdk|\
        ro.*.build.version.release|\
        ro.*.build.version.release_or_codename|\
        ro.*.build.version.codename)
            return 0
            ;;
    esac

    return 1
}

is_non_google_unsafe_prop() {
    case "$1" in
        ro.hardware|\
        ro.board.platform|\
        ro.boot.*|\
        ro.product.cpu.*|\
        ro.arch|\
        ro.sf.lcd_density|\
        ro.treble.enabled|\
        ro.kernel.qemu|\
        ro.crypto.state|\
        sys.oem_unlock_allowed|\
        ro.build.selinux|\
        gsm.*|\
        persist.sys.timezone|\
        persist.sys.usb.config|\
        ro.product.vendor.*|\
        ro.product.vendor_dlkm.*|\
        ro.product.odm.*|\
        ro.product.bootimage.*|\
        ro.product.system_dlkm.*|\
        ro.vendor.*|\
        ro.vendor_dlkm.*|\
        ro.odm.*|\
        ro.bootimage.*|\
        ro.system_dlkm.*)
            return 0
            ;;
    esac

    return 1
}

should_apply_prop() {
    local PROP="$1"
    local VALUE="$2"
    local STAGE="$3"
    local SOURCE="$4"

    unsafe_props_allowed && return 0

    if is_framework_version_prop "$PROP"; then
        safety_log "Compatibility skip (${STAGE}/${SOURCE}): $PROP=$VALUE (framework version props are opt-in)"
        return 1
    fi

    if ! is_google_device && is_non_google_unsafe_prop "$PROP"; then
        safety_log "Compatibility skip (${STAGE}/${SOURCE}): $PROP=$VALUE (non-Google device guard)"
        return 1
    fi

    return 0
}
