# Multi-Site Server Setup

An automated, secure, and modular server setup solution for hosting multiple websites with different technology stacks (PHP, Python, HTML) on a single Ubuntu server. Features built-in contact forms for HTML sites, comprehensive backup solutions, and robust security features.

## 🚀 Features

### Multi-Technology Support
- **HTML Sites**: Static websites with secure contact form integration
- **PHP Sites**: Full PHP-FPM configuration with per-site pools
- **Python Sites**: Python applications with Gunicorn and virtualenv

### Security Features
- 🔒 Isolated site environments with dedicated users
- 🛡️ Fail2Ban integration for intrusion prevention
- 🔐 SSL/TLS automation with Let's Encrypt
- 🚫 Rate limiting and DDoS protection
- 🕵️ Malware scanning with ClamAV

### Backup System
- 📂 Multiple storage backends (Local, S3, DO Spaces)
- 🔄 Automated backup rotation
- 🔒 Optional GPG encryption
- 📧 Email notifications
- 💾 Database backup support
- 🗜️ Compression and optimization

### Contact Form System
- ✉️ Secure PHP-based contact form for HTML sites
- 🔑 CSRF protection
- 🤖 Anti-spam measures
- 📝 Form validation and sanitization
- 📨 Email notifications

## 📋 Requirements

- Ubuntu 20.04 LTS or newer
- Root access or sudo privileges
- Domain names pointed to your server
- Minimum 1GB RAM (2GB+ recommended)
- 20GB+ disk space

## 🚀 Quick Start

1. Clone the repository:
```bash
git clone https://github.com/yourusername/multisite-server-setup.git
cd multisite-server-setup
```

2. Configure your domains in `config.sh`:
```bash
vim config.sh
```

Example configuration:
```bash
domains=(
    "example1.com:html:none:{contact_email:admin@example1.com}"
    "example2.com:python:postgres:{workers:3}"
    "example3.com:php:mysql:{php_version:8.2}"
)
```

3. Run the setup:
```bash
chmod +x setup.sh
sudo ./setup.sh
```

## 📝 Configuration

### Domain Configuration Format
```bash
"domain:type:db:{key:value,key:value}"
```

- **domain**: Your domain name
- **type**: Site type (html, php, python)
- **db**: Database type (none, mysql, postgres)
- **key:value**: Additional configurations

### Site-Specific Configurations

#### HTML Sites
```bash
"example.com:html:none:{
    contact_email:admin@example.com,
    memory_limit:128M,
    enable_contact_form:1,
    backup_retention:30
}"
```

#### PHP Sites
```bash
"example.com:php:mysql:{
    php_version:8.2,
    memory_limit:256M,
    max_children:5,
    pm_type:dynamic,
    backup_enabled:1
}"
```

#### Python Sites
```bash
"example.com:python:postgres:{
    workers:3,
    max_requests:1000,
    memory_limit:256M,
    python_version:3.9,
    backup_type:s3
}"
```

## 💾 Backup System

### Storage Options

#### Local Storage
```json
{
    "storage": {
        "local": {
            "enabled": true,
            "path": "/backups/example.com",
            "retention_days": 7
        }
    }
}
```

#### Amazon S3
```json
{
    "storage": {
        "s3": {
            "enabled": true,
            "bucket": "my-backups",
            "region": "us-east-1",
            "path": "backups/example.com",
            "access_key": "YOUR_ACCESS_KEY",
            "secret_key": "YOUR_SECRET_KEY",
            "retention_days": 30
        }
    }
}
```

#### DigitalOcean Spaces
```json
{
    "storage": {
        "spaces": {
            "enabled": true,
            "bucket": "my-backups",
            "region": "nyc3",
            "path": "backups/example.com",
            "access_key": "YOUR_SPACES_KEY",
            "secret_key": "YOUR_SPACES_SECRET",
            "endpoint": "nyc3.digitaloceanspaces.com",
            "retention_days": 30
        }
    }
}
```

### Backup Features
- 🔄 Automatic daily backups
- 🔒 Optional GPG encryption
- 📧 Email notifications on success/failure
- 📊 Backup size optimization
- 🗄️ Database backup support
- ⏰ Configurable retention periods
- 📝 Detailed logging

### Backup Commands

```bash
# Manual backup
sudo /usr/local/bin/backup-example.com.sh example.com

# View backup logs
sudo tail -f /var/www/example.com/logs/backup.log

# List backups
sudo ls -la /backups/example.com/

# Restore from backup
sudo /usr/local/bin/restore-example.com.sh example.com backup-file.tar.gz
```

## 📂 Directory Structure

```
/var/www/${domain}/
├── host/               # Web root
│   ├── public/         # Public files
│   └── contact/        # Contact form (HTML sites)
├── config/             # Site configuration
│   ├── backup.json     # Backup configuration
│   ├── contact.json    # Contact form configuration
│   └── nginx.conf      # Site-specific NGINX config
├── logs/               # Log files
├── sessions/           # PHP sessions
├── tmp/                # Temporary files
└── backup/             # Local backups
```

## 🔒 Security Features

### Per-Site Isolation
- Separate system users
- Isolated PHP-FPM pools
- Restricted file permissions
- Separate log files

### Contact Form Security
- CSRF protection
- Rate limiti