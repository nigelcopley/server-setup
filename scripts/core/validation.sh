# scripts/core/validation.sh
#!/bin/bash

validate_config() {
    log_message "INFO" "Validating configuration..."

    # Required variables
    local required_vars=(
        "NEW_USER"
        "HOSTNAME"
        "SSL_EMAIL"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_message "ERROR" "Required variable ${var} is not set"
            return 1
        fi
    done

    # Validate domains configuration
    validate_domains || return 1

    # Validate email format
    if ! validate_email "${SSL_EMAIL}"; then
        log_message "ERROR" "Invalid email format: ${SSL_EMAIL}"
        return 1
    fi

    # Validate backup configuration
    validate_backup_config || return 1

    log_message "INFO" "Configuration validation completed"
    return 0
}

validate_domains() {
    if [[ ${#domains[@]} -eq 0 ]]; then
        log_message "ERROR" "No domains configured"
        return 1
    fi

    local valid_types=("html" "php" "python")
    local valid_dbs=("none" "mysql" "postgres")

    for domain_entry in "${domains[@]}"; do
        local domain=$(echo "$domain_entry" | cut -d: -f1)
        local type=$(echo "$domain_entry" | cut -d: -f2)
        local db=$(echo "$domain_entry" | cut -d: -f3)

        # Validate domain format
        if ! validate_domain_format "$domain"; then
            log_message "ERROR" "Invalid domain format: $domain"
            return 1
        fi

        # Validate site type
        if [[ ! " ${valid_types[@]} " =~ " ${type} " ]]; then
            log_message "ERROR" "Invalid site type for ${domain}: ${type}"
            return 1
        fi

        # Validate database type
        if [[ ! " ${valid_dbs[@]} " =~ " ${db} " ]]; then
            log_message "ERROR" "Invalid database type for ${domain}: ${db}"
            return 1
        fi
    done

    return 0
}

validate_domain_format() {
    local domain=$1
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$ ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

validate_backup_config() {
    if [[ "${BACKUP_ENABLE}" == "1" ]]; then
        # Validate backup directory
        if [[ -z "${BACKUP_DIR}" ]]; then
            log_message "ERROR" "Backup directory not specified"
            return 1
        fi

        # Validate retention days
        if ! [[ "${BACKUP_RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
            log_message "ERROR" "Invalid backup retention days: ${BACKUP_RETENTION_DAYS}"
            return 1
        fi

        # Validate S3 configuration if enabled
        if [[ "${S3_BACKUP_ENABLED}" == "1" ]]; then
            if [[ -z "${S3_BUCKET}" || -z "${S3_ACCESS_KEY}" || -z "${S3_SECRET_KEY}" ]]; then
                log_message "ERROR" "Incomplete S3 backup configuration"
                return 1
            fi
        fi
    fi

    return 0
}
