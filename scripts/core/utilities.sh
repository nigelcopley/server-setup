# scripts/core/utilities.sh
#!/bin/bash

# Generate secure random string
generate_password() {
    local length=${1:-32}
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# Extract value from domain entry
get_domain_value() {
    local domain_entry=$1
    local field=$2
    echo "$domain_entry" | cut -d: -f"$field"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if service is running
service_is_running() {
    systemctl is-active --quiet "$1"
}

# Create directory with proper permissions
create_secure_directory() {
    local dir=$1
    local owner=$2
    local group=$3
    local perms=${4:-750}

    mkdir -p "$dir"
    chmod "$perms" "$dir"
    chown "$owner:$group" "$dir"
}

# Backup file before modification
backup_file() {
    local file=$1
    local backup="${file}.bak-$(date +%Y%m%d-%H%M%S)"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        log_message "INFO" "Created backup: $backup"
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service=$1
    local max_attempts=${2:-30}
    local attempt=1

    while ! service_is_running "$service"; do
        if ((attempt >= max_attempts)); then
            log_message "ERROR" "Service $service failed to start after $max_attempts attempts"
            return 1
        fi
        log_message "INFO" "Waiting for $service to start (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    return 0
}

# IP address validation
validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# URL validation
validate_url() {
    local url=$1
    if [[ $url =~ ^https?://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$ ]]; then
        return 0
    fi
    return 1
}

# Port validation
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    return 1
}

# Check disk space
check_disk_space() {
    local directory=$1
    local required_space=$2  # in MB
    
    local available_space=$(df -m "$directory" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        log_message "ERROR" "Insufficient disk space. Required: ${required_space}MB, Available: ${available_space}MB"
        return 1
    fi
    return 0
}

# Format file size
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while (( size > 1024 )); do
        size=$(( size / 1024 ))
        (( unit++ ))
    done
    
    echo "${size}${units[$unit]}"
}

# Check system requirements
check_system_requirements() {
    local min_ram=1024  # 1GB in MB
    local min_cpu=2
    local min_disk=20480  # 20GB in MB

    # Check RAM
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt "$min_ram" ]; then
        log_message "ERROR" "Insufficient RAM. Required: ${min_ram}MB, Available: ${total_ram}MB"
        return 1
    fi

    # Check CPU
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt "$min_cpu" ]; then
        log_message "ERROR" "Insufficient CPU cores. Required: $min_cpu, Available: $cpu_cores"
        return 1
    fi

    # Check Disk Space
    check_disk_space "/" "$min_disk" || return 1

    return 0
}

# System cleanup
cleanup() {
    log_message "INFO" "Performing system cleanup..."
    
    # Clean package cache
    apt-get clean
    apt-get autoremove -y
    
    # Remove temporary files
    find /tmp -type f -atime +7 -delete
    
    # Clean logs
    find /var/log -type f -name "*.gz" -delete
    find /var/log -type f -name "*.old" -delete
}