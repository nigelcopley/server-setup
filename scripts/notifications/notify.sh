# scripts/notifications/notify.sh
#!/bin/bash

# Main notification handler
send_notification() {
    local event_type=$1    # Type of event (error, warning, info, success)
    local message=$2       # Message content
    local title=$3         # Title/Subject
    local service=$4       # Service name (nginx, mysql, etc.)
    local domain=$5        # Domain name if applicable
    
    # Load notification preferences
    source /etc/multisite-server/notifications/config.sh
    
    # Create notification record
    local notification_id=$(generate_notification_id)
    log_notification "$notification_id" "$event_type" "$service" "$message"
    
    # Send notifications based on configuration and event type
    for channel in "${NOTIFICATION_CHANNELS[@]}"; do
        case "$channel" in
            "email")
                [[ "${ENABLE_EMAIL_NOTIFICATIONS}" == "1" ]] && 
                    send_email_notification "$notification_id" "$event_type" "$title" "$message" "$service" "$domain"
                ;;
            "slack")
                [[ "${ENABLE_SLACK_NOTIFICATIONS}" == "1" ]] && 
                    send_slack_notification "$notification_id" "$event_type" "$title" "$message" "$service" "$domain"
                ;;
            "discord")
                [[ "${ENABLE_DISCORD_NOTIFICATIONS}" == "1" ]] && 
                    send_discord_notification "$notification_id" "$event_type" "$title" "$message" "$service" "$domain"
                ;;
            "telegram")
                [[ "${ENABLE_TELEGRAM_NOTIFICATIONS}" == "1" ]] && 
                    send_telegram_notification "$notification_id" "$event_type" "$title" "$message" "$service" "$domain"
                ;;
        esac
    done
}