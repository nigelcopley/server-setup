# scripts/backup.sh
#!/bin/bash

setup_backup_system() {
    local domain=$1
    local site_user=$2
    local backup_config="/var/www/${domain}/config/backup.json"
    
    # Generate backup configuration
    envsubst < "${SCRIPT_DIR}/config/backup/backup.json.template" > "$backup_config"
    
    # Install required packages
    apt-get install -y awscli gpg
    
    # Create backup script
    create_backup_script "${domain}" "${site_user}"
    
    # Setup backup rotation
    setup_backup_rotation "${domain}"
    
    # Configure storage backends
    configure_backup_storage "${domain}"
    
    # Setup backup scheduling
    setup_backup_schedule "${domain}" "${site_user}"
}

create_backup_script() {
    local domain=$1
    local site_user=$2
    local backup_script="/usr/local/bin/backup-${domain}.sh"

    cat > "$backup_script" <<'EOF'
#!/bin/bash

set -euo pipefail

# Configuration
DOMAIN="$1"
CONFIG_FILE="/var/www/${DOMAIN}/config/backup.json"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="${DOMAIN}-${TIMESTAMP}"
TEMP_DIR="/tmp/backup-${DOMAIN}-${TIMESTAMP}"
LOG_FILE="/var/www/${DOMAIN}/logs/backup.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Function to send notifications
send_notification() {
    local subject="$1"
    local message="$2"
    local config=$(cat "$CONFIG_FILE")
    
    if [[ $(echo "$config" | jq -r '.notifications.enabled') == "true" ]]; then
        local email=$(echo "$config" | jq -r '.notifications.email')
        echo "$message" | mail -s "$subject" "$email"
    fi
}

# Function to compress backup
compress_backup() {
    local source=$1
    local dest=$2
    
    tar czf "$dest" -C "$(dirname "$source")" "$(basename "$source")"
}

# Function to encrypt backup
encrypt_backup() {
    local source=$1
    local dest="${source}.gpg"
    local config=$(cat "$CONFIG_FILE")
    
    if [[ $(echo "$config" | jq -r '.encryption.enabled') == "true" ]]; then
        local recipient=$(echo "$config" | jq -r '.encryption.gpg_recipient')
        gpg --encrypt --recipient "$recipient" --output "$dest" "$source"
        rm "$source"
        echo "$dest"
    else
        echo "$source"
    fi
}

# Function to store backup locally
store_local_backup() {
    local source=$1
    local config=$(cat "$CONFIG_FILE")
    
    if [[ $(echo "$config" | jq -r '.storage.local.enabled') == "true" ]]; then
        local path=$(echo "$config" | jq -r '.storage.local.path')
        mkdir -p "$path"
        cp "$source" "${path}/$(basename "$source")"
        log_message "Backup stored locally at ${path}/$(basename "$source")"
    fi
}

# Function to store backup in S3
store_s3_backup() {
    local source=$1
    local config=$(cat "$CONFIG_FILE")
    
    if [[ $(echo "$config" | jq -r '.storage.s3.enabled') == "true" ]]; then
        local bucket=$(echo "$config" | jq -r '.storage.s3.bucket')
        local path=$(echo "$config" | jq -r '.storage.s3.path')
        local endpoint=$(echo "$config" | jq -r '.storage.s3.endpoint')
        local key=$(echo "$config" | jq -r '.storage.s3.access_key')
        local secret=$(echo "$config" | jq -r '.storage.s3.secret_key')
        
        # Configure AWS CLI
        aws configure set aws_access_key_id "$key"
        aws configure set aws_secret_access_key "$secret"
        
        if [[ -n "$endpoint" ]]; then
            aws_extra_args="--endpoint-url $endpoint"
        else
            aws_extra_args=""
        fi
        
        # Upload to S3
        aws s3 cp "$source" "s3://${bucket}/${path}/$(basename "$source")" $aws_extra_args
        log_message "Backup uploaded to S3: ${bucket}/${path}/$(basename "$source")"
    fi
}

# Function to store backup in DigitalOcean Spaces
store_spaces_backup() {
    local source=$1
    local config=$(cat "$CONFIG_FILE")
    
    if [[ $(echo "$config" | jq -r '.storage.spaces.enabled') == "true" ]]; then
        local bucket=$(echo "$config" | jq -r '.storage.spaces.bucket')
        local path=$(echo "$config" | jq -r '.storage.spaces.path')
        local region=$(echo "$config" | jq -r '.storage.spaces.region')
        local key=$(echo "$config" | jq -r '.storage.spaces.access_key')
        local secret=$(echo "$config" | jq -r '.storage.spaces.secret_key')
        
        # Configure AWS CLI for Spaces
        aws configure set aws_access_key_id "$key"
        aws configure set aws_secret_access_key "$secret"
        
        # Upload to Spaces
        aws s3 cp "$source" "s3://${bucket}/${path}/$(basename "$source")" \
            --endpoint-url "https://${region}.digitaloceanspaces.com"
        log_message "Backup uploaded to Spaces: ${bucket}/${path}/$(basename "$source")"
    fi
}

# Main backup process
main() {
    log_message "Starting backup for ${DOMAIN}"
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Backup files
    log_message "Backing up files..."
    tar czf "${TEMP_DIR}/files.tar.gz" -C "/var/www/${DOMAIN}" .
    
    # Backup databases if configured
    if [[ -f "/var/www/${DOMAIN}/config/database.conf" ]]; then
        source "/var/www/${DOMAIN}/config/database.conf"
        if [[ "$DB_TYPE" == "mysql" ]]; then
            mysqldump --opt "$DB_NAME" > "${TEMP_DIR}/database.sql"
        elif [[ "$DB_TYPE" == "postgres" ]]; then
            pg_dump "$DB_NAME" > "${TEMP_DIR}/database.sql"
        fi
    fi
    
    # Create final backup archive
    local backup_file="${TEMP_DIR}/${BACKUP_NAME}.tar.gz"
    compress_backup "$TEMP_DIR" "$backup_file"
    
    # Encrypt if enabled
    backup_file=$(encrypt_backup "$backup_file")
    
    # Store backup in configured locations
    store_local_backup "$backup_file"
    store_s3_backup "$backup_file"
    store_spaces_backup "$backup_file"
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log_message "Backup completed successfully"
    send_notification "Backup Successful - ${DOMAIN}" "Backup completed successfully at $(date)"
}

# Error handling
trap 'error_exit "$?"' ERR

error_exit() {
    local err_msg="Backup failed with error code $1"
    log_message "$err_msg"
    send_notification "Backup Failed - ${DOMAIN}" "$err_msg"
    exit 1
}

# Run main process
main "$@"
EOF

    chmod +x "$backup_script"
    chown root:root "$backup_script"
}

