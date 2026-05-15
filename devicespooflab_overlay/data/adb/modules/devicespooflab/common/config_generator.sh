#!/system/bin/sh
# Config Generator - Creates config files from current device state

SCRIPT_DIR="${0%/*}"
MODDIR="/data/adb/modules/devicespooflab"
CONFIG_DIR="${MODDIR}/config"
TEMPLATE_DIR="${MODDIR}/templates"

[ -f "${SCRIPT_DIR}/utils.sh" ] && . "${SCRIPT_DIR}/utils.sh"

get_current() {
    getprop "$1" 2>/dev/null
}

get_setting() {
    settings get secure "$1" 2>/dev/null
}

# Create backup of original device values
create_backup() {
    local BACKUP_FILE="${CONFIG_DIR}/backup.conf"

    echo "# DeviceSpoofLabs - Original Device Backup" > "$BACKUP_FILE"
    echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$BACKUP_FILE"
    echo "# DO NOT EDIT - This is your restore point" >> "$BACKUP_FILE"
    echo "" >> "$BACKUP_FILE"

    # Device Identity
    echo "ro.product.brand=$(get_current ro.product.brand)" >> "$BACKUP_FILE"
    echo "ro.product.manufacturer=$(get_current ro.product.manufacturer)" >> "$BACKUP_FILE"
    echo "ro.product.model=$(get_current ro.product.model)" >> "$BACKUP_FILE"
    echo "ro.product.name=$(get_current ro.product.name)" >> "$BACKUP_FILE"
    echo "ro.product.device=$(get_current ro.product.device)" >> "$BACKUP_FILE"
    echo "ro.product.board=$(get_current ro.product.board)" >> "$BACKUP_FILE"
    echo "ro.hardware=$(get_current ro.hardware)" >> "$BACKUP_FILE"
    echo "ro.board.platform=$(get_current ro.board.platform)" >> "$BACKUP_FILE"

    # Build Info
    echo "ro.build.id=$(get_current ro.build.id)" >> "$BACKUP_FILE"
    echo "ro.build.display.id=$(get_current ro.build.display.id)" >> "$BACKUP_FILE"
    echo "ro.build.fingerprint=$(get_current ro.build.fingerprint)" >> "$BACKUP_FILE"
    echo "ro.build.version.incremental=$(get_current ro.build.version.incremental)" >> "$BACKUP_FILE"
    echo "ro.build.version.release=$(get_current ro.build.version.release)" >> "$BACKUP_FILE"
    echo "ro.build.version.sdk=$(get_current ro.build.version.sdk)" >> "$BACKUP_FILE"
    echo "ro.build.version.security_patch=$(get_current ro.build.version.security_patch)" >> "$BACKUP_FILE"
    echo "ro.build.type=$(get_current ro.build.type)" >> "$BACKUP_FILE"
    echo "ro.build.tags=$(get_current ro.build.tags)" >> "$BACKUP_FILE"

    # Identifiers
    echo "ro.serialno=$(get_current ro.serialno)" >> "$BACKUP_FILE"
    echo "ro.bootloader=$(get_current ro.bootloader)" >> "$BACKUP_FILE"
    echo "ANDROID_ID=$(get_setting android_id)" >> "$BACKUP_FILE"

    # Screen
    local SIZE=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -1)
    local DENSITY=$(wm density 2>/dev/null | grep -oE '[0-9]+' | tail -1)
    echo "SCREEN_SIZE=$SIZE" >> "$BACKUP_FILE"
    echo "SCREEN_DENSITY=$DENSITY" >> "$BACKUP_FILE"

    chmod 600 "$BACKUP_FILE"
}

