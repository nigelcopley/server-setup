#!/bin/bash

setup_ssl() {
    local domain=$1
    local email=$2
    
    if ! command -v certbot &>/dev/null; then
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    if ! certbot certificates | grep -q "${domain}"; then
        certbot --nginx \
            -d "${domain}" \
            --non-interactive \
            --agree-tos \
            -m "${email}" \
            --redirect \
            --hsts \
            --staple-ocsp
            
        systemctl enable certbot.timer
        systemctl start certbot.timer
    fi
}