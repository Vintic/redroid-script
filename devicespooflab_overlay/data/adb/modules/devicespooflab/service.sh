#!/system/bin/sh
# Applies all spoofed props after boot, plus ANDROID_ID and screen settings

MODDIR=${0%/*}
CONFIG_DIR="${MODDIR}/config"
PERSONA_FLAG="${CONFIG_DIR}/persona_active"
LOG_FILE="/data/local/tmp/devicespooflab.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [service] $1" >> "$LOG_FILE"
}

should_apply_prop() {
    return 0
}

if [ -f "${MODDIR}/common/prop_safety.sh" ]; then
    . "${MODDIR}/common/prop_safety.sh"
else
    log "WARN: prop_safety.sh missing - applying all props (legacy mode)"
fi

generate_hex() {
    local LEN=${1:-16}
    cat /dev/urandom | tr -dc 'a-f0-9' | head -c "$LEN"
}

generate_serial() {
    cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 12
}

resolve_value() {
    local VAL="$1"
    case "$VAL" in
        '${RANDOM_HEX:'*'}')
            local LEN=$(echo "$VAL" | sed 's/.*:\([0-9]*\)}.*/\1/')
            generate_hex "$LEN"
            ;;
        '${RANDOM_SERIAL}')
            generate_serial
            ;;
        *)
            echo "$VAL"
            ;;
    esac
}

wait_for_boot_complete() {
    local WAIT=0
    local LIMIT=120

    while [ $WAIT -lt $LIMIT ]; do
        local STATE
        STATE=$(getprop sys.boot_completed 2>/dev/null)
        [ "$STATE" = "1" ] && return 0
        sleep 2
        WAIT=$((WAIT + 2))
    done

    return 1
}

wait_for_resetprop() {
    local WAIT=0
    while [ $WAIT -lt 30 ]; do
        command -v resetprop >/dev/null 2>&1 && return 0
        sleep 1
        WAIT=$((WAIT + 1))
    done
    return 1
}

apply_prop() {
    local PROP="$1"
    local VALUE="$2"

    [ -z "$VALUE" ] && return 1

    if resetprop -n "$PROP" "$VALUE" 2>/dev/null; then
        log "Prop set: $PROP=$VALUE"
        return 0
    else
        log "ERROR: Failed to set prop: $PROP"
        return 1
    fi
}

apply_config_file() {
    local FILE="$1"
    local NAME=$(basename "$FILE")

    [ ! -f "$FILE" ] && return

    if grep -q '^FILE_DISABLED' "$FILE" 2>/dev/null; then
        log "Skipping (disabled): $NAME"
        return
    fi

    log "Parsing: $NAME"

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in ''|'#'*) continue ;; esac
        [ "$LINE" = "FILE_ENABLED" ] && continue

        local STATUS=$(echo "$LINE" | cut -d',' -f1)
        local PROP=$(echo "$LINE" | cut -d',' -f2)
        local RAW=$(echo "$LINE" | cut -d',' -f3-)

        [ "$STATUS" != "ENABLED" ] && continue

        # Skip entries handled separately
        case "$PROP" in
            ANDROID_ID|SCREEN_*) continue ;;
        esac

        local VALUE
        VALUE=$(resolve_value "$RAW")
        [ -n "$VALUE" ] || continue
        should_apply_prop "$PROP" "$VALUE" "service" "$NAME" || continue
        apply_prop "$PROP" "$VALUE"

    done < "$FILE"
}

apply_all_props() {
    for CONF in \
        device_identity.conf \
        build_info.conf \
        security.conf \
        hardware.conf \
        identifiers.conf \
        carrier.conf \
        custom.conf; do

        [ -f "${CONFIG_DIR}/${CONF}" ] && apply_config_file "${CONFIG_DIR}/${CONF}"
    done
}

