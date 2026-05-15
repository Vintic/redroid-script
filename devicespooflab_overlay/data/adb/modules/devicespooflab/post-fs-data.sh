#!/system/bin/sh
# Applies critical props early; remaining spoofing runs in service.sh

MODDIR=${0%/*}
CONFIG_DIR="${MODDIR}/config"
PERSONA_FLAG="${CONFIG_DIR}/persona_active"
LOG_FILE="/data/local/tmp/devicespooflab.log"
EARLY_CONF="${CONFIG_DIR}/early_boot.conf"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [post-fs-data] $1" >> "$LOG_FILE"
}

should_apply_prop() {
    return 0
}

if [ -f "${MODDIR}/common/prop_safety.sh" ]; then
    . "${MODDIR}/common/prop_safety.sh"
else
    log "WARN: prop_safety.sh missing - applying all props (legacy mode)"
fi

resolve_value() {
    local VAL="$1"
    case "$VAL" in
        '${RANDOM_HEX:'*'}')
            local LEN=$(echo "$VAL" | sed 's/.*:\([0-9]*\)}.*/\1/')
            cat /dev/urandom | tr -dc 'a-f0-9' | head -c "$LEN"
            ;;
        '${RANDOM_SERIAL}')
            cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 12
            ;;
        *)
            echo "$VAL"
            ;;
    esac
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

apply_early_props() {
    [ ! -f "$EARLY_CONF" ] && { log "No early boot config - skipping"; return; }

    if grep -q '^FILE_DISABLED' "$EARLY_CONF" 2>/dev/null; then
        log "Early boot config disabled - skipping"
        return
    fi

    log "Applying early-boot props"

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in ''|'#'*) continue ;; esac
        [ "$LINE" = "FILE_ENABLED" ] && continue

        local STATUS=$(echo "$LINE" | cut -d',' -f1)
        local PROP=$(echo "$LINE" | cut -d',' -f2)
        local RAW=$(echo "$LINE" | cut -d',' -f3-)

        [ "$STATUS" != "ENABLED" ] && continue

        local VALUE
        VALUE=$(resolve_value "$RAW")
        [ -n "$VALUE" ] || continue
        should_apply_prop "$PROP" "$VALUE" "post-fs-data" "$(basename "$EARLY_CONF")" || continue
        apply_prop "$PROP" "$VALUE"

    done < "$EARLY_CONF"
}

log "============================================"
log "DeviceSpoofLabs post-fs-data - early props stage"

if [ -f "${MODDIR}/disable" ]; then
    log "Module disabled - skipping"
    exit 0
fi

if [ ! -f "$PERSONA_FLAG" ]; then
    log "No active persona - skipping"
    exit 0
fi

if wait_for_resetprop; then
    log "resetprop ready"
else
    log "resetprop not available - aborting early props"
    exit 1
fi

# Apply only the early boot props here. the rest in service.sh happens after boot
apply_early_props

log "Early boot props applied; remaining props will load after boot"
