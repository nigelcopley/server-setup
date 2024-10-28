# scripts/notifications/email.sh
#!/bin/bash

send_email_notification() {
    local notification_id=$1
    local event_type=$2
    local title=$3
    local message=$4
    local service=$5
    local domain=$6
    
    # Load email template
    local template=$(get_email_template "$event_type")
    
    # Replace placeholders
    template=${template//\{\{TITLE\}\}/$title}
    template=${template//\{\{MESSAGE\}\}/$message}
    template=${template//\{\{SERVICE\}\}/$service}
    template=${template//\{\{DOMAIN\}\}/$domain}
    template=${template//\{\{TIMESTAMP\}\}/$(date '+%Y-%m-%d %H:%M:%S')}
    template=${template//\{\{NOTIFICATION_ID\}\}/$notification_id}
    
    # Send email
    echo "$template" | mail -s "$title - [$event_type]" \
        -a "From: ${NOTIFICATION_FROM_NAME} <${NOTIFICATION_FROM_EMAIL}>" \
        -a "Content-Type: text/html" \
        "${NOTIFICATION_EMAIL}"
}