setup_backup_rotation() {
    local domain=$1
    local rotation_script="/usr/local/bin/rotate-backups-${domain}.sh"
    
    cat > "$rotation_script" <<'EOF'
#!/bin/bash

DOMAIN="$1"
CONFIG_FILE="/var/www/${DOMAIN}/config/backup.json"

# Rotate local backups
rotate_local() {
    local config=$(cat "$CONFIG_FILE")
    if [[ $(echo "$config" | jq -r '.storage.local.enabled') == "true" ]]; then
        local path=$(echo "$config" | jq -r '.storage.local.path')
        local days=$(echo "$config" | jq -r '.storage.local.retention_days')
        find "$path" -type f -mtime "+${days}" -delete
    fi
}

# Rotate S3 backups
rotate_s3() {
    local config=$(cat "$CONFIG_FILE")
    if [[ $(echo "$config" | jq -r '.storage.s3.enabled') == "true" ]]; then
        local bucket=$(echo "$config" | jq -r '.storage.s3.bucket')
        local path=$(echo "$config" | jq -r '.storage.s3.path')
        local days=$(echo "$config" | jq -r '.storage.s3.retention_days')
        
        aws s3 ls "s3://${bucket}/${path}/" | while read -r line; do
            local date=$(echo "$line" | awk '{print $1}')
            local file=$(echo "$line" | awk '{print $4}')
            if [[ $(date -d "$date" +%s) -lt $(date -d "-${days} days" +%s) ]]; then
                aws s3 rm "s3://${bucket}/${path}/${file}"
            fi
        done
    fi
}

# Rotate Spaces backups
rotate_spaces() {
    local config=$(cat "$CONFIG_FILE")
    if [[ $(echo "$config" | jq -r '.storage.spaces.enabled') == "true" ]]; then
        local bucket=$(echo "$config" | jq -r '.storage.spaces.bucket')
        local path=$(echo "$config" | jq -r '.storage.spaces.path')
        local days=$(echo "$config" | jq -r '.storage.spaces.retention_days')
        local region=$(echo "$config" | jq -r '.storage.spaces.region')
        
        aws s3 ls "s3://${bucket}/${path}/" --endpoint-url "https://${region}.digitaloceanspaces.com" | \
        while read -r line; do
            local date=$(echo "$line" | awk '{print $1}')
            local file=$(echo "$line" | awk '{print $4}')
            if [[ $(date -d "$date" +%s) -lt $(date -d "-${days} days" +%s) ]]; then
                aws s3 rm "s3://${bucket}/${path}/${file}" \
                    --endpoint-url "https://${region}.digitaloceanspaces.com"
            fi
        done
    fi
}

# Run rotations
rotate_local
rotate_s3
rotate_spaces
EOF

    chmod +x "$rotation_script"
    chown root:root "$rotation_script"
}

setup_backup_schedule() {
    local domain=$1
    local site_user=$2
    
    # Add backup jobs to crontab
    (crontab -l 2>/dev/null || true; echo "0 2 * * * /usr/local/bin/backup-${domain}.sh ${domain}") | crontab -
    (crontab -l 2>/dev/null || true; echo "0 3 * * * /usr/local/bin/rotate-backups-${domain}.sh ${domain}") | crontab -
}

configure_backup_storage() {
    local domain=$1
    local config_file="/var/www/${domain}/config/backup.json"
    
    # Create local backup directory if enabled
    if [[ $(jq -r '.storage.local.enabled' "$config_file") == "true" ]]; then
        local backup_path=$(jq -r '.storage.local.path' "$config_file")
        mkdir -p "$backup_path"
        chmod 750 "$backup_path"
    fi
    
    # Configure AWS CLI if S3 or Spaces is enabled
    if [[ $(jq -r '.storage.s3.enabled' "$config_file") == "true" ]] || \
       [[ $(jq -r '.storage.spaces.enabled' "$config_file") == "true" ]]; then
        apt-get install -y awscli
    fi
}