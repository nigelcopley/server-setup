# Multi-Site Server Setup

This project is a comprehensive Bash script to set up a multi-site hosting server on an Ubuntu machine. It can install and configure NGINX, PostgreSQL, MySQL, PHP, Gunicorn, and SSL using Let's Encrypt for multiple domains, with support for different software stacks like WordPress (PHP) and Django (Python).

## Prerequisites

- Ensure you run this script as the root user or with sudo privileges.
- The configuration file (`config_file.sh`) should be properly set up before running the script.
- Update the domains list and user information according to your requirements.

## Configuration

The configuration settings are provided through a configuration file (`config_file.sh`). Below is a summary of some key settings:

- **User Information**: Define `NEW_USER` and `USER_PASSWORD` for the server user.
- **Hostname**: Set `HOSTNAME` to the desired server name.
- **Optional Tools**: Use variables like `INSTALL_REDIS`, `INSTALL_FAIL2BAN`, `INSTALL_CLAMAV` to enable or disable optional installations.
- **Automatic Backups**: Set `ENABLE_BACKUPS` and `BACKUP_DIR` to configure automatic backups.
- **DigitalOcean Spaces Configuration**: To enable backup storage, configure `USE_DO_SPACES`, `DO_SPACES_ACCESS_KEY`, `DO_SPACES_SECRET_KEY`, and other settings.
- **Domains List**: Define the list of domains with their types and database configurations.

### Configuration File Example (`config_file.sh`)

The script requires a configuration file that contains information like user credentials, domains, and services to install. An example configuration is:

```sh
#!/bin/bash

# Define user information
NEW_USER="default_user"
USER_PASSWORD="$(openssl rand -base64 16)"

# Set the hostname for the server
HOSTNAME="default-hostname"

# Enable Redis installation (0/1)
INSTALL_REDIS=1

# Email for SSL certificates and notifications
SSL_EMAIL="your-email@example.com"

# Enable Fail2Ban installation for additional security (0/1)
INSTALL_FAIL2BAN=1

# Enable ClamAV for malware scanning (0/1)
INSTALL_CLAMAV=1

# Enable automatic backups (0/1)
ENABLE_BACKUPS=1

# Backup destination directory
BACKUP_DIR="/backups/$(date +%Y%m%d)"

# Enable email notifications for backup success/failures (0/1)
ENABLE_EMAIL_NOTIFICATIONS=1

# DigitalOcean Spaces configuration
USE_DO_SPACES=0
DO_SPACES_ACCESS_KEY=""
DO_SPACES_SECRET_KEY=""
DO_SPACES_BUCKET_NAME="your_space_name"
DO_SPACES_REGION="nyc3"

# Define domains with their respective types and databases
# Format: domain:type:db
domains=(
  "example1.com:html:none"
  "example2.com:python:postgres"
  "example3.com:php:mysql"
)
```

## Running the Script

Once the configuration is ready, run the script as follows:

```sh
sudo ./setup.sh
```

The script will perform the following tasks:

1. **Update and Upgrade the System**: Runs system updates.
2. **Set Hostname**: Configures the server hostname.
3. **Install Required Packages**: Installs NGINX, MySQL, PostgreSQL, PHP, Python, Certbot, and other tools.
4. **Create User**: Adds a new user to the system with sudo privileges.
5. **Set Up Security**: Installs and configures security tools like Fail2Ban, ClamAV, and configures UFW.
6. **Configure NGINX**: Sets up NGINX server blocks for each domain based on its type (HTML, PHP, Python).
7. **Database Setup**: Configures MySQL or PostgreSQL databases for applicable domains.
8. **SSL Setup**: Obtains SSL certificates for each domain using Let's Encrypt.
9. **Automatic Backups**: Sets up backups if enabled.

## Features

- **Multi-Domain Support**: Configure multiple domains with different stacks (HTML, PHP, Python).
- **Security Configurations**: Fail2Ban, ClamAV, and UFW setup for enhanced server security.
- **Automated SSL Setup**: Integration with Let's Encrypt for SSL certificates.
- **Automatic Backups**: Configurable backup system with optional integration with DigitalOcean Spaces.

## Troubleshooting

- **Configuration File Missing**: Ensure the `config_file.sh` file is present and correctly filled out before running the script.
- **DigitalOcean Spaces Setup**: Make sure `DO_SPACES_ACCESS_KEY` and `DO_SPACES_SECRET_KEY` are set if DigitalOcean Spaces is enabled.
- **Permissions**: Ensure that the script is executed with appropriate permissions (`sudo`).

## Recommendations

- **Security**: Use a strong password for `USER_PASSWORD` and keep all credentials secure.
- **Modularity**: Split configuration into multiple smaller files (e.g., `db_config.sh`, `security_config.sh`) to increase modularity.
- **Testing**: Test the script in a controlled environment before deploying to production.

## License

This script is open-source and available for modification under the MIT License.
