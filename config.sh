# config.sh
#!/bin/bash

# System Configuration
HOSTNAME="${HOSTNAME:-multisite-server}"
LOG_DIR="/var/log/multisite-server"
LOG_FILE="${LOG_DIR}/setup.log"
CREDENTIALS_FILE="credentials.txt"

# Admin User Configuration
NEW_USER="${NEW_USER:-admin}"
USER_PASSWORD="${USER_PASSWORD:-}"  # Will be auto-generated if empty
COPY_ROOT_SSH_KEYS=1

# Security Configuration
INSTALL_FAIL2BAN=1
INSTALL_CLAMAV=1
INSTALL_REDIS=0
ADDITIONAL_PORTS=""  # Space-separated list of additional ports to open

# SSH Configuration
SSH_PORT=22
SSH_ALLOW_PASSWORDS=0
SSH_ALLOW_ROOT=0

# SSL Configuration
SSL_EMAIL="${SSL_EMAIL:-admin@example.com}"
SSL_RENEWAL_HOOK="/usr/local/bin/ssl-renewed.sh"

# Backup Configuration
BACKUP_ENABLE=1
BACKUP_DIR="/backups"
BACKUP_RETENTION_DAYS=30
BACKUP_ENCRYPTION=0
BACKUP_COMPRESSION="gzip"

# Email Configuration
SMTP_HOST="${SMTP_HOST:-}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"

# Domain Configurations
# Format: "domain:type:db:{key:value,key:value}"
domains=(
    "example1.com:html:none:{
        contact_email:admin@example1.com,
        memory_limit:128M,
        enable_contact_form:1,
        backup_enabled:1
    }"
    
    "example2.com:python:postgres:{
        workers:3,
        memory_limit:256M,
        python_version:3.9,
        requirements_file:requirements.txt,
        wsgi_app:app.wsgi:application,
        backup_type:s3,
        backup_bucket:my-backups
    }"
    
    "example3.com:php:mysql:{
        php_version:8.2,
        memory_limit:256M,
        max_children:5,
        pm_type:dynamic,
        backup_enabled:1,
        db_backup:1
    }"
)

# PHP Configurations
PHP_VERSIONS=(
    "7.4"
    "8.0"
    "8.1"
    "8.2"
)

PHP_DEFAULT_VERSION="8.2"
PHP_MODULES=(
    "cli"
    "fpm"
    "mysql"
    "pgsql"
    "curl"
    "gd"
    "mbstring"
    "xml"
    "zip"
)

# Python Configurations
PYTHON_DEFAULT_VERSION="3.9"
PYTHON_VIRTUALENV=1

# Database Configurations
DB_MYSQL_ROOT_PASSWORD="${DB_MYSQL_ROOT_PASSWORD:-}"  # Auto-generated if empty
DB_POSTGRES_VERSION="14"

# Monitoring Configuration
ENABLE_MONITORING=1
MONITORING_EMAIL="${MONITORING_EMAIL:-${SSL_EMAIL}}"
MONITORING_INTERVAL=5  # minutes
MONITORING_RETENTION=30  # days

# Backup Storage Configuration
# Local Storage
LOCAL_BACKUP_ENABLED=1
LOCAL_BACKUP_PATH="${BACKUP_DIR}"

# S3 Storage
S3_BACKUP_ENABLED=0
S3_BUCKET=""
S3_ACCESS_KEY=""
S3_SECRET_KEY=""
S3_REGION="us-east-1"

# DigitalOcean Spaces
DO_SPACES_ENABLED=0
DO_SPACES_BUCKET=""
DO_SPACES_ACCESS_KEY=""
DO_SPACES_SECRET_KEY=""
DO_SPACES_REGION="nyc3"

# Maintenance Mode Configuration
MAINTENANCE_TEMPLATE="/etc/multisite-server/templates/maintenance.html"
MAINTENANCE_ALLOWED_IPS=()  # IPs that can bypass maintenance mode

# Resource Limits
DEFAULT_MEMORY_LIMIT="128M"
DEFAULT_PROCESS_LIMIT=5
DEFAULT_MAX_REQUESTS=1000

# Automatic Updates
AUTO_UPDATE_SECURITY=1  # Enable automatic security updates
AUTO_UPDATE_PACKAGES=0  # Enable automatic package updates
AUTO_UPDATE_NOTIFY=1    # Send notification after updates

# Notification Configuration
NOTIFICATION_EMAIL="${SSL_EMAIL}"
NOTIFICATION_EVENTS=(
    "backup_complete"
    "backup_failed"
    "ssl_renewed"
    "ssl_expiring"
    "maintenance_started"
    "maintenance_completed"
    "security_updates"
)

# Advanced Options
DEBUG_MODE=0                    # Enable debug logging
FORCE_HTTPS=1                  # Force HTTPS redirect
HSTS_ENABLE=1                  # Enable HTTPS Strict Transport Security
OCSP_STAPLING=1               # Enable OCSP Stapling
GZIP_COMPRESSION=1            # Enable Gzip compression
BROTLI_COMPRESSION=0          # Enable Brotli compression
HIDE_NGINX_VERSION=1          # Hide NGINX version
HIDE_PHP_VERSION=1            # Hide PHP version
DISABLE_SERVER_TOKENS=1       # Disable server tokens

# Performance Tuning
NGINX_WORKER_PROCESSES="auto"
NGINX_WORKER_CONNECTIONS=1024
PHP_FPM_MAX_CHILDREN=5
PHP_FPM_START_SERVERS=2
PHP_FPM_MIN_SPARE_SERVERS=1
PHP_FPM_MAX_SPARE_SERVERS=3

# Development Options
DEVELOPMENT_MODE=0            # Enable development mode features
INSTALL_COMPOSER=0            # Install Composer
INSTALL_NODEJS=0             # Install Node.js
INSTALL_GIT=1                # Install Git

# Custom Scripts
PRE_SETUP_SCRIPT=""          # Script to run before setup
POST_SETUP_SCRIPT=""         # Script to run after setup