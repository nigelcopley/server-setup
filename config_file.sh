#!/bin/bash

# Define user information
NEW_USER="multiops"
USER_PASSWORD="H!Aw-5sawjzKZKs"


# Define domains with their respective types (php, python, html) and optional features
# Format: domain:type:db
domains=(
  "example1.com:html:none"
  "example2.com:python:postgres"
  "example3.com:php:mysql"
  "charleston.com:php:mysql"
)

# Optional Features
INSTALL_REDIS=true          # Install Redis for caching
ENABLE_EMAIL_NOTIFICATIONS=true  # Enable email notifications for events
SETUP_AUTOMATIC_BACKUPS=true # Set up automatic backups for databases
#STATIC_IP="192.168.1.100"    # Optional static IP address configuration (leave empty if not needed)
