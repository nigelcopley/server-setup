# scripts/security/ssh.sh
#!/bin/bash

setup_ssh_security() {
    log_message "INFO" "Configuring SSH security..."
    
    # Backup original config
    backup_file "/etc/ssh/sshd_config"
    
    # Create custom config
    cat > "/etc/ssh/sshd_config.d/security.conf" <<EOF
# Security configuration for SSH
Port ${SSH_PORT:-22}
Protocol 2

# Authentication
PermitRootLogin no
PasswordAuthentication ${SSH_ALLOW_PASSWORDS:-no}
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
AuthenticationMethods publickey

# Session configuration
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxStartups 10:30:60
MaxSessions 4

# Security
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Allow only specific users/groups
AllowGroups sudo ${NEW_USER}
EOF

    # Set proper permissions
    chmod 600 /etc/ssh/sshd_config.d/security.conf
    
    # Test configuration
    if ! sshd -t; then
        log_message "ERROR" "SSH configuration test failed"
        return 1
    fi
    
    # Restart SSH service
    systemctl restart sshd
    
    log_message "INFO" "SSH security configuration completed"
}