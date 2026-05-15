#!/system/bin/sh
# Config Parser - Reads config files and applies props

SCRIPT_DIR="${SCRIPT_DIR:-${0%/*}}"

should_apply_prop() {
    return 0
}

if [ -f "${SCRIPT_DIR}/prop_safety.sh" ]; then
    . "${SCRIPT_DIR}/prop_safety.sh"
elif type log >/dev/null 2>&1; then
    log "WARN: prop_safety.sh missing - applying all props (legacy mode)"
fi

# Resolve generator expressions like ${RANDOM_HEX:16}
resolve_value() {
    local VALUE="$1"

    case "$VALUE" in
        '${RANDOM_HEX:'*'}')
            local LEN=$(echo "$VALUE" | sed 's/${RANDOM_HEX:\([0-9]*\)}/\1/')
            generate_hex "$LEN"
            ;;
        '${RANDOM_SERIAL}')
            generate_serial
            ;;
        '${RANDOM_UUID}')
            generate_uuid
            ;;
        '${RANDOM_IMEI}')
            generate_imei
            ;;
        '${RANDOM_MAC}')
            generate_mac
            ;;
        '${FROM_BACKUP:'*'}')
            local PROP=$(echo "$VALUE" | sed 's/${FROM_BACKUP:\([^}]*\)}/\1/')
            get_backup_value "$PROP"
            ;;
        *)
            echo "$VALUE"
            ;;
    esac
}

# Generate random hex string
generate_hex() {
    local LENGTH=${1:-16}
    cat /dev/urandom | tr -dc 'a-f0-9' | head -c "$LENGTH"
}

# Generate random serial (alphanumeric uppercase)
generate_serial() {
    cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 12
}

# Generate UUID format
generate_uuid() {
    local H1=$(generate_hex 8)
    local H2=$(generate_hex 4)
    local H3=$(generate_hex 4)
    local H4=$(generate_hex 4)
    local H5=$(generate_hex 12)
    echo "${H1}-${H2}-${H3}-${H4}-${H5}"
}

# Generate IMEI (15 digits)
generate_imei() {
    local BASE=$(cat /dev/urandom | tr -dc '0-9' | head -c 14)
    local SUM=0
    local DOUBLE=0
    for i in $(seq 1 14); do
        local DIGIT=$(echo "$BASE" | cut -c$i)
        if [ $DOUBLE -eq 1 ]; then
            DIGIT=$((DIGIT * 2))
            [ $DIGIT -gt 9 ] && DIGIT=$((DIGIT - 9))
        fi
        SUM=$((SUM + DIGIT))
        DOUBLE=$((1 - DOUBLE))
    done
    local CHECK=$(((10 - (SUM % 10)) % 10))
    echo "${BASE}${CHECK}"
}

# Generate MAC address
generate_mac() {
    printf '%02x:%02x:%02x:%02x:%02x:%02x' \
        $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) \
        $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
}

# Get value from backup file
get_backup_value() {
    local PROP="$1"
    local BACKUP_FILE="${MODDIR}/config/backup.conf"
    if [ -f "$BACKUP_FILE" ]; then
        grep "^${PROP}=" "$BACKUP_FILE" | cut -d'=' -f2- | tr -d '"'
    fi
}

# Parse a single config file and apply props
# Returns: number of props applied
parse_config_file() {
    local CONFIG_FILE="$1"
    local DRY_RUN="${2:-0}"
    local APPLIED=0
    local SKIPPED=0

    [ ! -f "$CONFIG_FILE" ] && return 0

    local FILENAME=$(basename "$CONFIG_FILE")
    log "Parsing config: $FILENAME"

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in
            ''|'#'*) continue ;;
        esac

        # Parse: STATUS,PROP_NAME,VALUE
        local STATUS=$(echo "$LINE" | cut -d',' -f1)
        local PROP_NAME=$(echo "$LINE" | cut -d',' -f2)
        local RAW_VALUE=$(echo "$LINE" | cut -d',' -f3-)

        # Skip disabled props
        if [ "$STATUS" != "ENABLED" ]; then
            log_debug "Skipped (disabled): $PROP_NAME"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # Skip synthetic entries handled by dedicated apply_* functions
        case "$PROP_NAME" in
            ANDROID_ID|SCREEN_*)
                SKIPPED=$((SKIPPED + 1))
                continue
                ;;
        esac

        local RESOLVED_VALUE=$(resolve_value "$RAW_VALUE")

        if [ -z "$RESOLVED_VALUE" ]; then
            log_debug "Skipped (empty value): $PROP_NAME"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        if [ "$DRY_RUN" -eq 1 ]; then
            log "DRY-RUN: Would set $PROP_NAME = $RESOLVED_VALUE"
        else
            if ! should_apply_prop "$PROP_NAME" "$RESOLVED_VALUE" "config-parser" "$FILENAME"; then
                SKIPPED=$((SKIPPED + 1))
                continue
            fi

            # Apply the prop
            if resetprop -n "$PROP_NAME" "$RESOLVED_VALUE" 2>/dev/null; then
                APPLIED=$((APPLIED + 1))
            else
                log_error "Failed to set: $PROP_NAME"
            fi
        fi

    done < "$CONFIG_FILE"

    log "  Applied: $APPLIED, Skipped: $SKIPPED"
    echo "$APPLIED"
}

