# scripts/web/nginx.sh
#!/bin/bash

setup_nginx() {
    log_message "INFO" "Setting up NGINX..."

    # Install NGINX
    apt-get install -y nginx

    # Create custom configuration directories
    mkdir -p /etc/nginx/conf.d/custom
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled

    # Configure main NGINX settings
    configure_nginx_main
    configure_nginx_security
    configure_nginx_performance
    
    # Test and restart
    nginx -t && systemctl restart nginx
}

configure_nginx_main() {
    cat > "/etc/nginx/nginx.conf" <<EOF
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    multi_accept on;
    worker_connections 65535;
}

http {
    charset utf-8;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    types_hash_max_size 2048;
    server_tokens off;
    
    # MIME
    include mime.types;
    default_type application/octet-stream;
    
    # Logging
    access_log /var/log/nginx/access.log combined buffer=512k flush=1m;
    error_log /var/log/nginx/error.log warn;
    
    # Limits
    limit_req_zone \$binary_remote_addr zone=one:10m rate=1r/s;
    client_max_body_size 16M;
    
    # SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Load configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
}

configure_nginx_security() {
    cat > "/etc/nginx/conf.d/security.conf" <<EOF
# Security configurations
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# DH parameters
ssl_dhparam /etc/nginx/dhparam.pem;

# Security headers
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF

    # Generate DH parameters
    openssl dhparam -out /etc/nginx/dhparam.pem 2048
}

configure_nginx_performance() {
    cat > "/etc/nginx/conf.d/performance.conf" <<EOF
# Gzip Settings
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

# FastCGI cache
fastcgi_cache_path /var/run/nginx-cache levels=1:2 keys_zone=CACHEZONE:100m inactive=60m;
fastcgi_cache_key "\$scheme\$request_method\$host\$request_uri";
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_cache_valid 200 60m;

# Browser cache
location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
    expires 30d;
    add_header Cache-Control "public, no-transform";
}
EOF
}

setup_site_nginx() {
    local domain=$1
    local type=$2
    local template=""

    case $type in
        "php")
            template="php-site.conf"
            ;;
        "python")
            template="python-site.conf"
            ;;
        "html")
            template="html-site.conf"
            ;;
        *)
            log_message "ERROR" "Unknown site type: $type"
            return 1
            ;;
    esac

    # Copy and configure site template
    envsubst < "/etc/nginx/site-templates/$template" > "/etc/nginx/sites-available/$domain"
    ln -sf "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain"

    # Test configuration
    nginx -t
}