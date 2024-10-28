# scripts/monitoring/alerts.sh
#!/bin/bash

check_alerts() {
    local domain=$1
    local threshold_file="/var/www/${domain}/config/monitoring/thresholds.conf"
    local alert_log="/var/www/${domain}/logs/alerts.log"

    # Load thresholds
    source "$threshold_file"

    # Check CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        send_alert "CPU usage above threshold: ${cpu_usage}%" "cpu" "$domain"
    fi

    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    if (( $(echo "$mem_usage > $MEMORY_THRESHOLD" | bc -l) )); then
        send_alert "Memory usage above threshold: ${mem_usage}%" "memory" "$domain"
    fi

    # Check disk usage
    local disk_usage=$(df -h /var/www/${domain} | awk 'NR==2 {print $5}' | tr -d '%')
    if (( disk_usage > DISK_THRESHOLD )); then
        send_alert "Disk usage above threshold: ${disk_usage}%" "disk" "$domain"
    fi
}

send_alert() {
    local message=$1
    local type=$2
    local domain=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log alert
    echo "[${timestamp}] [${type}] ${message}" >> "/var/www/${domain}/logs/alerts.log"

    # Send notifications
    if [[ "${ENABLE_EMAIL_NOTIFICATIONS}" == "1" ]]; then
        send_email_alert "$message" "$type" "$domain"
    fi

    if [[ "${ENABLE_SLACK_NOTIFICATIONS}" == "1" ]]; then
        send_slack_alert "$message" "$type" "$domain"
    fi
}