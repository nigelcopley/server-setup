# scripts/notifications/utils.sh
#!/bin/bash

generate_notification_id() {
    echo "$(date +%s)-$(openssl rand -hex 4)"
}

log_notification() {
    local notification_id=$1
    local event_type=$2
    local service=$3
    local message=$4
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$notification_id] [$event_type] [$service] $message" >> \
        "$NOTIFICATION_LOG"
}

rotate_notification_logs() {
    find "/var/log/multisite-server/notifications" -name "*.log" -mtime +${NOTIFICATION_RETENTION_DAYS} -delete
}

check_rate_limit() {
    local service=$1
    local current_time=$(date +%s)
    local rate_file="/tmp/notification_rate_${service}"
    
    # Create or load rate file
    touch "$rate_file"
    local notifications=($(cat "$rate_file"))
    
    # Remove old timestamps
    local new_notifications=()
    for timestamp in "${notifications[@]}"; do
        if (( current_time - timestamp < NOTIFICATION_RATE_LIMIT )); then
            new_notifications+=($timestamp)
        fi
    done
    
    # Check burst limit
    if (( ${#new_notifications[@]} >= NOTIFICATION_BURST_LIMIT )); then
        return 1
    fi
    
    # Add new timestamp
    new_notifications+=($current_time)
    printf "%s\n" "${new_notifications[@]}" > "$rate_file"
    
    return 0
}