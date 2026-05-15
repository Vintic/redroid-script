#!/system/bin/sh
# Clears all 3rd party apps and some system apps(to prevent webview and chrome from saving data)

SCRIPT_DIR="${0%/*}"
[ -f "${SCRIPT_DIR}/utils.sh" ] && . "${SCRIPT_DIR}/utils.sh"

log_cleaner() {
    local MSG="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [app_cleaner] $MSG" >> "$LOG_FILE"
}

check_pm_available() {
    if ! command -v pm >/dev/null 2>&1; then
        print_error "Package Manager (pm) not available"
        log_cleaner "ERROR: pm command not found"
        return 1
    fi
    return 0
}

clear_app_data() {
    local PACKAGE="$1"

    pm clear "$PACKAGE" >/dev/null 2>&1
    local RESULT=$?

    if [ $RESULT -eq 0 ]; then
        log_cleaner "SUCCESS: Cleared $PACKAGE"
        return 0
    else
        log_cleaner "FAILED: Could not clear $PACKAGE (code: $RESULT)"
        return 1
    fi
}

# Denylist of things to never clear
get_protected_packages() {
    echo "com.topjohnwu.magisk"
    echo "io.github.vvb2060.magisk"
    echo "me.weishu.kernelsu"
    echo "com.rifsxd.ksunext"
    echo "com.sukisu.ultra"
    echo "com.twj.wksu"
    echo "me.bmax.apatch"
    echo "org.meowcat.edxposed.manager"
    echo "de.robv.android.xposed.installer"
    echo "io.github.lsposed.manager"
    echo "com.android.shell"
    echo "com.android.systemui"
    echo "com.oasisfeng.island"
    echo "com.devicespooflab.hooks"
    echo "com.enflick.android.TextNow"
}

is_protected_package() {
    local PKG="$1"

    case "$PKG" in
        com.topjohnwu.magisk|\
        io.github.vvb2060.magisk|\
        me.weishu.kernelsu|\
        com.rifsxd.ksunext|\
        com.sukisu.ultra|\
        com.twj.wksu|\
        me.bmax.apatch|\
        org.meowcat.edxposed.manager|\
        de.robv.android.xposed.installer|\
        io.github.lsposed.manager|\
        com.android.shell|\
        com.android.systemui|\
        com.oasisfeng.island|\
        com.devicespooflab.hooks|\
        com.enflick.android.TextNow)
            return 0
            ;;
        *ksuwebui*|*kernelsu*|*apatch*)
            return 0
            ;;
    esac

    return 1
}

# quick list of system apps to clear, add to this list if you wanna manually clear system apps
get_system_apps_to_clear() {
    echo "com.android.chrome"
    echo "com.google.android.webview"
    echo "com.android.webview"
    echo "com.google.android.gms"
    echo "com.google.android.gsf"
}

clear_all_third_party_apps() {
    local TOTAL=0
    local SUCCESS=0
    local FAILED=0
    local SKIPPED=0

    print_info "Fetching list of 3rd party apps..."
    log_cleaner "Starting 3rd party app data clearing"

    local PACKAGES=$(pm list packages -3 2>/dev/null | cut -d':' -f2)

    if [ -z "$PACKAGES" ]; then
        print_warn "No 3rd party apps found"
        log_cleaner "No 3rd party packages detected"
        return 0
    fi

    TOTAL=$(echo "$PACKAGES" | wc -l | tr -d ' ')
    print_info "Found $TOTAL 3rd party apps"

    local COUNT=0
    local PROTECTED=0
    for PKG in $PACKAGES; do
        COUNT=$((COUNT + 1))
        [ -z "$PKG" ] && continue

        if is_protected_package "$PKG"; then
            SKIPPED=$((SKIPPED + 1))
            PROTECTED=$((PROTECTED + 1))
            log_cleaner "PROTECTED: Skipped $PKG (on denylist)"
            continue
        fi

        if [ $((COUNT % 10)) -eq 0 ]; then
            print_info "Progress: $COUNT/$TOTAL apps processed..."
        fi

        if ! pm list packages "$PKG" | grep -q "$PKG"; then
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        if clear_app_data "$PKG"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi

        sleep 0.1
    done

    echo ""
    print_ok "Cleared $SUCCESS 3rd party apps"
    [ $PROTECTED -gt 0 ] && print_info "Protected $PROTECTED critical apps (Magisk, LSPosed, etc.)"
    [ $FAILED -gt 0 ] && print_warn "Failed to clear $FAILED apps"
    [ $SKIPPED -gt 0 ] && print_info "Skipped $SKIPPED other apps"

    log_cleaner "3rd party apps: SUCCESS=$SUCCESS, PROTECTED=$PROTECTED, FAILED=$FAILED, SKIPPED=$SKIPPED"
}

# Clear critical system apps
clear_system_apps() {
    local TOTAL=0
    local SUCCESS=0
    local FAILED=0

    print_info "Clearing critical system apps..."
    log_cleaner "Starting system app data clearing"

    for PKG in $(get_system_apps_to_clear); do
        TOTAL=$((TOTAL + 1))

        if ! pm list packages "$PKG" | grep -q "$PKG"; then
            print_warn "$PKG not found on this device"
            log_cleaner "SKIPPED: $PKG (not installed)"
            continue
        fi

        print_info "Clearing: $PKG"

        if clear_app_data "$PKG"; then
            SUCCESS=$((SUCCESS + 1))
            print_ok "  Cleared $PKG"
        else
            FAILED=$((FAILED + 1))
            print_error "  Failed to clear $PKG"
        fi
    done

    echo ""
    print_ok "Cleared $SUCCESS/$TOTAL system apps"
    [ $FAILED -gt 0 ] && print_warn "Failed to clear $FAILED system apps"

    log_cleaner "System apps: SUCCESS=$SUCCESS, FAILED=$FAILED, TOTAL=$TOTAL"
}

clear_all_apps() {
    echo ""
    print_color "$YELLOW" "╔═══════════════════════════════════════════════╗"
    print_color "$YELLOW" "║   APP DATA & CACHE CLEANER                    ║"
    print_color "$YELLOW" "╚═══════════════════════════════════════════════╝"
    echo ""

    print_warn "WARNING: This will clear ALL app data and cache!"
    print_warn "This includes:"
    print_warn "  - All 3rd party apps (game progress, logins, etc)"
    print_warn "  - Chrome browser (history, passwords, cookies)"
    print_warn "  - Google Play Services & GSF"
    print_warn "  - WebView"
    echo ""
    print_color "$GREEN" "Protected (will NOT be cleared):"
    print_info "  - Magisk & LSPosed (root management apps)"
    print_info "  - System UI & Shell"
    echo ""
    print_color "$RED" "This operation CANNOT be undone!"
    echo ""
    print_info "Apps will act like they're freshly installed."
    echo ""

    echo -n "Continue? (y/n): "
    read -r CONFIRM

    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        print_info "Operation cancelled"
        log_cleaner "User cancelled app clearing"
        return 0
    fi

    if ! check_pm_available; then
        return 1
    fi

    log_cleaner "=========================================="
    log_cleaner "Starting full app clear operation"

    local START_TIME=$(date +%s)

    clear_system_apps

    echo ""
    print_info "Pausing for 2 seconds..."
    sleep 2

    clear_all_third_party_apps

    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))

    echo ""
    print_color "$GREEN" "=========================================="
    print_ok "App clearing complete in ${DURATION}s"
    print_color "$GREEN" "=========================================="
    print_warn "Reboot recommended for best results"

    log_cleaner "App clear completed in ${DURATION}s"
    log_cleaner "=========================================="
}