apply_android_id() {
    local FILE="${CONFIG_DIR}/identifiers.conf"
    [ ! -f "$FILE" ] && return

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in ''|'#'*) continue ;; esac

        local STATUS=$(echo "$LINE" | cut -d',' -f1)
        local NAME=$(echo "$LINE" | cut -d',' -f2)
        local RAW=$(echo "$LINE" | cut -d',' -f3-)

        if [ "$STATUS" = "ENABLED" ] && [ "$NAME" = "ANDROID_ID" ]; then
            local VALUE
            VALUE=$(resolve_value "$RAW")
            [ -z "$VALUE" ] && return

            # Poll aggressively for settings provider (0.2s intervals)
            local WAIT=0
            while [ $WAIT -lt 300 ]; do
                CURRENT=$(settings get secure android_id 2>/dev/null)
                if [ -n "$CURRENT" ] && [ "$CURRENT" != "null" ]; then
                    settings put secure android_id "$VALUE" 2>/dev/null
                    log "ANDROID_ID set: $VALUE (after ${WAIT}x0.2s)"
                    return 0
                fi
                sleep 0.2
                WAIT=$((WAIT + 1))
            done

            log "ERROR: Settings provider not ready after 60s"
            return 1
        fi
    done < "$FILE"
}

apply_screen_settings() {
    local FILE="${CONFIG_DIR}/hardware.conf"
    [ ! -f "$FILE" ] && return

    local WIDTH="" HEIGHT="" DENSITY=""

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in ''|'#'*) continue ;; esac

        local STATUS=$(echo "$LINE" | cut -d',' -f1)
        local NAME=$(echo "$LINE" | cut -d',' -f2)
        local VALUE=$(echo "$LINE" | cut -d',' -f3-)

        [ "$STATUS" != "ENABLED" ] && continue

        case "$NAME" in
            SCREEN_WIDTH) WIDTH="$VALUE" ;;
            SCREEN_HEIGHT) HEIGHT="$VALUE" ;;
            SCREEN_DENSITY) DENSITY="$VALUE" ;;
        esac
    done < "$FILE"

    # Give WM a moment
    sleep 3

    if [ -n "$WIDTH" ] && [ -n "$HEIGHT" ]; then
        wm size "${WIDTH}x${HEIGHT}" 2>/dev/null
        log "Screen size: ${WIDTH}x${HEIGHT}"
    fi

    if [ -n "$DENSITY" ]; then
        wm density "$DENSITY" 2>/dev/null
        log "Screen density: $DENSITY"
    fi
}

ensure_cli_in_path() {
    local LAUNCHER="${MODDIR}/system/bin/devicespooflabs"
    [ -f "$LAUNCHER" ] || return 0

    # Module's system/ overlay applied - nothing to do
    [ -x /system/bin/devicespooflabs ] && return 0

    # KernelSU/APatch don't always overlay system/ on every kernel.
    # These dirs are in PATH for root sessions and persist across reboots.
    for BIN in /data/adb/ksu/bin /data/adb/ap/bin; do
        if [ -d "$BIN" ]; then
            ln -sf "$LAUNCHER" "$BIN/devicespooflabs" 2>/dev/null && \
                log "CLI symlink: $BIN/devicespooflabs -> $LAUNCHER"
            return 0
        fi
    done
}

log "Service starting..."

chmod 755 "$MODDIR/common/"*.sh 2>/dev/null

if [ -f "${MODDIR}/disable" ]; then
    log "Module disabled - skipping"
    exit 0
fi

# Ensure CLI is in PATH regardless of persona state (CLI activates personas)
ensure_cli_in_path

if [ ! -f "$PERSONA_FLAG" ]; then
    log "No active persona - skipping spoof"
    exit 0
fi

[ ! -d "$CONFIG_DIR" ] && exit 0

if wait_for_resetprop; then
    log "resetprop ready"
else
    log "resetprop not available - aborting spoof"
    exit 1
fi

[ -f "/system/bin/devicespooflabs" ] && log "CLI available"

# ANDROID_ID spoofing as early as possible (don't wait for full boot)
# Settings provider becomes available before boot_completed
log "Attempting early ANDROID_ID spoof..."
apply_android_id

log "Waiting for boot completion..."
if wait_for_boot_complete; then
    log "Boot completed detected"
else
    log "Boot completion wait timed out - continuing"
fi

# Apply all props and screen settings after boot
apply_all_props
apply_screen_settings

log "Service complete"
