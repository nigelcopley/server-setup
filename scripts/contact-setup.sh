# scripts/contact-setup.sh - Contact form setup
#!/bin/bash

setup_contact_form() {
    local domain=$1
    local site_user=$2
    
    # Copy contact form handler
    install -m 644 -o "${site_user}" -g "${site_user}" \
        "${SCRIPT_DIR}/config/contact/contact-handler.php" \
        "/var/www/${domain}/host/contact/index.php"
    
    # Copy contact form template
    install -m 644 -o "${site_user}" -g "${site_user}" \
        "${SCRIPT_DIR}/config/contact/contact-template.html" \
        "/var/www/${domain}/host/contact.html"
    
    # Setup contact form configuration
    generate_contact_config "${domain}" "${site_user}"
}