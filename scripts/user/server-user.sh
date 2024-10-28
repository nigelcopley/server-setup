# scripts/user/server-user.sh
#!/bin/bash

setup_server_user() {
    local username="${NEW_USER:-admin}"
    local password="${USER_PASSWORD:-$(generate_password 32)}"
    
    log_message "INFO" "Setting up main server user: ${username}"
    
    # Create user if doesn't exist
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"
        echo "${username}:${password}" | chpasswd
        
        # Add to sudo group
        usermod -aG sudo "$username"
        
        # Store credentials
        store_admin_credentials "$username" "$password"
        
        # Setup sudo access
        setup_sudo_access "$username"
        
        # Setup SSH
        setup_ssh_access "$username"
        
        # Setup user environment
        setup_user_environment "$username"
        
        log_message "INFO" "Server user created successfully"
    else
        log_message "INFO" "User ${username} already exists"
    fi
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
    
    chmod 440 "/etc/sudoers.d/$username"
}

setup_ssh_access() {
    local username=$1
    local ssh_dir="/home/${username}/.ssh"
    
    # Create SSH directory
    mkdir -p "$ssh_dir"
    
    # Generate SSH key pair
    if [[ ! -f "${ssh_dir}/id_rsa" ]]; then
        ssh-keygen -t rsa -b 4096 -f "${ssh_dir}/id_rsa" -N "" -C "${username}@${HOSTNAME}"
    fi
    
    # Copy authorized keys from root if they exist
    if [[ -f "/root/.ssh/authorized_keys" ]]; then
        cp "/root/.ssh/authorized_keys" "${ssh_dir}/authorized_keys"
    fi
    
    # Set proper permissions
    chown -R "${username}:${username}" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "${ssh_dir}/id_rsa"
    chmod 644 "${ssh_dir}/id_rsa.pub"
    [[ -f "${ssh_dir}/authorized_keys" ]] && chmod 600 "${ssh_dir}/authorized_keys"
}

setup_user_environment() {
    local username=$1
    local home_dir="/home/${username}"
    
    # Create necessary directories
    mkdir -p "${home_dir}"/{bin,scripts,logs,backups}
    
    # Setup bash configuration
    cat > "${home_dir}/.bashrc" <<'EOF'
# Custom bash configuration
export PATH="$HOME/bin:$PATH"
export EDITOR=vim
export LANG=en_US.UTF-8

# Aliases
alias ll='ls -la'
alias l='ls -CF'
alias nginx-reload='sudo systemctl reload nginx'
alias php-reload='sudo systemctl restart php*-fpm'
alias check-logs='tail -f /var/log/nginx/error.log /var/log/php*-fpm.log'
alias check-sites='ls -l /etc/nginx/sites-enabled/'

# Custom functions
server-status() {
    echo "=== Server Status ==="
    echo "Nginx: $(systemctl is-active nginx)"
    echo "PHP-FPM: $(systemctl is-active php*-fpm)"
    echo "MySQL: $(systemctl is-active mysql)"
    echo "PostgreSQL: $(systemctl is-active postgresql)"
}

check-disk() {
    df -h /var/www/
}

check-memory() {
    free -h
}

check-certificates() {
    sudo certbot certificates
}
EOF
    
    # Setup vim configuration
    cat > "${home_dir}/.vimrc" <<'EOF'
syntax on
set number
set autoindent
set expandtab
set tabstop=4
set shiftwidth=4
set ignorecase
set smartcase
set hlsearch
set incsearch
set ruler
set showcmd
EOF
    
    # Set ownership
    chown -R "${username}:${username}" "$home_dir"
}
