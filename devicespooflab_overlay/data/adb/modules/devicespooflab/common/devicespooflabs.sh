#!/system/bin/sh
# DeviceSpoofLabs CLI
# Interactive tool for managing device spoofing=

VERSION="2.3"

SCRIPT_DIR="${0%/*}"
[ -f "${SCRIPT_DIR}/utils.sh" ] && . "${SCRIPT_DIR}/utils.sh"
[ -f "${SCRIPT_DIR}/config_parser.sh" ] && . "${SCRIPT_DIR}/config_parser.sh"

check_root() {
    [ "$(id -u)" -ne 0 ] && { print_error "Run as root (su)"; exit 1; }
}

check_module() {
    [ ! -d "$MODDIR" ] && { print_error "Module not installed"; exit 1; }
}

is_persona_active() {
    [ -f "$PERSONA_FLAG" ]
}

count_props() {
    local FILE="$1"
    if [ ! -f "$FILE" ]; then
        echo "0"
        return
    fi
    local COUNT=$(grep -c "^ENABLED," "$FILE" 2>/dev/null)
    echo "${COUNT:-0}"
}

count_disabled() {
    local FILE="$1"
    if [ ! -f "$FILE" ]; then
        echo "0"
        return
    fi
    local COUNT=$(grep -c "^DISABLED," "$FILE" 2>/dev/null)
    echo "${COUNT:-0}"
}

show_config_status() {
    # Config status removed - not needed
    return 0
}

regenerate_identifiers() {
    local FILE="${CONFIG_DIR}/identifiers.conf"
    [ ! -f "$FILE" ] && { print_error "identifiers.conf not found"; return 1; }

    print_info "Regenerating unique identifiers..."

    local NEW_SERIAL=$(generate_serial)
    local NEW_ANDROID_ID=$(generate_hex 16)
    local NEW_BOOTLOADER="cheetah-1.2-$(generate_hex 8)"

    # Update file with new static values
    sed -i "s|^ENABLED,ro.serialno,.*|ENABLED,ro.serialno,${NEW_SERIAL}|" "$FILE"
    sed -i "s|^ENABLED,ro.boot.serialno,.*|ENABLED,ro.boot.serialno,${NEW_SERIAL}|" "$FILE"
    sed -i "s|^ENABLED,ro.bootloader,.*|ENABLED,ro.bootloader,${NEW_BOOTLOADER}|" "$FILE"
    sed -i "s|^ENABLED,ANDROID_ID,.*|ENABLED,ANDROID_ID,${NEW_ANDROID_ID}|" "$FILE"

    # Also handle DISABLED lines to ensure they get updated if user enables later
    sed -i "s|^DISABLED,ro.serialno,.*|DISABLED,ro.serialno,${NEW_SERIAL}|" "$FILE"
    sed -i "s|^DISABLED,ro.boot.serialno,.*|DISABLED,ro.boot.serialno,${NEW_SERIAL}|" "$FILE"
    sed -i "s|^DISABLED,ro.bootloader,.*|DISABLED,ro.bootloader,${NEW_BOOTLOADER}|" "$FILE"
    sed -i "s|^DISABLED,ANDROID_ID,.*|DISABLED,ANDROID_ID,${NEW_ANDROID_ID}|" "$FILE"

    print_ok "Serial: $NEW_SERIAL"
    print_ok "ANDROID_ID: $NEW_ANDROID_ID"
    print_ok "Bootloader: $NEW_BOOTLOADER"
    echo ""
    print_ok "New identifiers generated!"
}

is_dimension_spoof_enabled() {
    local FILE="${CONFIG_DIR}/hardware.conf"
    [ -f "$FILE" ] && grep -q "^ENABLED,SCREEN_WIDTH," "$FILE"
}

