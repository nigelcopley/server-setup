# scripts/check-status.sh
#!/bin/bash

set -euo pipefail

check_status() {
    local domain=$1
    local status_file="/var/www/${domain}/logs/status.json"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check core services
    local nginx_status=$(systemctl is-active nginx)
    local php_status=$(systemctl is-active php*-fpm)
    local web_status=$(curl -sI "https://${domain}" | head -n1)
    
    # Check SSL certificate
    local ssl_expiry=$(openssl s_client -connect "${domain}:443" -servername "${domain}" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null)
    
    # Check disk space
    local disk_usage=$(df -h "/var/www/${domain}" | awk 'NR==2 {print $5}')
    
    # Check recent errors in logs
    local recent_errors=$(tail -n 100 "/var/www/${domain}/logs/error.log" | grep -c "error\|critical" || true)
    
    # Create status report
    cat > "$status_file" <<EOF
{
    "timestamp": "${current_time}",
    "domain": "${domain}",
    "services": {
        "nginx": "${nginx_status}",
        "php_fpm": "${php_status}",
        "web_status": "${web_status}"
    },
    "ssl": {
        "expiry": "${ssl_expiry}"
    },
    "resources": {
        "disk_usage": "${disk_usage}",
        "recent_errors": ${recent_errors}
    }
}
EOF

    # Output status
    cat "$status_file"
}

# Usage check
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 domain"
    exit 1
fi

check_status "$1"