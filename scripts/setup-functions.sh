# scripts/setup-functions.sh - Core functions
#!/bin/bash

setup_logging() {
    mkdir -p "${LOG_DIR}"
    exec 1> >(tee -a "${LOG_FILE}")
    exec 2>&1
    log_message "Logging initialized"
}

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "Error: This script must be run as root"
        exit 1
    fi
}

get_domain_config() {
    local domain_entry=$1
    local key=$2
    local config_string=$(echo $domain_entry | cut -d':' -f4)
    echo "$config_string" | grep -o "${key}:[^,}]*" | cut -d':' -f2
}

update_system() {
    log_message "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y software-properties-common
}
