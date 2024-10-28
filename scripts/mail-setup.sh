# scripts/mail-setup.sh
#!/bin/bash

setup_mail() {
    local domain=$1
    
    # Install postfix if not present
    if ! command -v postfix >/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
    fi

    # Configure postfix for sending mail
    cat > "/etc/postfix/main.cf" <<EOF
# Basic configuration
smtpd_banner = \$myhostname ESMTP \$mail_name
biff = no
append_dot_mydomain = no
readme_directory = no

# TLS parameters
smtpd_tls_cert_file=/etc/letsencrypt/live/${domain}/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/${domain}/privkey.pem
smtpd_use_tls=yes
smtpd_tls_auth_only = yes
smtp_tls_security_level = may
smtpd_tls_security_level = may
smtpd_sasl_security_options = noanonymous

# Network configuration
myhostname = ${domain}
mydomain = ${domain}
myorigin = \$mydomain
inet_interfaces = loopback-only
inet_protocols = ipv4
mydestination = \$myhostname, localhost.\$mydomain, localhost

# SMTP relay configuration (if provided)
EOF

    # Add SMTP relay configuration if credentials are provided
    if [ -n "${SMTP_HOST}" ]; then
        cat >> "/etc/postfix/main.cf" <<EOF
relayhost = [${SMTP_HOST}]:${SMTP_PORT}
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF

        # Setup SMTP credentials
        echo "[${SMTP_HOST}]:${SMTP_PORT} ${SMTP_USER}:${SMTP_PASS}" > /etc/postfix/sasl_passwd
        chmod 600 /etc/postfix/sasl_passwd
        postmap /etc/postfix/sasl_passwd
    fi

    # Restart postfix
    systemctl restart postfix
}

# Test mail function
test_mail() {
    local domain=$1
    local recipient=$2
    
    echo "This is a test email from ${domain}" | mail -s "Test Email" "${recipient}"
}