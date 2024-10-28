# scripts/user/site-user.sh
#!/bin/bash

setup_site_user() {
    local domain=$1
    local type=$2
    
    local username="site_${domain//./_}"
    local password=$(generate_password 32)
    
    log_message "INFO" "Setting up site user: ${username}"
    
    # Create user
    useradd --system \
        --shell /usr/sbin/nologin \
        --home-dir "/var/www/${domain}" \
        --create-home \
        "$username"
    
    # Set password
    echo "${username}:${password}" | chpasswd
    
    # Store credentials
    store_site_credentials "$domain" "$username" "$password"
    
    # Setup directory structure
    setup_site_directories "$domain" "$username" "$type"
    
    # Setup permissions
    setup_site_permissions "$domain" "$username" "$type"
    
    log_message "INFO" "Site user setup completed"
    
    echo "$username"
}

setup_site_directories() {
    local domain=$1
    local username=$2
    local type=$3
    
    local base_dir="/var/www/${domain}"
    
    # Create base directories
    mkdir -p "${base_dir}"/{host,logs,config,sessions,tmp,backup}
    
    # Type-specific directories
    case $type in
        "php")
            mkdir -p "${base_dir}"/{cache,sessions,uploads}
            ;;
        "python")
            mkdir -p "${base_dir}"/{venv,static,media}
            ;;
        "html")
            mkdir -p "${base_dir}"/{assets,public}
            ;;
    esac
    
    # Set ownership
    chown -R "${username}:${username}" "$base_dir"
}

setup_site_permissions() {
    local domain=$1
    local username=$2
    local type=$3
    
    local base_dir="/var/www/${domain}"
    
    # Set base permissions
    chmod 750 "$base_dir"
    
    # Set directory permissions
    find "$base_dir" -type d -exec chmod 750 {} \;
    find "$base_dir" -type f -exec chmod 640 {} \;
    
    # Set specific permissions
    chmod 770 "${base_dir}/tmp"
    chmod 770 "${base_dir}/logs"
    
    case $type in
        "php")
            chmod 770 "${base_dir}/sessions"
            chmod 770 "${base_dir}/uploads"
            ;;
        "python")
            chmod 770 "${base_dir}/media"
            ;;
    esac
    
    # Set ACLs for web server
    setfacl -R -m u:www-data:rx "$base_dir"
    setfacl -R -m d:u:www-data:rx "$base_dir"
}

# scripts/user/utils.sh
#!/bin/bash

store_admin_credentials() {
    local username=$1
    local password=$2
    
    # Create secure credentials directory
    local creds_dir="/root/.server-credentials"
    mkdir -p "$creds_dir"
    chmod 700 "$creds_dir"
    
    # Store credentials
    cat > "${creds_dir}/admin-credentials.txt" <<EOF
Username: ${username}
Password: ${password}
Created: $(date)
SSH Public Key: $(cat "/home/${username}/.ssh/id_rsa.pub")
EOF
    
    chmod 600 "${creds_dir}/admin-credentials.txt"
}

store_site_credentials() {
    local domain=$1
    local username=$2
    local password=$3
    
    cat >> "${CREDENTIALS_FILE}" <<EOF
Site: ${domain}
Username: ${username}
Password: ${password}
Created: $(date)
----------------------------------------
EOF
}

generate_password() {
    local length=${1:-32}
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

change_user_password() {
    local username=$1
    local new_password=$(generate_password 32)
    
    echo "${username}:${new_password}" | chpasswd
    
    # Update stored credentials
    if [[ "$username" == "$NEW_USER" ]]; then
        store_admin_credentials "$username" "$new_password"
    else
        local domain=${username#site_}
        domain=${domain//_/.}
        store_site_credentials "$domain" "$username" "$new_password"
    fi
    
    echo "$new_password"
}

disable_user() {
    local username=$1
    usermod -L "$username"
    log_message "INFO" "User ${username} disabled"
}

enable_user() {
    local username=$1
    usermod -U "$username"
    log_message "INFO" "User ${username} enabled"
}