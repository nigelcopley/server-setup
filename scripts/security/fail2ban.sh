# scripts/security/fail2ban.sh
#!/bin/bash

setup_fail2ban() {
    if [[ "${INSTALL_FAIL2BAN}" != "1" ]]; then
        return 0
    fi
    
    log_message "INFO" "Setting up Fail2Ban..."
    
    # Install fail2ban
    apt-get install -y fail2ban
    
    # Backup original config
    backup_file "/etc/fail2ban/jail.local"
    
    # Create custom configuration
    cat > "/etc/fail2ban/jail.local" <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
banaction = ufw
banaction_allports = ufw

[sshd]
enabled = true
port = ${SSH_PORT:-22}
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 3600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 7200

[nginx-badbots]
enabled = true
filter = nginx-badbots
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[php-url-fopen]
enabled = true
port = http,https
filter = php-url-fopen
logpath = /var/log/nginx/access.log
maxretry = 3
bantime = 3600
EOF
    
    # Create custom filters
    setup_fail2ban_filters
    
    # Start and enable service
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_message "INFO" "Fail2Ban setup completed"
}

setup_fail2ban_filters() {
    # Custom filter for PHP URL fopen attempts
    cat > "/etc/fail2ban/filter.d/php-url-fopen.conf" <<EOF
[Definition]
failregex = ^<HOST> .* (fopen|include|require)_url.*$
ignoreregex =
EOF

    # Custom filter for bad bots
    cat > "/etc/fail2ban/filter.d/nginx-badbots.conf" <<EOF
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD).*HTTP.*"$
ignoreregex = .*(friendly-scanner|UptimeRobot|Pingdom|GoogleBot|BingBot).*
EOF
}
