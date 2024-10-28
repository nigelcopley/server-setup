# scripts/user/server-user.sh
#!/bin/bash

setup_server_user() {
    local username="${NEW_USER:-admin}"
    local password="${USER_PASSWORD:-$(openssl rand -base64 16)}"
    
    log_message "Setting up main server user: ${username}"
    
    # Create user if doesn't exist
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"
        echo "${username}:${password}" | chpasswd
        
        # Add to sudo group
        usermod -aG sudo "$username"
        
        # Store credentials securely
        store_admin_credentials "$username" "$password"
        
        # Setup sudo without password for specific commands
        setup_sudo_access "$username"
        
        # Setup SSH directory
        setup_ssh_directory "$username"
        
        log_message "Server user created successfully"
    else
        log_message "User ${username} already exists"
    fi
}

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
EOF
    
    chmod 600 "${creds_dir}/admin-credentials.txt"
    
    # Also store in the standard credentials file
    echo "Main Server User Credentials" >> "$CREDENTIALS_FILE"
    echo "Username: ${username}" >> "$CREDENTIALS_FILE"
    echo "Password: ${password}" >> "$CREDENTIALS_FILE"
    echo "----------------------------------------" >> "$CREDENTIALS_FILE"
}

setup_sudo_access() {
    local username=$1
    
    # Create sudo rules file
    cat > "/etc/sudoers.d/$username" <<EOF
# Sudo rules for $username
$username ALL=(ALL) NOPASSWD: /usr/sbin/nginx
$username ALL=(ALL) NOPASSWD: /usr/sbin/php-fpm*
$username ALL=(ALL) NOPASSWD: /usr/local/bin/maintenance-*.sh
$username ALL=(ALL) NOPASSWD: /usr/local/bin/backup-*.sh
$username ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
$username ALL=(ALL) NOPASSWD: /bin/systemctl restart php*-fpm
EOF
    
    # Secure the sudo rules file
    chmod 440 "/etc/sudoers.d/$username"
}

setup_ssh_directory() {
    local username=$1
    local ssh_dir="/home/${username}/.ssh"
    
    # Create SSH directory
    mkdir -p "$ssh_dir"
    
    # Copy SSH keys from root if they exist
    if [[ -f "/root/.ssh/authorized_keys" ]]; then
        cp "/root/.ssh/authorized_keys" "${ssh_dir}/authorized_keys"
    fi
    
    # Set proper permissions
    chown -R "${username}:${username}" "$ssh_dir"
    chmod 700 "$ssh_dir"
    [[ -f "${ssh_dir}/authorized_keys" ]] && chmod 600 "${ssh_dir}/authorized_keys"
}

# Update config.sh to include these options
cat >> config.sh <<EOF

# Server User Configuration
NEW_USER="${NEW_USER:-admin}"
USER_PASSWORD="${USER_PASSWORD:-}"  # Will be auto-generated if empty
COPY_ROOT_SSH_KEYS=1
EOF

# Update main setup.sh to include server user creation
update_setup_script() {
    # Add to main function in setup.sh
    cat > setup.sh.tmp <<EOF
#!/bin/bash

set -euo pipefail

# Script directory
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
source "\${SCRIPT_DIR}/config.sh"

# Load all function scripts
for script in "\${SCRIPT_DIR}/scripts/"*.sh; do
    source "\$script"
done

# Initialize logging
setup_logging

# Main execution
main() {
    check_root
    update_system
    
    # Create main server user
    setup_server_user
    
    setup_firewall
    
    for domain_entry in "\${domains[@]}"; do
        setup_site "\${domain_entry}"
    done
    
    finalize_setup
    
    # Show credentials location
    log_message "Setup completed successfully!"
    log_message "Admin credentials stored in /root/.server-credentials/admin-credentials.txt"
}

main "\$@"
EOF

    mv setup.sh.tmp setup.sh
    chmod +x setup.sh
}

# Utility functions for user management
list_server_users() {
    log_message "Server Users:"
    grep -E '^admin|^NEW_USER' /etc/passwd | cut -d: -f1
}

change_user_password() {
    local username=$1
    local new_password=$2
    
    if id "$username" &>/dev/null; then
        echo "${username}:${new_password}" | chpasswd
        log_message "Password changed for user ${username}"
    else
        log_message "Error: User ${username} does not exist"
        return 1
    fi
}

add_ssh_key() {
    local username=$1
    local ssh_key=$2
    local ssh_dir="/home/${username}/.ssh"
    
    if ! id "$username" &>/dev/null; then
        log_message "Error: User ${username} does not exist"
        return 1
    fi
    
    mkdir -p "$ssh_dir"
    echo "$ssh_key" >> "${ssh_dir}/authorized_keys"
    sort -u "${ssh_dir}/authorized_keys" -o "${ssh_dir}/authorized_keys"
    
    chown -R "${username}:${username}" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "${ssh_dir}/authorized_keys"
    
    log_message "SSH key added for user ${username}"
}

# Add to config/templates/bash_aliases.template
cat > config/templates/bash_aliases.template <<EOF
# Server management aliases
alias server-status='sudo systemctl status nginx php*-fpm mysql postgresql'
alias nginx-reload='sudo systemctl reload nginx'
alias php-reload='sudo systemctl restart php*-fpm'
alias show-logs='tail -f /var/log/nginx/error.log /var/log/php*-fpm.log'
alias list-sites='ls -l /etc/nginx/sites-enabled/'
alias check-ssl='sudo certbot certificates'
alias server-update='sudo apt update && sudo apt upgrade -y'
EOF