# scripts/python-setup.sh - Python setup functions
#!/bin/bash

setup_python_site() {
    local domain=$1
    local site_user=$2
    local domain_entry=$3
    
    # Create and configure virtualenv
    sudo -u "${site_user}" python3 -m venv "/var/www/${domain}/venv"
    sudo -u "${site_user}" /var/www/${domain}/venv/bin/pip install gunicorn
    
    # Setup Gunicorn service
    setup_gunicorn_service "${domain}" "${site_user}" "${domain_entry}"
}

setup_gunicorn_service() {
    local domain=$1
    local site_user=$2
    local domain_entry=$3
    
    local workers=$(get_domain_config "${domain_entry}" "workers")
    workers=${workers:-3}
    
    envsubst < "${SCRIPT_DIR}/config/python/gunicorn-template.service" > \
        "/etc/systemd/system/gunicorn-${domain}.service"
    
    systemctl daemon-reload
    systemctl enable "gunicorn-${domain}"
    systemctl start "gunicorn-${domain}"
}