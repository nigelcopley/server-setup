# scripts/cleanup.sh
#!/bin/bash

cleanup_installation() {
    local domain=$1
    
    # Remove default nginx site if exists
    rm -f /etc/nginx/sites-enabled/default

    # Secure tmp directories
    find "/var/www/${domain}" -type d -name "tmp" -exec chmod 750 {} \;

    # Remove installation files
    rm -f "/var/www/${domain}/installation.log"
    
    # Secure configuration files
    find "/var/www/${domain}/config" -type f -exec chmod 640 {} \;
}