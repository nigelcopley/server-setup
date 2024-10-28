# config.sh - Main configuration file
#!/bin/bash

# System Configuration
HOSTNAME="${HOSTNAME:-multisite-server}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Security Configuration
FAIL2BAN_ENABLE=1
FIREWALL_ENABLE=1
MALWARE_SCAN_ENABLE=1

# Backup Configuration
BACKUP_ENABLE=1
BACKUP_DIR="/backups/$(date +%Y%m%d)"
BACKUP_RETENTION_DAYS=7

# Email Configuration
SMTP_HOST="${SMTP_HOST:-}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"

# Domain Configurations
# Format: "domain:type:db:{key:value,key:value}"
domains=(
    "example1.com:html:none:{contact_email:admin@example1.com,memory_limit:128M}"
    "example2.com:python:postgres:{workers:3,memory_limit:256M}"
    "example3.com:php:mysql:{php_version:8.2,memory_limit:256M}"
)

# Default Resource Limits
DEFAULT_MEMORY_LIMIT="128M"
DEFAULT_PROCESS_LIMIT=5
DEFAULT_MAX_REQUESTS=1000

# Logging Configuration
LOG_DIR="/var/log/multisite-setup"
LOG_FILE="${LOG_DIR}/setup.log"