# Generate device_identity.conf
generate_device_identity() {
    local OUT="${CONFIG_DIR}/device_identity.conf"
    local ORIG_BRAND=$(get_current ro.product.brand)
    local ORIG_MODEL=$(get_current ro.product.model)
    local ORIG_DEVICE=$(get_current ro.product.device)

    cat > "$OUT" << 'EOF'
# ============================================
# DEVICE IDENTITY
# ============================================
# Format: ENABLED,prop.name,value
# Comment out or change ENABLED to DISABLED to skip
#
# Generators:
#   ${RANDOM_SERIAL}  - Random 12-char serial
#   ${RANDOM_HEX:N}   - Random N-char hex string
#   ${FROM_BACKUP:X}  - Value from backup.conf
# ============================================

EOF

    # ro.product.brand
    echo "# ro.product.brand" >> "$OUT"
    echo "# Original: $ORIG_BRAND" >> "$OUT"
    echo "ENABLED,ro.product.brand,google" >> "$OUT"
    echo "" >> "$OUT"

    # ro.product.manufacturer
    echo "# ro.product.manufacturer" >> "$OUT"
    echo "# Original: $(get_current ro.product.manufacturer)" >> "$OUT"
    echo "ENABLED,ro.product.manufacturer,Google" >> "$OUT"
    echo "" >> "$OUT"

    # ro.product.model
    echo "# ro.product.model" >> "$OUT"
    echo "# Original: $ORIG_MODEL" >> "$OUT"
    echo "ENABLED,ro.product.model,Pixel 7 Pro" >> "$OUT"
    echo "" >> "$OUT"

    # ro.product.name
    echo "# ro.product.name" >> "$OUT"
    echo "# Original: $(get_current ro.product.name)" >> "$OUT"
    echo "ENABLED,ro.product.name,cheetah" >> "$OUT"
    echo "" >> "$OUT"

    # ro.product.device
    echo "# ro.product.device" >> "$OUT"
    echo "# Original: $ORIG_DEVICE" >> "$OUT"
    echo "ENABLED,ro.product.device,cheetah" >> "$OUT"
    echo "" >> "$OUT"

    # ro.product.board
    echo "# ro.product.board" >> "$OUT"
    echo "# Original: $(get_current ro.product.board)" >> "$OUT"
    echo "ENABLED,ro.product.board,cheetah" >> "$OUT"
    echo "" >> "$OUT"

    # ro.hardware
    echo "# ro.hardware" >> "$OUT"
    echo "# Original: $(get_current ro.hardware)" >> "$OUT"
    echo "DISABLED,ro.hardware,cheetah" >> "$OUT"
    echo "" >> "$OUT"

    # ro.board.platform
    echo "# ro.board.platform" >> "$OUT"
    echo "# Original: $(get_current ro.board.platform)" >> "$OUT"
    echo "DISABLED,ro.board.platform,gs201" >> "$OUT"
    echo "" >> "$OUT"

    # Partition-specific props that are normally safe to spoof.
    for PART in product system system_ext; do
        echo "# ro.product.${PART}.brand" >> "$OUT"
        echo "ENABLED,ro.product.${PART}.brand,google" >> "$OUT"
        echo "ENABLED,ro.product.${PART}.manufacturer,Google" >> "$OUT"
        echo "ENABLED,ro.product.${PART}.model,Pixel 7 Pro" >> "$OUT"
        echo "ENABLED,ro.product.${PART}.name,cheetah" >> "$OUT"
        echo "ENABLED,ro.product.${PART}.device,cheetah" >> "$OUT"
        echo "" >> "$OUT"
    done

    # Vendor/ODM/DLKM identity is device-specific and opt-in for compatibility.
    for PART in vendor vendor_dlkm odm bootimage system_dlkm; do
        echo "# ro.product.${PART}.brand" >> "$OUT"
        echo "DISABLED,ro.product.${PART}.brand,google" >> "$OUT"
        echo "DISABLED,ro.product.${PART}.manufacturer,Google" >> "$OUT"
        echo "DISABLED,ro.product.${PART}.model,Pixel 7 Pro" >> "$OUT"
        echo "DISABLED,ro.product.${PART}.name,cheetah" >> "$OUT"
        echo "DISABLED,ro.product.${PART}.device,cheetah" >> "$OUT"
        echo "" >> "$OUT"
    done

    chmod 644 "$OUT"
}

