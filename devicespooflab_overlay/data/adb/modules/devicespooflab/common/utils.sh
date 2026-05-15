#!/system/bin/sh
# DeviceSpoofLabs - Shared Utilities
# Common functions, colors, and path definitions

MODDIR="/data/adb/modules/devicespooflab"
CONFIG_DIR="${MODDIR}/config"
PERSONA_FLAG="${CONFIG_DIR}/persona_active"
LOG_FILE="/data/local/tmp/devicespooflab.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Print functions
print_color() {
    echo -e "${1}${2}${NC}"
}

print_error() {
    echo -e "${RED}[!] ${1}${NC}"
}

print_ok() {
    echo -e "${GREEN}[+] ${1}${NC}"
}

print_warn() {
    echo -e "${YELLOW}[*] ${1}${NC}"
}

print_info() {
    echo -e "${CYAN}[i] ${1}${NC}"
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}