toggle_dimension_spoof() {
    local FILE="${CONFIG_DIR}/hardware.conf"
    [ ! -f "$FILE" ] && { print_error "hardware.conf not found"; return 1; }

    if is_dimension_spoof_enabled; then
        # Disable dimension spoofing
        sed -i 's/^ENABLED,SCREEN_WIDTH,/DISABLED,SCREEN_WIDTH,/' "$FILE"
        sed -i 's/^ENABLED,SCREEN_HEIGHT,/DISABLED,SCREEN_HEIGHT,/' "$FILE"
        sed -i 's/^ENABLED,SCREEN_DENSITY,/DISABLED,SCREEN_DENSITY,/' "$FILE"
        print_ok "Dimension spoofing DISABLED"
    else
        # Enable dimension spoofing
        sed -i 's/^DISABLED,SCREEN_WIDTH,/ENABLED,SCREEN_WIDTH,/' "$FILE"
        sed -i 's/^DISABLED,SCREEN_HEIGHT,/ENABLED,SCREEN_HEIGHT,/' "$FILE"
        sed -i 's/^DISABLED,SCREEN_DENSITY,/ENABLED,SCREEN_DENSITY,/' "$FILE"
        print_ok "Dimension spoofing ENABLED"
    fi
    print_info "Reboot to apply changes"
}

edit_config() {
    local DIM_STATUS="OFF"
    is_dimension_spoof_enabled && DIM_STATUS="ON"

    echo ""
    print_color "$CYAN" "Select config to edit:"
    echo "  [1] device_identity.conf"
    echo "  [2] build_info.conf"
    echo "  [3] security.conf"
    echo "  [4] hardware.conf"
    echo "  [5] identifiers.conf"
    echo "  [6] carrier.conf"
    echo "  [7] custom.conf"
    echo "  [8] Toggle Dimension Spoof (currently: $DIM_STATUS)"
    echo "  [0] Back"
    echo ""
    echo -n "Choice: "
    read -r CHOICE

    local FILE=""
    case "$CHOICE" in
        1) FILE="device_identity.conf" ;;
        2) FILE="build_info.conf" ;;
        3) FILE="security.conf" ;;
        4) FILE="hardware.conf" ;;
        5) FILE="identifiers.conf" ;;
        6) FILE="carrier.conf" ;;
        7) FILE="custom.conf" ;;
        8) toggle_dimension_spoof; return ;;
        0) return ;;
        *) print_error "Invalid"; return ;;
    esac

    if [ -f "${CONFIG_DIR}/${FILE}" ]; then
        # Try editors in order
        if command -v nano >/dev/null 2>&1; then
            nano "${CONFIG_DIR}/${FILE}"
        elif command -v vi >/dev/null 2>&1; then
            vi "${CONFIG_DIR}/${FILE}"
        else
            print_error "No editor found. Edit manually:"
            print_info "${CONFIG_DIR}/${FILE}"
        fi
    else
        print_error "File not found: $FILE"
    fi
}

view_current() {
    echo ""
    print_color "$CYAN" "Current Spoofed Values (Live):"
    echo "─────────────────────────────────"
    echo "  Model:       $(getprop ro.product.model)"
    echo "  Brand:       $(getprop ro.product.brand)"
    echo "  Device:      $(getprop ro.product.device)"
    echo "  Fingerprint: $(getprop ro.build.fingerprint)"
    echo "  Build ID:    $(getprop ro.build.id)"
    echo "  Android:     $(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))"
    echo "  Security:    $(getprop ro.build.version.security_patch)"
    echo "  Serial:      $(getprop ro.serialno)"
    echo "  ANDROID_ID:  $(settings get secure android_id 2>/dev/null)"
    echo "─────────────────────────────────"
    echo ""
}

