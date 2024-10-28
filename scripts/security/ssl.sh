# scripts/security/ssl.sh
#!/bin/bash

setup_ssl() {
    local domain=$1
    local email=$2
    
    log_message "INFO" "Setting up SSL for ${domain}"
    
    # Install certbot if not present
    if ! command_exists certbot; then
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Check for existing certificate
    if certbot certificates | grep -q "${domain}"; then
        log_message "INFO" "SSL certificate already exists for ${domain}"
        return 0
    fi
    
    # Optional: Stop nginx for standalone verification
    systemctl stop nginx
    
    # Obtain certificate
    if ! certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "${email}" \
        --domains "${domain}" \
        --preferred-challenges http \
        --http-01-port 80 \
        --rsa-key-size 4096 \
        --must-staple; then
        
        log_message "ERROR" "Failed to obtain SSL certificate for ${domain}"
        systemctl start nginx
        return 1
    fi
    
    # Start nginx
    systemctl start nginx
    
    # Setup auto-renewal
    setup_ssl_renewal "${domain}"
    
    log_message "INFO" "SSL setup completed for ${domain}"
}

setup_ssl_renewal() {
    local domain=$1
    
    # Create renewal hook directory
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    
    # Create renewal hook script
    cat > "/etc/letsencrypt/renewal-hooks/deploy/${domain}-hook.sh" <<EOF
#!/bin/bash
# Reload nginx after certificate renewal
systemctl reload nginx

# Send notification
if [[ -n "${NOTIFICATION_EMAIL}" ]]; then
    echo "SSL certificate renewed for ${domain}" | \
    mail -s "SSL Certificate Renewed - ${domain}" "${NOTIFICATION_EMAIL}"
fi
EOF
    
    chmod +x "/etc/letsencrypt/renewal-hooks/deploy/${domain}-hook.sh"
    
    # Setup renewal timer
    systemctl enable certbot.timer
    systemctl start certbot.timer
}