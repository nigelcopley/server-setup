# scripts/ssl.sh
#!/bin/bash

setup_ssl() {
    local domain=$1
    
    # Install certbot if not already installed
    if ! command -v certbot >/dev/null; then
        apt-get install -y certbot python3-certbot-nginx
    fi

    # Obtain SSL certificate
    certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "${ADMIN_EMAIL}" \
        --domains "${domain}" \
        --redirect

    # Configure auto-renewal
    systemctl enable certbot.timer
    systemctl start certbot.timer
}
