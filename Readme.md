# Multi-Site Hosting Server Setup

## Overview

This script automates the setup of a multi-site hosting server on Ubuntu, providing a streamlined process for configuring various services like NGINX, PostgreSQL, MySQL, PHP, Gunicorn, and SSL using Let's Encrypt. It supports running multiple websites using different software stacks, such as WordPress (PHP), Django (Python), and static HTML.

The script includes the following features:

- Automated installation of necessary services and tools.
- Configuration of NGINX for serving multiple domains.
- Database setup for MySQL and PostgreSQL.
- SSL certificate generation and renewal using Let's Encrypt.
- Optional integration with DigitalOcean Spaces for backups.
- Security hardening with Fail2Ban, ClamAV, and SSH configuration.
- Daily automatic backups with optional cloud storage.

## Requirements

- **Ubuntu Server** (recommended version 20.04 or later)
- **Root privileges** or run the script with `sudo`
- **DigitalOcean Spaces Access Keys** (if using backup integration)
- **Valid domain names** configured to point to the server's IP address

## Configuration

Before running the script, you must update the configuration file (`config_file.sh`) to include details about domains, users, and optional features. The configuration file should define the following variables:

```bash
NEW_USER="your_user"
USER_PASSWORD="your_password"
HOSTNAME="your-hostname"
INSTALL_REDIS="true"
SSL_EMAIL="your-email@example.com"
INSTALL_FAIL2BAN="true"
INSTALL_CLAMAV="true"
ENABLE_BACKUPS="true"
USE_DO_SPACES="true"
DO_SPACES_ACCESS_KEY="your_access_key"
DO_SPACES_SECRET_KEY="your_secret_key"
DO_SPACES_BUCKET_NAME="your_space_name"
DO_SPACES_REGION="nyc3"
ENABLE_EMAIL_NOTIFICATIONS="true"

# Define domains with their respective types (php, python, html) and optional features
# Format: domain:type:db:db_user:db_password
domains=(
  "example1.com:html:none:none:none"
  "example2.com:python:postgres:pg_user:pg_password"
  "example3.com:php:mysql:mysql_user:mysql_password"
)
```

## Features

### 1. User Management

- Creates a new user for managing the server and adds the user to sudoers with passwordless privileges.
- Optionally copies root's authorized SSH keys to the new user for secure login.

### 2. NGINX Multi-Site Configuration

- Configures NGINX to serve multiple domains.
- Supports HTML, PHP (WordPress), and Python (Django) websites.

### 3. Database Setup

- Configures **MySQL** databases for PHP sites and **PostgreSQL** databases for Django sites.
- Sets up database users with configurable credentials.

### 4. Security Enhancements

- **Fail2Ban**: Protects against brute-force attacks.
- **ClamAV**: Scans the server for malware.
- SSH hardening: Disables root login and password-based SSH authentication.
- **UFW Firewall**: Allows only necessary ports for SSH and web traffic.

### 5. SSL Certificates with Let's Encrypt

- Automatically issues SSL certificates for all configured domains.
- Sets up auto-renewal for SSL certificates using `certbot`.

### 6. DigitalOcean Spaces Integration

- Optional integration with **DigitalOcean Spaces** for automated backups of database and site files.
- Uses AWS CLI to upload backups securely to a DigitalOcean Space.

### 7. Automatic Backups

- Creates daily backups of all MySQL and PostgreSQL databases and website files.
- Optionally uploads backups to cloud storage.

## Usage Instructions

### Step 1: Update Configuration File

Modify the `config_file.sh` file to include your desired configuration settings. Make sure to add all domains, user credentials, and any optional features you'd like to enable.

### Step 2: Run the Script

Ensure the script (`server_setup.sh`) is executable:

```sh
chmod +x server_setup.sh
```

Then execute the script:

```sh
sudo ./server_setup.sh
```

### Step 3: Verify the Setup

- Check that the NGINX configuration files have been created for each domain in `/etc/nginx/sites-available`.
- Verify that SSL certificates have been issued for your domains.
- Confirm the new user is created and can access the server using SSH.

## Notes

- Ensure all domain names point to the server IP before running the script to prevent SSL issues.
- Use the provided `BACKUP_DIR` variable to customize where backups are stored.
- If using DigitalOcean Spaces, ensure AWS CLI credentials are correctly configured in the configuration file.

## Known Issues

- **SSL Certificates**: If your domain does not point to the server, Let's Encrypt may fail to issue an SSL certificate.
- **Database Access**: Make sure you have updated firewall rules to allow database access only from trusted sources.

## Future Enhancements

- **Monitoring Integration**: Add server health monitoring tools (e.g., Prometheus, Nagios).
- **Logging Enhancements**: Aggregate logs from NGINX, databases, and other services for easier debugging.
- **Load Balancing**: Add load balancing configuration to distribute traffic across multiple servers.

## License

This project is licensed under the MIT License. See the `LICENSE` file for more details.

## Contributions

Contributions are welcome! Feel free to submit a pull request or open an issue to discuss any changes or improvements.

## Contact

If you have any questions or issues, feel free to contact me
