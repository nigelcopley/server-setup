# config/monitoring/check-services.sh
#!/bin/bash

check_service() {
    local domain=$1
    local config_file="/var/www/${domain}/config/monitor.conf"
    local output_file="/var/www/${domain}/monitoring/status.json"
    local log_file="/var/www/${domain}/logs/monitor.log"
    
    # Initialize status object
    cat > "$output_file" <<EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "services": {},
    "resources": {},
    "events": []
}
EOF
    
    # Check services
    check_process_services "$domain" "$output_file"
    check_resource_usage "$domain" "$output_file"
    check_ssl_certificates "$domain" "$output_file"
    check_logs "$domain" "$output_file"
    
    # Log update
    echo "[$(date)] Status check completed for ${domain}" >> "$log_file"
}

check_process_services() {
    local domain=$1
    local output_file=$2
    
    # Check NGINX
    if systemctl is-active --quiet nginx; then
        add_service_status "$output_file" "nginx" "ok" "Running"
    else
        add_service_status "$output_file" "nginx" "error" "Not running"
    fi
    
    # Check PHP-FPM
    if systemctl is-active --quiet "php*-fpm"; then
        add_service_status "$output_file" "php-fpm" "ok" "Running"
    else
        add_service_status "$output_file" "php-fpm" "error" "Not running"
    fi
}

check_resource_usage() {
    local domain=$1
    local output_file=$2
    
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F. '{print $1}')
    add_resource_metric "$output_file" "cpu" "${cpu_usage}%"
    
    # Memory Usage
    local memory_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    add_resource_metric "$output_file" "memory" "${memory_usage}%"
    
    # Disk Usage
    local disk_usage=$(df -h "/var/www/${domain}" | tail -1 | awk '{print $5}' | sed 's/%//')
    add_resource_metric "$output_file" "disk" "${disk_usage}%"
}

check_ssl_certificates() {
    local domain=$1
    local output_file=$2
    local cert_file="/etc/letsencrypt/live/${domain}/fullchain.pem"
    
    if [[ -f "$cert_file" ]]; then
        local expiry=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry" +%s)
        local now=$(date +%s)
        local days_left=$(( ($expiry_epoch - $now) / 86400 ))
        
        if [[ $days_left -lt 7 ]]; then
            add_service_status "$output_file" "ssl" "error" "Expires in ${days_left} days"
        elif [[ $days_left -lt 30 ]]; then
            add_service_status "$output_file" "ssl" "warning" "Expires in ${days_left} days"
        else
            add_service_status "$output_file" "ssl" "ok" "Valid for ${days_left} days"
        fi
    else
        add_service_status "$output_file" "ssl" "error" "Certificate not found"
    fi
}

check_logs() {
    local domain=$1
    local output_file=$2
    local log_file="/var/www/${domain}/logs/error.log"
    
    if [[ -f "$log_file" ]]; then
        # Check for recent errors
        local recent_errors=$(tail -n 100 "$log_file" | grep -i "error" | wc -l)
        if [[ $recent_errors -gt 0 ]]; then
            add_event "$output_file" "warning" "Found ${recent_errors} recent errors in logs"
        fi
    fi
}

add_service_status() {
    local file=$1
    local service=$2
    local status=$3
    local message=$4
    
    local temp_file="${file}.tmp"
    jq ".services.\"${service}\" = {\"status\": \"${status}\", \"message\": \"${message}\"}" "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

add_resource_metric() {
    local file=$1
    local metric=$2
    local value=$3
    
    local temp_file="${file}.tmp"
    jq ".resources.\"${metric}\" = \"${value}\"" "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

add_event() {
    local file=$1
    local level=$2
    local message=$3
    
    local temp_file="${file}.tmp"
    jq ".events += [{\"time\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"level\": \"${level}\", \"message\": \"${message}\"}]" "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

# Run checks if domain is provided
if [[ -n "$1" ]]; then
    check_service "$1"
fi