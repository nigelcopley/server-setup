#!/bin/bash

# Define user information
NEW_USER="your_user"
USER_PASSWORD="your_password"

# Set the hostname for the server
HOSTNAME="your-hostname"

# Enable Redis installation (true/false)
INSTALL_REDIS="true"

# Email for SSL certificates and notifications
SSL_EMAIL="your-email@example.com"

# Enable Fail2Ban installation for additional security (true/false)
INSTALL_FAIL2BAN="true"

# Enable ClamAV for malware scanning (true/false)
INSTALL_CLAMAV="true"

# Enable automatic backups (true/false)
ENABLE_BACKUPS="true"

# Backup destination directory
BACKUP_DIR="/backups"

# Enable email notifications for backup success/failures (true/false)
ENABLE_EMAIL_NOTIFICATIONS="true"

# DigitalOcean Spaces configuration
USE_DO_SPACES="true"
DO_SPACES_ACCESS_KEY="your_access_key"
DO_SPACES_SECRET_KEY="your_secret_key"
DO_SPACES_BUCKET_NAME="your_space_name"
DO_SPACES_REGION="nyc3" # Example: nyc3, ams3, sgp1, etc.

# Define domains with their respective types (php, python, html) and optional features
# Format: domain:type:db:db_user:db_password
domains=(
  "example1.com:html:none:none:none"
  "example2.com:python:postgres:pg_user:pg_password"
  "example3.com:php:mysql:mysql_user:mysql_password"
)