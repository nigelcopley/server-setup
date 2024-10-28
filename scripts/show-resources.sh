# scripts/show-resources.sh
#!/bin/bash

set -euo pipefail

show_resources() {
    local domain=$1
    local domain_user="site_${domain//./_}"
    
    echo "Resource Usage Report for ${domain}"
    echo "================================"
    
    # Process usage
    echo -e "\nProcess Information:"
    ps aux | grep -E "${domain}|${domain_user}" | grep -v grep
    
    # Memory usage
    echo -e "\nMemory Usage:"
    free -h
    
    # Disk usage
    echo -e "\nDisk Usage:"
    du -sh "/var/www/${domain}"/*
    
    # PHP-FPM pool status
    if [[ -S "/run/php-fpm/${domain}.sock" ]]; then
        echo -e "\nPHP-FPM Pool Status:"
        SCRIPT='<?php echo json_encode(array_merge(array("pool_status" => "active"), array("memory_usage" => memory_get_usage(true)))); ?>'
        RESPONSE=$(echo "$SCRIPT" | cgi-fcgi -bind -connect "/run/php-fpm/${domain}.sock")
        echo "$RESPONSE" | grep -v "X-Powered-By"
    fi
    
    # NGINX status
    echo -e "\nNGINX Connections:"
    nginx -V 2>&1
    netstat -an | grep :80 | grep ESTABLISHED | wc -l
    
    # Log sizes
    echo -e "\nLog Sizes:"
    ls -lh "/var/www/${domain}/logs/"
}

# Usage check
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 domain"
    exit 1
fi

show_resources "$1"