# Generate build_info.conf
generate_build_info() {
    local OUT="${CONFIG_DIR}/build_info.conf"
    local FP="google/cheetah/cheetah:15/AP4A.241205.013/12621605:user/release-keys"

    cat > "$OUT" << 'EOF'
# ============================================
# BUILD INFORMATION
# ============================================
# Fingerprint format: brand/name/device:version/id/incremental:type/tags
# ============================================

EOF

    echo "# ro.build.fingerprint" >> "$OUT"
    echo "# Original: $(get_current ro.build.fingerprint)" >> "$OUT"
    echo "ENABLED,ro.build.fingerprint,$FP" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.id" >> "$OUT"
    echo "# Original: $(get_current ro.build.id)" >> "$OUT"
    echo "ENABLED,ro.build.id,AP4A.241205.013" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.display.id" >> "$OUT"
    echo "# Original: $(get_current ro.build.display.id)" >> "$OUT"
    echo "ENABLED,ro.build.display.id,AP4A.241205.013" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.version.incremental" >> "$OUT"
    echo "# Original: $(get_current ro.build.version.incremental)" >> "$OUT"
    echo "ENABLED,ro.build.version.incremental,12621605" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.type" >> "$OUT"
    echo "# Original: $(get_current ro.build.type)" >> "$OUT"
    echo "ENABLED,ro.build.type,user" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.tags" >> "$OUT"
    echo "# Original: $(get_current ro.build.tags)" >> "$OUT"
    echo "ENABLED,ro.build.tags,release-keys" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.description" >> "$OUT"
    echo "ENABLED,ro.build.description,cheetah-user 15 AP4A.241205.013 12621605 release-keys" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.version.release" >> "$OUT"
    echo "# Original: $(get_current ro.build.version.release)" >> "$OUT"
    echo "DISABLED,ro.build.version.release,15" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.version.sdk" >> "$OUT"
    echo "# Original: $(get_current ro.build.version.sdk)" >> "$OUT"
    echo "DISABLED,ro.build.version.sdk,35" >> "$OUT"
    echo "" >> "$OUT"

    echo "# ro.build.version.security_patch" >> "$OUT"
    echo "# Original: $(get_current ro.build.version.security_patch)" >> "$OUT"
    echo "ENABLED,ro.build.version.security_patch,2024-12-05" >> "$OUT"
    echo "" >> "$OUT"

    # Partition fingerprints
    for PART in system system_ext product; do
        echo "ENABLED,ro.${PART}.build.fingerprint,$FP" >> "$OUT"
    done
    for PART in vendor odm bootimage system_dlkm vendor_dlkm; do
        echo "DISABLED,ro.${PART}.build.fingerprint,$FP" >> "$OUT"
    done
    echo "" >> "$OUT"

    # Product build props (Android 11+)
    echo "# Product build props (Android 11+)" >> "$OUT"
    echo "ENABLED,ro.product.build.fingerprint,$FP" >> "$OUT"
    echo "ENABLED,ro.product.build.id,AP4A.241205.013" >> "$OUT"
    echo "ENABLED,ro.product.build.tags,release-keys" >> "$OUT"
    echo "ENABLED,ro.product.build.type,user" >> "$OUT"
    echo "ENABLED,ro.product.build.version.incremental,12621605" >> "$OUT"
    echo "DISABLED,ro.product.build.version.release,15" >> "$OUT"
    echo "DISABLED,ro.product.build.version.sdk,35" >> "$OUT"

    chmod 644 "$OUT"
}

# Generate security.conf
generate_security() {
    local OUT="${CONFIG_DIR}/security.conf"

    cat > "$OUT" << 'EOF'
# ============================================
# SECURITY PROPERTIES
# ============================================
# These props help pass SafetyNet/Play Integrity
# ============================================

# ro.debuggable (0 = production, 1 = debug)
ENABLED,ro.debuggable,0

# ro.secure
ENABLED,ro.secure,1

# ro.adb.secure
ENABLED,ro.adb.secure,1

# ro.build.selinux
DISABLED,ro.build.selinux,0

# Verified boot state (green = locked, orange = unlocked)
DISABLED,ro.boot.verifiedbootstate,green

# Flash lock state
DISABLED,ro.boot.flash.locked,1

# VBMeta device state
DISABLED,ro.boot.vbmeta.device_state,locked

# Warranty bit (0 = not voided)
DISABLED,ro.boot.warranty_bit,0

# OEM unlock allowed
DISABLED,sys.oem_unlock_allowed,0

# Verity mode
DISABLED,ro.boot.veritymode,enforcing

# Crypto state
DISABLED,ro.crypto.state,encrypted

# Anti-emulator props
DISABLED,ro.kernel.qemu,0
DISABLED,ro.boot.qemu,0
EOF

    chmod 644 "$OUT"
}

# Generate hardware.conf
generate_hardware() {
    local OUT="${CONFIG_DIR}/hardware.conf"
    local SIZE=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -1)
    local W="${SIZE%x*}"
    local H="${SIZE#*x}"
    local D=$(wm density 2>/dev/null | grep -oE '[0-9]+' | tail -1)

    cat > "$OUT" << EOF