create_backup() {
    local BACKUP="${CONFIG_DIR}/backup.conf"

    print_info "Creating device backup at $BACKUP"
    {
        echo "# DeviceSpoofLabs - Original Device Backup"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# DO NOT EDIT - This is your restore point"
        echo ""
        echo "ro.product.brand=$(getprop ro.product.brand)"
        echo "ro.product.manufacturer=$(getprop ro.product.manufacturer)"
        echo "ro.product.model=$(getprop ro.product.model)"
        echo "ro.product.name=$(getprop ro.product.name)"
        echo "ro.product.device=$(getprop ro.product.device)"
        echo "ro.product.board=$(getprop ro.product.board)"
        echo "ro.hardware=$(getprop ro.hardware)"
        echo "ro.board.platform=$(getprop ro.board.platform)"
        echo "ro.build.id=$(getprop ro.build.id)"
        echo "ro.build.display.id=$(getprop ro.build.display.id)"
        echo "ro.build.fingerprint=$(getprop ro.build.fingerprint)"
        echo "ro.build.version.incremental=$(getprop ro.build.version.incremental)"
        echo "ro.build.version.release=$(getprop ro.build.version.release)"
        echo "ro.build.version.sdk=$(getprop ro.build.version.sdk)"
        echo "ro.build.version.security_patch=$(getprop ro.build.version.security_patch)"
        echo "ro.build.type=$(getprop ro.build.type)"
        echo "ro.build.tags=$(getprop ro.build.tags)"
        echo "ro.serialno=$(getprop ro.serialno)"
        echo "ro.bootloader=$(getprop ro.bootloader)"
        echo "ANDROID_ID=$(settings get secure android_id 2>/dev/null)"
    } > "$BACKUP"
    chmod 600 "$BACKUP"
    print_ok "Backup created"
}

ensure_backup() {
    [ -f "${CONFIG_DIR}/backup.conf" ] || create_backup
}

restore_backup() {
    local BACKUP="${CONFIG_DIR}/backup.conf"

    if [ ! -f "$BACKUP" ]; then
        print_error "No backup found"
        return 1
    fi

    print_warn "This will restore original device values"
    echo -n "Continue? (yes/no): "
    read -r CONFIRM
    [ "$CONFIRM" != "yes" ] && { print_info "Cancelled"; return; }

    # Read backup and update configs
    while IFS='=' read -r KEY VALUE; do
        [ -z "$KEY" ] && continue
        case "$KEY" in '#'*) continue ;; esac

        VALUE=$(echo "$VALUE" | tr -d '"')

        # Find and update in appropriate config file
        for CONF in device_identity build_info security hardware identifiers carrier; do
            local FILE="${CONFIG_DIR}/${CONF}.conf"
            [ ! -f "$FILE" ] && continue

            if grep -q ",$KEY," "$FILE" 2>/dev/null; then
                sed -i "s|^ENABLED,$KEY,.*|ENABLED,$KEY,$VALUE|" "$FILE"
                sed -i "s|^DISABLED,$KEY,.*|ENABLED,$KEY,$VALUE|" "$FILE"
            fi
        done
    done < "$BACKUP"

    print_ok "Backup restored"
    print_warn "Reboot to apply"
}

activate_persona() {
    ensure_backup
    touch "$PERSONA_FLAG"
    print_ok "Persona activated!"
    echo ""
    print_warn "Rebooting in 3 seconds..."
    print_info "Press Ctrl+C to cancel"
    sleep 3
    reboot
}

deactivate_persona() {
    if [ -f "$PERSONA_FLAG" ]; then
        rm -f "$PERSONA_FLAG"
        print_ok "Persona deactivated!"
        echo ""
        print_warn "Rebooting in 3 seconds..."
        print_info "Press Ctrl+C to cancel"
        sleep 3
        reboot
    else
        print_info "Persona already inactive."
    fi
}

show_ascii_header() {
    clear
    print_color "$MAGENTA" " ____             _           ____                   __ _          _         "
    print_color "$MAGENTA" "|  _ \\  _____   _(_) ___ ___ / ___| _ __   ___   ___| |_| |    __ _| |__  ___ "
    print_color "$MAGENTA" "| | | |/ _ \\ \\ / / |/ __/ _ \\___ \\| '_ \\ / _ \\ / _ \\ __| |   / _\` | '_ \\/ __|"
    print_color "$MAGENTA" "| |_| |  __/\\ V /| | (_|  __/___) | |_) | (_) | (_) | |_| |__| (_| | |_) \\__ \\\\"
    print_color "$MAGENTA" "|____/ \\___| \\_/ |_|\\___\\___|____/| .__/ \\___/ \\___/ \\__|_____|__,_|_.__/|___/"
    print_color "$MAGENTA" "                                   |_|                                         "
    echo ""
    print_color "$CYAN" "Author: @yubunus"
    print_color "$CYAN" "Version: $VERSION"
    echo ""
}

