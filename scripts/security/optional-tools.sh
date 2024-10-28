#!/bin/bash

setup_optional_tools() {
    local domain=$1
    
    # Install and configure Fail2Ban
    if [[ "${INSTALL_FAIL2BAN:-1}" == "1" ]]; then
        log_message "Setting up Fail2Ban..."
        install_fail2ban
    fi
    
    # Install and configure ClamAV
    if [[ "${INSTALL_CLAMAV:-1}" == "1" ]]; then
        log_message "Setting up ClamAV..."
        install_clamav "$domain"
    fi
    
    # Install and configure Redis
    if [[ "${INSTALL_REDIS:-0}" == "1" ]]; then
        log_message "Setting up Redis..."
        install_redis
    fi
}

install_fail2ban() {
    apt-get install -y fail2ban
    
    # Configure Fail2Ban
    cat > "/etc/fail2ban/jail.local" <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
}

install_clamav() {
    local domain=$1
    
    apt-get install -y clamav clamav-daemon
    systemctl stop clamav-freshclam
    freshclam
    systemctl start clamav-freshclam
    
    # Setup daily scan
    cat > "/etc/cron.daily/clamscan-${domain}" <<EOF
#!/bin/bash
clamscan -r /var/www/${domain} | logger -t clamav
EOF
    chmod +x "/etc/cron.daily/clamscan-${domain}"
}

install_redis() {
    apt-get install -y redis-server
    
    # Basic Redis hardening
    sed -i 's/^bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf
    sed -i 's/# requirepass foobared/requirepass '"$(openssl rand -base64 32)"'/' /etc/redis/redis.conf
    
    systemctl enable redis-server
    systemctl restart redis-server
}