# ============================================
# HARDWARE & DISPLAY
# ============================================

# Boot hardware
# Original: $(get_current ro.boot.hardware)
DISABLED,ro.boot.hardware,cheetah

# Boot mode
DISABLED,ro.boot.mode,normal

# CPU ABI
# Original: $(get_current ro.product.cpu.abi)
DISABLED,ro.product.cpu.abi,arm64-v8a
DISABLED,ro.product.cpu.abilist,arm64-v8a,armeabi-v7a,armeabi
DISABLED,ro.product.cpu.abilist64,arm64-v8a

# Architecture
DISABLED,ro.arch,arm64

# Screen settings (applied via wm command, not resetprop)
# Original: ${W}x${H} @ ${D}dpi
DISABLED,SCREEN_WIDTH,1440
DISABLED,SCREEN_HEIGHT,3120
DISABLED,SCREEN_DENSITY,512

# LCD density prop
DISABLED,ro.sf.lcd_density,512

# Treble
DISABLED,ro.treble.enabled,true
EOF

    chmod 644 "$OUT"
}

# Generate identifiers.conf
generate_identifiers() {
    local OUT="${CONFIG_DIR}/identifiers.conf"

    cat > "$OUT" << EOF
# ============================================
# UNIQUE IDENTIFIERS
# ============================================
# These are randomized on each new persona generation
# Use generators for random values:
#   \${RANDOM_SERIAL}  - 12-char alphanumeric
#   \${RANDOM_HEX:16}  - 16-char hex (for ANDROID_ID)
#   \${RANDOM_UUID}    - UUID format
#   \${RANDOM_IMEI}    - 15-digit IMEI
# ============================================

# Serial number
# Original: $(get_current ro.serialno)
ENABLED,ro.serialno,\${RANDOM_SERIAL}
DISABLED,ro.boot.serialno,\${RANDOM_SERIAL}

# Bootloader version
# Original: $(get_current ro.bootloader)
DISABLED,ro.bootloader,cheetah-1.2-\${RANDOM_HEX:8}

# ANDROID_ID (Settings.Secure, not a prop)
# Original: $(get_setting android_id)
ENABLED,ANDROID_ID,\${RANDOM_HEX:16}
EOF

    chmod 644 "$OUT"
}

# Generate carrier.conf
generate_carrier() {
    local OUT="${CONFIG_DIR}/carrier.conf"

    cat > "$OUT" << EOF
# ============================================
# CARRIER / GSM PROPERTIES
# ============================================

# GSM Operator (carrier name)
DISABLED,gsm.operator.alpha,T-Mobile
DISABLED,gsm.operator.numeric,310260

# SIM Operator
DISABLED,gsm.sim.operator.alpha,T-Mobile
DISABLED,gsm.sim.operator.numeric,310260
DISABLED,gsm.sim.operator.iso-country,us

# Timezone
DISABLED,persist.sys.timezone,America/Los_Angeles

# USB config
DISABLED,persist.sys.usb.config,none
EOF

    chmod 644 "$OUT"
}

# Generate custom.conf (empty template for user)
generate_custom() {
    local OUT="${CONFIG_DIR}/custom.conf"

    cat > "$OUT" << 'EOF'
# ============================================
# CUSTOM PROPERTIES
# ============================================
# Add your own props here
# Format: ENABLED,prop.name,value
# ============================================

# Example:
# ENABLED,my.custom.prop,myvalue

EOF

    chmod 644 "$OUT"
}

generate_all_configs() {
    mkdir -p "$CONFIG_DIR"

    echo "Generating config files..."

    # Create backup first
    if [ ! -f "${CONFIG_DIR}/backup.conf" ]; then
        echo "  Creating device backup..."
        create_backup
    fi

    echo "  Generating device_identity.conf..."
    generate_device_identity

    echo "  Generating build_info.conf..."
    generate_build_info

    echo "  Generating security.conf..."
    generate_security

    echo "  Generating hardware.conf..."
    generate_hardware

    echo "  Generating identifiers.conf..."
    generate_identifiers

    echo "  Generating carrier.conf..."
    generate_carrier

    echo "  Generating custom.conf..."
    generate_custom

    echo "Done! Config files created in: $CONFIG_DIR"
}

# If ran directly
if [ "$1" = "generate" ] || [ -z "$1" ]; then
    generate_all_configs
fi
