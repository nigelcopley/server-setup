# scripts/web/python.sh
#!/bin/bash

setup_python() {
    log_message "INFO" "Setting up Python environment..."

    # Install Python and required packages
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        libpq-dev

    # Install global packages
    pip3 install --upgrade pip
    pip3 install virtualenv
}

setup_python_site() {
    local domain=$1
    local site_user=$2
    local python_version=${3:-"3.9"}

    # Create virtual environment
    sudo -u "$site_user" python3 -m venv "/var/www/${domain}/venv"

    # Install base packages
    sudo -u "$site_user" "/var/www/${domain}/venv/bin/pip" install \
        gunicorn \
        uvicorn \
        supervisor

    # Create Gunicorn configuration
    setup_gunicorn "$domain" "$site_user"
}

setup_gunicorn() {
    local domain=$1
    local site_user=$2

    # Create Gunicorn systemd service
    cat > "/etc/systemd/system/gunicorn-${domain}.service" <<EOF
[Unit]
Description=Gunicorn daemon for ${domain}
After=network.target

[Service]
User=${site_user}
Group=${site_user}
WorkingDirectory=/var/www/${domain}/host
Environment="PATH=/var/www/${domain}/venv/bin"
ExecStart=/var/www/${domain}/venv/bin/gunicorn \\
          --workers 3 \\
          --bind unix:/run/gunicorn/${domain}.sock \\
          --access-logfile /var/www/${domain}/logs/gunicorn-access.log \\
          --error-logfile /var/www/${domain}/logs/gunicorn-error.log \\
          wsgi:application

[Install]
WantedBy=multi-user.target
EOF

    # Create directory for Gunicorn socket
    mkdir -p /run/gunicorn
    chown root:root /run/gunicorn
    chmod 755 /run/gunicorn

    # Enable and start service
    systemctl enable "gunicorn-${domain}"
    systemctl start "gunicorn-${domain}"
}