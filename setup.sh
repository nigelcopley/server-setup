# setup.sh
#!/bin/bash

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDENTIALS_FILE="${SCRIPT_DIR}/credentials.txt"

# Source configuration
if [[ ! -f "${SCRIPT_DIR}/config.sh" ]]; then
    echo "Error: Configuration file not found!"
    exit 1
fi
source "${SCRIPT_DIR}/config.sh"

# Load all function scripts
for script in "${SCRIPT_DIR}/scripts/"*.sh; do
    source "$script"
done

# Initialize logging
setup_logging() {
    mkdir -p "${LOG_DIR}"
    exec 1> >(tee -a "${LOG_FILE}")
    exec 2>&1
    log_message "Starting setup at $(date)"
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

update_system() {
    log_message "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y software-properties-common curl wget gnupg2 git
}

setup_prerequisites() {
    log_message "Installing prerequisites..."
    
    # Install required packages
    apt-get install -y \
        nginx \
        python3 python3-pip python3-venv \
        certbot python3-certbot-nginx \
        ufw \
        jq \
        acl

    # Install optional packages based on configuration
    if [[ "${INSTALL_FAIL2BAN}" == "1" ]]; then
        apt-get install -y fail2ban
    fi

    if [[ "${INSTALL_CLAMAV}" == "1" ]]; then
        apt-get install -y clamav clamav-daemon
    fi

    if [[ "${INSTALL_REDIS}" == "1" ]]; then
        apt-get install -y redis-server
    fi
}

setup_firewall() {
    log_message "Configuring firewall..."
    
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 'Nginx Full'
    
    # Additional ports if configured
    if [[ -n "${ADDITIONAL_PORTS}" ]]; then
        for port in ${ADDITIONAL_PORTS}; do
            ufw allow "$port"
        done
    fi
    
    # Enable firewall
    echo "y" | ufw enable
}

setup_site() {
    local domain_entry=$1
    local domain=$(echo "$domain_entry" | cut -d: -f1)
    local type=$(echo "$domain_entry" | cut -d: -f2)
    local db=$(echo "$domain_entry" | cut -d: -f3)
    
    log_message "Setting up site: ${domain}"
    
    # Create main server user if not done yet
    if [[ ! -f "/root/.server-credentials/admin-credentials.txt" ]]; then
        setup_server_user
    fi
    
    # Create site user
    local site_user="site_${domain//./_}"
    create_site_user "$domain" "$site_user"
    
    # Setup directory structure
    setup_directory_structure "$domain" "$site_user"
    
    # Setup based on site type
    case $type in
        "php")
            setup_php_site "$domain" "$site_user" "$domain_entry"
            ;;
        "python")
            setup_python_site "$domain" "$site_user" "$domain_entry"
            ;;
        "html")
            setup_html_site "$domain" "$site_user" "$domain_entry"
            ;;
        *)
            log_message "Error: Unknown site type: $type"
            return 1
            ;;
    esac
    
    # Setup database if needed
    if [[ "$db" != "none" ]]; then
        setup_database "$domain" "$site_user" "$db"
    fi
    
    # Setup SSL
    setup_ssl "$domain" "$SSL_EMAIL"
    
    # Setup maintenance mode
    setup_maintenance_mode "$domain" "$site_user"
    
    # Setup monitoring
    setup_monitoring "$domain" "$site_user"
    
    # Setup backups
    setup_backup_system "$domain" "$site_user"
}

cleanup() {
    log_message "Performing cleanup..."
    
    # Remove default nginx site
    rm -f /etc/nginx/sites-enabled/default
    
    # Restart services
    systemctl restart nginx php*-fpm
    
    # Cleanup package cache
    apt-get clean
}

finalize_setup() {
    log_message "Finalizing setup..."
    
    # Final security checks
    setup_ssh_hardening
    
    # Start optional services
    if [[ "${INSTALL_FAIL2BAN}" == "1" ]]; then
        systemctl enable fail2ban
        systemctl start fail2ban
    fi
    
    if [[ "${INSTALL_CLAMAV}" == "1" ]]; then
        systemctl enable clamav-freshclam
        systemctl start clamav-freshclam
    fi
    
    # Setup automatic updates
    setup_automatic_updates
    
    # Cleanup
    cleanup
    
    # Show completion message
    cat <<EOF

Setup completed successfully!
----------------------------
Admin credentials: /root/.server-credentials/admin-credentials.txt
Site credentials: ${CREDENTIALS_FILE}
Logs directory: ${LOG_DIR}

Next steps:
1. Review credentials files
2. Test each site
3. Configure backup settings
4. Test maintenance mode
EOF
}

# Main execution
main() {
    check_root
    setup_logging
    
    log_message "Starting multi-site server setup"
    
    update_system
    setup_prerequisites
    setup_firewall
    
    # Process each domain
    for domain_entry in "${domains[@]}"; do
        setup_site "$domain_entry"
    done
    
    finalize_setup
    
    log_message "Setup completed successfully!"
}

main "$@"