# setup.sh
#!/bin/bash

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
source "${SCRIPT_DIR}/config.sh"

# Load all function scripts
for script in "${SCRIPT_DIR}/scripts/"*.sh; do
    source "$script"
done

# Initialize logging
setup_logging

# Maintenance mode functions
setup_maintenance_mode() {
    local domain=$1
    local site_user=$2
    
    # Create maintenance directory
    local maint_dir="/var/www/${domain}/maintenance"
    mkdir -p "$maint_dir"
    
    # Copy maintenance page
    cp "${SCRIPT_DIR}/templates/site-structures/html/default-pages/maintenance.html" \
        "${maint_dir}/index.html"
    
    # Create maintenance control script
    cat > "/usr/local/bin/maintenance-${domain}.sh" <<EOF
#!/bin/bash

# Maintenance control script for ${domain}
NGINX_CONF="/etc/nginx/sites-available/${domain}"
MAINTENANCE_FLAG="/var/www/${domain}/maintenance/.maintenance"

start_maintenance() {
    local duration=\$1
    local message=\$2
    
    # Create maintenance flag with metadata
    cat > "\$MAINTENANCE_FLAG" <<METADATA
start_time: \$(date +%s)
duration: \$duration
message: \$message
METADATA
    
    # Update NGINX configuration
    sed -i '/maintenance_mode/d' "\$NGINX_CONF"
    sed -i '/location \/ {/a \    if (-f \$document_root/../maintenance/.maintenance) { return 503; }' "\$NGINX_CONF"
    
    # Add maintenance error page
    sed -i '/error_page 503/d' "\$NGINX_CONF"
    echo "error_page 503 /maintenance/index.html;" >> "\$NGINX_CONF"
    
    # Reload NGINX
    systemctl reload nginx
    
    echo "Maintenance mode activated for ${domain}"
}

stop_maintenance() {
    # Remove maintenance flag
    rm -f "\$MAINTENANCE_FLAG"
    
    # Update NGINX configuration
    sed -i '/maintenance_mode/d' "\$NGINX_CONF"
    sed -i '/if (-f \$document_root\/.maintenance)/d' "\$NGINX_CONF"
    sed -i '/error_page 503/d' "\$NGINX_CONF"
    
    # Reload NGINX
    systemctl reload nginx
    
    echo "Maintenance mode deactivated for ${domain}"
}

status_maintenance() {
    if [ -f "\$MAINTENANCE_FLAG" ]; then
        echo "Maintenance mode is active"
        cat "\$MAINTENANCE_FLAG"
    else
        echo "Maintenance mode is inactive"
    fi
}

case "\$1" in
    start)
        start_maintenance "\${2:-7200}" "\${3:-Scheduled maintenance in progress}"
        ;;
    stop)
        stop_maintenance
        ;;
    status)
        status_maintenance
        ;;
    *)
        echo "Usage: \$0 {start|stop|status} [duration_seconds] [message]"
        exit 1
        ;;
esac
EOF
    
    # Make script executable
    chmod +x "/usr/local/bin/maintenance-${domain}.sh"
    chown root:root "/usr/local/bin/maintenance-${domain}.sh"
    
    # Set permissions for maintenance directory
    chown -R "${site_user}:${site_user}" "$maint_dir"
    chmod 750 "$maint_dir"
}

# Add maintenance mode setup to main site setup
setup_site() {
    local domain_entry=$1
    local domain=$(extract_domain_info "$domain_entry" 1)
    local domain_type=$(extract_domain_info "$domain_entry" 2)
    
    log_message "Setting up site: ${domain}"
    
    # Create site user
    local site_user=$(create_site_user "${domain}")
    
    # Setup directory structure
    setup_directory_structure "${domain}" "${site_user}"
    
    # Setup maintenance mode
    setup_maintenance_mode "${domain}" "${site_user}"
    
    # Continue with existing setup...
    case ${domain_type} in
        "html")
            setup_html_site "${domain}" "${site_user}" "${domain_entry}"
            ;;
        "php")
            setup_php_site "${domain}" "${site_user}" "${domain_entry}"
            ;;
        "python")
            setup_python_site "${domain}" "${site_user}" "${domain_entry}"
            ;;
    esac
    
    # Rest of the setup...
}

# Main execution
main() {
    check_root
    update_system
    setup_firewall
    
    for domain_entry in "${domains[@]}"; do
        setup_site "${domain_entry}"
    done
    
    finalize_setup
    
    log_message "Setup completed successfully!"
}

main "$@"