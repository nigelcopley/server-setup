# scripts/user-management.sh - User management functions
#!/bin/bash

create_site_user() {
    local domain=$1
    local site_user="site_${domain//./_}"
    
    if ! id "$site_user" &>/dev/null; then
        log_message "Creating user $site_user"
        useradd --system --shell /usr/sbin/nologin --home-dir "/var/www/${domain}" "${site_user}"
        
        # Store credentials
        local site_password=$(openssl rand -base64 16)
        echo "${site_user}:${site_password}" >> "${CREDENTIALS_FILE}"
    fi
    
    echo "${site_user}"
}

setup_site_permissions() {
    local domain=$1
    local site_user=$2
    
    log_message "Setting up permissions for ${domain}"
    mkdir -p "/var/www/${domain}"/{host,logs,sessions,backup,tmp,config}
    chown -R "${site_user}:${site_user}" "/var/www/${domain}"
    chmod 750 "/var/www/${domain}"
}
