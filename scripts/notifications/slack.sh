# scripts/notifications/slack.sh
#!/bin/bash

send_slack_notification() {
    local notification_id=$1
    local event_type=$2
    local title=$3
    local message=$4
    local service=$5
    local domain=$6
    
    # Determine color based on event type
    local color
    case "$event_type" in
        "error")   color="#FF0000" ;; # Red
        "warning") color="#FFA500" ;; # Orange
        "info")    color="#0000FF" ;; # Blue
        "success") color="#00FF00" ;; # Green
        *)         color="#808080" ;; # Grey
    esac
    
    # Create JSON payload
    local payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "${color}",
            "title": "${title}",
            "text": "${message}",
            "fields": [
                {
                    "title": "Service",
                    "value": "${service}",
                    "short": true
                },
                {
                    "title": "Domain",
                    "value": "${domain}",
                    "short": true
                }
            ],
            "footer": "Notification ID: ${notification_id}",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    # Send to Slack
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${SLACK_WEBHOOK_URL}"
}