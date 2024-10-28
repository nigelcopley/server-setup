# scripts/security.sh - Security setup functions
#!/bin/bash

setup_firewall() {
    if [[ "${FIREWALL_ENABLE}" != "1" ]]; then
        return
    fi
    
    log_message "Setting up firewall..."
    ufw allow OpenSSH
    ufw allow 'Nginx Full'
    ufw --force enable
}

setup_fail2ban() {
    if [[ "${FAIL2BAN_ENABLE}" != "1" ]]; then
        return
    fi
    
    log_message "Setting up Fail2ban..."
    apt-get install -y fail2ban
    
    cat > /etc/fail2ban/jail.local <<EOF
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

    systemctl restart fail2ban
}
