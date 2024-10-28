# scripts/maintenance/control.sh
#!/bin/bash

create_maintenance_script() {
    local domain=$1
    local script_path="/usr/local/bin/maintenance-${domain}"
    
    cat > "$script_path" <<'EOF'
#!/bin/bash

set -euo pipefail

DOMAIN="$1"
ACTION="$2"
MAINTENANCE_DIR="/var/www/${DOMAIN}/maintenance"
STATUS_FILE="${MAINTENANCE_DIR}/status/maintenance.json"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"

# Load configuration
source "${MAINTENANCE_DIR}/config/maintenance.conf"

start_maintenance() {
    local duration=${1:-7200}  # Default 2 hours
    local message="$2"
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    # Create status file
    cat > "$STATUS_FILE" <<EOL
{
    "status": "active",
    "start_time": ${start_time},
    "end_time": ${end_time},
    "duration": ${duration},
    "message": "${message}",
    "allowed_ips": [
        $(printf '"%s",' "${MAINTENANCE_ALLOWED_IPS[@]}" | sed 's/,$//')
    ]
}
EOL
    
    # Enable maintenance mode in nginx
    sed -i '/maintenance_mode/d' "$NGINX_CONF"
    sed -i '/location \/ {/a \    if (-f $document_root/../maintenance/status/maintenance.json) { return 503; }' "$NGINX_CONF"
    
    # Add maintenance error page
    sed -i '/error_page 503/d' "$NGINX_CONF"
    echo "error_page 503 /maintenance/index.html;" >> "$NGINX_CONF"
    
    # Reload nginx
    systemctl reload nginx
    
    # Send notifications
    notify_maintenance_start "$DOMAIN" "$duration" "$message"
    
    # Log action
    log_maintenance_action "start" "$duration" "$message"
}

stop_maintenance() {
    # Remove maintenance status
    rm -f "$STATUS_FILE"
    
    # Update nginx configuration
    sed -i '/maintenance_mode/d' "$NGINX_CONF"
    sed -i '/error_page 503/d' "$NGINX_CONF"
    
    # Reload nginx
    systemctl reload nginx
    
    # Send notifications
    notify_maintenance_stop "$DOMAIN"
    
    # Log action
    log_maintenance_action "stop"
}

check_maintenance() {
    if [[ -f "$STATUS_FILE" ]]; then
        local data=$(cat "$STATUS_FILE")
        local end_time=$(echo "$data" | jq -r '.end_time')
        local current_time=$(date +%s)
        
        if (( current_time > end_time )); then
            stop_maintenance
            echo "Maintenance mode expired and has been disabled"
        else
            local remaining=$((end_time - current_time))
            echo "Maintenance mode active"
            echo "Time remaining: $(format_duration $remaining)"
            echo "Message: $(echo "$data" | jq -r '.message')"
        fi
    else
        echo "Maintenance mode is not active"
    fi
}

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    echo "${hours}h ${minutes}m"
}

log_maintenance_action() {
    local action=$1
    local duration=$2
    local message=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] ${action} - Duration: ${duration}s - Message: ${message}" >> \
        "${MAINTENANCE_DIR}/logs/maintenance.log"
}

case "$ACTION" in
    start)
        start_maintenance "${3:-7200}" "${4:-Scheduled maintenance in progress}"
        ;;
    stop)
        stop_maintenance
        ;;
    status)
        check_maintenance
        ;;
    *)
        echo "Usage: $0 domain {start|stop|status} [duration_seconds] [message]"
        exit 1
        ;;
esac
EOF

    chmod +x "$script_path"
}
