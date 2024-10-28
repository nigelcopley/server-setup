# scripts/logging.sh
#!/bin/bash

setup_logging() {
    local domain=$1
    
    # Create logging directories
    mkdir -p "/var/www/${domain}/logs"

    # Setup log rotation
    cat > "/etc/logrotate.d/${domain}" <<EOF
/var/www/${domain}/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 ${site_user} ${site_user}
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 \$(cat /var/run/nginx.pid)
    endscript
}
EOF

    # Setup error logging for PHP (if used)
    if [ -d "/etc/php" ]; then
        for version in /etc/php/*; do
            if [ -d "$version/fpm" ]; then
                sed -i "s|error_log = .*|error_log = /var/www/${domain}/logs/php_errors.log|" \
                    "$version/fpm/php.ini"
            fi
        done
    fi
}