# MAIN MENU
show_main_menu() {
    show_ascii_header

    local STATUS="INACTIVE"
    local STATUS_COLOR="$RED"
    if is_persona_active; then
        STATUS="ACTIVE"
        STATUS_COLOR="$GREEN"
    fi

    print_color "$STATUS_COLOR" "Persona Status: $STATUS"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  [1] Persona Management"
    echo "  [2] App Data / Cache Tools"
    echo "  [0] Exit"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo -n "Choice: "
}

show_persona_menu() {
    clear
    print_color "$MAGENTA" "═══════════════════════════════════════════════"
    print_color "$MAGENTA" "           PERSONA MANAGEMENT"
    print_color "$MAGENTA" "═══════════════════════════════════════════════"

    local STATUS="INACTIVE"
    local STATUS_COLOR="$RED"
    if is_persona_active; then
        STATUS="ACTIVE"
        STATUS_COLOR="$GREEN"
    fi

    print_color "$STATUS_COLOR" "Persona Status: $STATUS"

    show_config_status

    echo "  [1] View Current Persona Status"
    echo "  [2] Generate New Persona"
    echo "  [3] Restore Default Persona"
    echo "  [4] Activate Persona"
    echo "  [5] Deactivate Persona"
    echo "  [6] Edit Config Files"
    echo "  [7] View Logs"
    echo "  [0] Back to Main Menu"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo -n "Choice: "
}

show_generate_persona_menu() {
    clear
    print_color "$YELLOW" "═══════════════════════════════════════════════"
    print_color "$YELLOW" "           GENERATE NEW PERSONA"
    print_color "$YELLOW" "═══════════════════════════════════════════════"
    echo ""
    print_warn "WARNING: This will create new device identifiers!"
    echo ""
    echo "Choose your level of reset:"
    echo ""
    echo "  [1] Generate IDs and spoof only"
    print_info "      - Creates new serial, ANDROID_ID, bootloader"
    print_info "      - Keeps all your app data intact"
    print_info "      - Recommended for most users"
    echo ""
    echo "  [2] Generate IDs, spoof, and CLEAR ALL APPS (Nuclear Option)"
    print_warn "      - Clears ALL 3rd party apps FIRST"
    print_warn "      - Clears Chrome, GMS, GSF, WebView"
    print_warn "      - Then generates new identifiers"
    print_warn "      - Activates persona automatically"
    print_warn "      - Complete fresh start (CANNOT BE UNDONE)"
    echo ""
    echo "  [0] Back"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo -n "Choice: "
}

show_app_tools_menu() {
    clear
    print_color "$YELLOW" "═══════════════════════════════════════════════"
    print_color "$YELLOW" "        APP DATA & CACHE MANAGEMENT"
    print_color "$YELLOW" "═══════════════════════════════════════════════"
    echo ""
    echo "  [1] Clear ALL app data (3rd party + system)"
    print_warn "      WARNING: This will reset all apps!"
    echo ""
    echo "  [2] View app clearing logs"
    echo ""
    echo "  [0] Back to Main Menu"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo -n "Choice: "
}

