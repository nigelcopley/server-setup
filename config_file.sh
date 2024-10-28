#!/bin/bash

# Define user information
NEW_USER="${NEW_USER:-default_user}"
USER_PASSWORD="${USER_PASSWORD:-$(openssl rand -base64 16)}"

# Set the hostname for the server
HOSTNAME="${HOSTNAME:-default-hostname}"

# Enable Redis installation (0/1)
INSTALL_REDIS=${INSTALL_REDIS:-0}

# Email for SSL certificates and notifications
SSL_EMAIL="${SSL_EMAIL:-your-email@example.com}"
if [[ -z "$SSL_EMAIL" ]]; then
  echo "Error: SSL email is not set. Please configure SSL_EMAIL before proceeding."
  exit 1
fi

# Enable Fail2Ban installation for additional security (0/1)
INSTALL_FAIL2BAN=${INSTALL_FAIL2BAN:-1}

# Enable ClamAV for malware scanning (0/1)
INSTALL_CLAMAV=${INSTALL_CLAMAV:-1}

# Enable automatic backups (0/1)
ENABLE_BACKUPS=${ENABLE_BACKUPS:-1}

# Backup destination directory, use timestamp if not provided
BACKUP_DIR="${BACKUP_DIR:-/backups/$(date +%Y%m%d)}"

# Enable email notifications for backup success/failures (0/1)
ENABLE_EMAIL_NOTIFICATIONS=${ENABLE_EMAIL_NOTIFICATIONS:-1}

# DigitalOcean Spaces configuration
USE_DO_SPACES=${USE_DO_SPACES:-0}
DO_SPACES_ACCESS_KEY="${DO_SPACES_ACCESS_KEY:-}"  # Set from environment variables or vault
DO_SPACES_SECRET_KEY="${DO_SPACES_SECRET_KEY:-}"  # Set from environment variables or vault
DO_SPACES_BUCKET_NAME="${DO_SPACES_BUCKET_NAME:-your_space_name}"
DO_SPACES_REGION="${DO_SPACES_REGION:-nyc3}" # Example: nyc3, ams3, sgp1, etc.

# Define domains with their respective types (php, python, html) and optional features
# Format: domain:type:db (db can be 'postgres', 'mysql', or 'none')
domains=(
  "example1.com:html:none"
  "example2.com:python:postgres"
  "example3.com:php:mysql"
)

# Validation for DigitalOcean Spaces
if [[ "$USE_DO_SPACES" == "1" && ( -z "$DO_SPACES_ACCESS_KEY" || -z "$DO_SPACES_SECRET_KEY" ) ]]; then
  echo "Error: DigitalOcean Spaces is enabled, but access key or secret key is not set."
  exit 1
fi

# Print out the configurations for verification
echo "--- Configuration Summary ---"
echo "NEW_USER: $NEW_USER"
echo "HOSTNAME: $HOSTNAME"
echo "INSTALL_REDIS: $INSTALL_REDIS"
echo "SSL_EMAIL: $SSL_EMAIL"
echo "INSTALL_FAIL2BAN: $INSTALL_FAIL2BAN"
echo "INSTALL_CLAMAV: $INSTALL_CLAMAV"
echo "ENABLE_BACKUPS: $ENABLE_BACKUPS"
echo "BACKUP_DIR: $BACKUP_DIR"
echo "USE_DO_SPACES: $USE_DO_SPACES"
echo "DO_SPACES_BUCKET_NAME: $DO_SPACES_BUCKET_NAME"
echo "DO_SPACES_REGION: $DO_SPACES_REGION"

echo "Domains Configuration:"
for domain_entry in "${domains[@]}"
do
  echo "$domain_entry"
done
