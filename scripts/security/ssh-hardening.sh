#!/bin/bash

setup_ssh_hardening() {
    log_message "Configuring SSH security..."
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Configure SSH
    cat > "/etc/ssh/sshd_config.d/security.conf" <<EOF
Port ${SSH_PORT:-22}
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowAgentForwarding no
AllowTcpForwarding no
EOF
    
    systemctl reload sshd
}