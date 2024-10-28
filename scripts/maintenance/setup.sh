# scripts/maintenance/setup.sh
#!/bin/bash

setup_maintenance_system() {
    local domain=$1
    local site_user=$2
    
    log_message "INFO" "Setting up maintenance system for ${domain}"
    
    # Create maintenance directories and files
    create_maintenance_structure "$domain" "$site_user"
    
    # Setup maintenance configuration
    setup_maintenance_config "$domain"
    
    # Create maintenance page
    setup_maintenance_page "$domain"
    
    # Configure nginx for maintenance mode
    setup_maintenance_nginx "$domain"
    
    # Create maintenance control script
    create_maintenance_script "$domain"
}

create_maintenance_structure() {
    local domain=$1
    local site_user=$2
    
    # Create directories
    mkdir -p "/var/www/${domain}/maintenance"
    mkdir -p "/var/www/${domain}/maintenance/logs"
    mkdir -p "/var/www/${domain}/maintenance/status"
    
    # Set permissions
    chown -R "${site_user}:${site_user}" "/var/www/${domain}/maintenance"
    chmod -R 750 "/var/www/${domain}/maintenance"
}