parse_all_configs() {
    local CONFIG_DIR="${MODDIR}/config"
    local DRY_RUN="${1:-0}"
    local TOTAL_APPLIED=0

    [ ! -d "$CONFIG_DIR" ] && return 0

    for CONF in \
        "$CONFIG_DIR/device_identity.conf" \
        "$CONFIG_DIR/build_info.conf" \
        "$CONFIG_DIR/security.conf" \
        "$CONFIG_DIR/hardware.conf" \
        "$CONFIG_DIR/identifiers.conf" \
        "$CONFIG_DIR/carrier.conf" \
        "$CONFIG_DIR/custom.conf"; do

        if [ -f "$CONF" ]; then
            APPLIED=$(parse_config_file "$CONF" "$DRY_RUN")
            TOTAL_APPLIED=$((TOTAL_APPLIED + APPLIED))
        fi
    done

    echo "$TOTAL_APPLIED"
}

# Apply Settings.Secure values (like ANDROID_ID)
apply_secure_settings() {
    local CONFIG_FILE="${MODDIR}/config/identifiers.conf"

    [ ! -f "$CONFIG_FILE" ] && return 0

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in
            ''|'#'*) continue ;;
        esac

        local STATUS=$(echo "$LINE" | cut -d',' -f1)
        local SETTING_NAME=$(echo "$LINE" | cut -d',' -f2)
        local RAW_VALUE=$(echo "$LINE" | cut -d',' -f3-)

        # Only handle ANDROID_ID here (it's a setting, not a prop)
        if [ "$STATUS" = "ENABLED" ] && [ "$SETTING_NAME" = "ANDROID_ID" ]; then
            local RESOLVED_VALUE=$(resolve_value "$RAW_VALUE")
            if [ -n "$RESOLVED_VALUE" ]; then
                settings put secure android_id "$RESOLVED_VALUE" 2>/dev/null
                log "Applied ANDROID_ID: $RESOLVED_VALUE"
            fi
        fi

    done < "$CONFIG_FILE"
}

# Apply screen settings from config
apply_screen_settings() {
    local CONFIG_FILE="${MODDIR}/config/hardware.conf"

    [ ! -f "$CONFIG_FILE" ] && return 0

    local WIDTH=""
    local HEIGHT=""
    local DENSITY=""

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        case "$LINE" in
            ''|'#'*) continue ;;
        esac

        local STATUS=$(echo "$LINE" | cut -d',' -f1)
        local NAME=$(echo "$LINE" | cut -d',' -f2)
        local VALUE=$(echo "$LINE" | cut -d',' -f3-)

        [ "$STATUS" != "ENABLED" ] && continue

        case "$NAME" in
            "SCREEN_WIDTH") WIDTH="$VALUE" ;;
            "SCREEN_HEIGHT") HEIGHT="$VALUE" ;;
            "SCREEN_DENSITY") DENSITY="$VALUE" ;;
        esac
    done < "$CONFIG_FILE"

    if [ -n "$WIDTH" ] && [ -n "$HEIGHT" ]; then
        wm size "${WIDTH}x${HEIGHT}" 2>/dev/null
        log "Applied screen size: ${WIDTH}x${HEIGHT}"
    fi

    if [ -n "$DENSITY" ]; then
        wm density "$DENSITY" 2>/dev/null
        log "Applied screen density: $DENSITY"
    fi
}
