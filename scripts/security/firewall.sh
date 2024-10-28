# scripts/security/firewall.sh
#!/bin/bash

setup_firewall() {
    log_message "INFO" "Configuring firewall..."
    
    # Install UFW if not present
    if ! command_exists ufw; then
        apt-get install -y ufw
    fi
    
    # Reset UFW to default state
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (before enabling firewall)
    ufw allow ${SSH_PORT:-22}/tcp comment 'SSH'
    
    # Web traffic
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Additional configured ports
    if [[ -n "${ADDITIONAL_PORTS}" ]]; then
        for port in ${ADDITIONAL_PORTS}; do
            if validate_port "$port"; then
                ufw allow "$port" comment "Custom port"
            else
                log_message "WARNING" "Invalid port number: $port"
            fi
        done
    fi
    
    # Rate limiting rules
    cat > /etc/ufw/before.rules.local <<EOF
# Rate limiting rules
-A ufw-before-input -p tcp --dport ${SSH_PORT:-22} -i eth0 -m state --state NEW -m recent --set
-A ufw-before-input -p tcp --dport ${SSH_PORT:-22} -i eth0 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
EOF
    
    # Enable UFW
    echo "y" | ufw enable
    
    # Show status
    ufw status verbose
    
    log_message "INFO" "Firewall configuration completed"
}