handle_generate_persona_menu() {
    while true; do
        show_generate_persona_menu
        read -r CHOICE

        case "$CHOICE" in
            1)
                # Generate IDs only
                regenerate_identifiers
                print_warn "Persona IDs regenerated! Activating persona and rebooting to apply..."
                activate_persona
                ;;
            2)
                # Nuclear option - Clear apps FIRST, then generate IDs, then activate, then reboot
                echo ""
                print_color "$RED" "═══════════════════════════════════════════════"
                print_color "$RED" "        NUCLEAR OPTION"
                print_color "$RED" "═══════════════════════════════════════════════"
                echo ""
                print_warn "This will:"
                print_warn "  1. Clear ALL 3rd party apps"
                print_warn "  2. Clear Chrome, GMS, GSF, WebView"
                print_warn "  3. Generate new device identifiers"
                print_warn "  4. Activate persona"
                print_warn "  5. Auto-reboot to apply changes"
                echo ""
                print_color "$RED" "YOU WILL LOSE:"
                print_warn "  - All app logins and saved data"
                print_warn "  - Browser history and cookies"
                print_warn "  - Game progress"
                print_warn "  - Everything except system files"
                echo ""
                print_color "$GREEN" "Goal: Apps will see a completely new device"
                echo ""
                echo -n "Continue? (y/n): "
                read -r CONFIRM

                if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
                    echo ""
                    print_color "$GREEN" "═══════════════════════════════════════════════"
                    print_ok "Starting nuclear reset sequence..."
                    print_color "$GREEN" "═══════════════════════════════════════════════"

                    # Step 1: Clear all apps FIRST
                    if [ -f "${SCRIPT_DIR}/app_cleaner.sh" ]; then
                        . "${SCRIPT_DIR}/app_cleaner.sh"
                        clear_all_apps
                    else
                        print_error "app_cleaner.sh not found!"
                        echo -n "Press Enter to continue..."
                        read -r
                        continue
                    fi

                    echo ""
                    print_info "Step 1 complete: Apps cleared"
                    sleep 2

                    # Step 2: Generate new IDs
                    echo ""
                    regenerate_identifiers
                    print_info "Step 2 complete: New identifiers generated"
                    sleep 1

                    # Step 3: Activate persona
                    echo ""
                    activate_persona
                    print_info "Step 3 complete: Persona activated"
                    sleep 1

                    # Step 4: Auto-reboot
                    echo ""
                    print_color "$GREEN" "═══════════════════════════════════════════════"
                    print_ok "Nuclear reset complete!"
                    print_color "$GREEN" "═══════════════════════════════════════════════"
                    echo ""
                    print_warn "Rebooting in 5 seconds..."
                    print_info "Press Ctrl+C to cancel reboot"
                    sleep 5
                    print_ok "Rebooting now..."
                    reboot
                else
                    print_info "Operation cancelled"
                    echo ""
                    echo -n "Press Enter to continue..."
                    read -r
                fi
                ;;
            0)
                return
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

handle_persona_menu() {
    while true; do
        show_persona_menu
        read -r CHOICE

        case "$CHOICE" in
            1)
                view_current
                echo -n "Press Enter to continue..."
                read -r
                ;;
            2)
                handle_generate_persona_menu
                ;;
            3)
                restore_backup
                echo -n "Press Enter to continue..."
                read -r
                ;;
            4)
                activate_persona
                echo -n "Press Enter to continue..."
                read -r
                ;;
            5)
                deactivate_persona
                echo -n "Press Enter to continue..."
                read -r
                ;;
            6)
                edit_config
                ;;
            7)
                echo ""
                tail -50 "$LOG_FILE" 2>/dev/null || print_error "No logs"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            0)
                return
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

handle_app_tools_menu() {
    while true; do
        show_app_tools_menu
        read -r CHOICE

        case "$CHOICE" in
            1)
                # Source app_cleaner.sh and run
                if [ -f "${SCRIPT_DIR}/app_cleaner.sh" ]; then
                    . "${SCRIPT_DIR}/app_cleaner.sh"
                    clear_all_apps
                else
                    print_error "app_cleaner.sh not found at ${SCRIPT_DIR}/"
                fi
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            2)
                # Show app cleaner logs
                echo ""
                grep "\[app_cleaner\]" "$LOG_FILE" 2>/dev/null | tail -50 || print_error "No app cleaner logs"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            0)
                return
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

main() {
    check_root
    check_module

    # Main menu loop
    while true; do
        show_main_menu
        read -r CHOICE

        case "$CHOICE" in
            1)
                handle_persona_menu
                ;;
            2)
                handle_app_tools_menu
                ;;
            0)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

main "$@"
