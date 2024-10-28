# scripts/contact-setup.sh
#!/bin/bash

setup_contact_form() {
    local domain=$1
    local site_user=$2
    
    # Create directories
    mkdir -p "/var/www/${domain}/"{contact,config,logs,tmp}
    
    # Copy contact form handler
    cp "${SCRIPT_DIR}/config/contact/contact-handler.php" \
        "/var/www/${domain}/contact/index.php"
    
    # Copy contact form template
    cp "${SCRIPT_DIR}/config/contact/contact-template.html" \
        "/var/www/${domain}/host/contact.html"
    
    # Generate contact configuration
    envsubst < "${SCRIPT_DIR}/config/contact/contact.json.template" > \
        "/var/www/${domain}/config/contact.json"
    
    # Set permissions
    chown -R "${site_user}:${site_user}" "/var/www/${domain}/contact"
    chown -R "${site_user}:${site_user}" "/var/www/${domain}/config/contact.json"
    chmod 644 "/var/www/${domain}/contact/index.php"
    chmod 644 "/var/www/${domain}/host/contact.html"
    chmod 640 "/var/www/${domain}/config/contact.json"
    
    # Set up PHP-FPM pool for contact form
    setup_contact_php_pool() {
        local domain=$1
        local site_user=$2
        
        # Create contact form specific PHP-FPM pool
        cat > "/etc/php/*/fpm/pool.d/${domain}-contact.conf" <<EOF
[${domain}-contact]
user = ${site_user}
group = ${site_user}

listen = /run/php-fpm/${domain}-contact.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 3
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 2
pm.max_requests = 500

php_admin_value[memory_limit] = 32M
php_admin_value[upload_max_filesize] = 1M
php_admin_value[post_max_size] = 1M
php_admin_value[error_log] = /var/www/${domain}/logs/contact_php_errors.log
php_admin_flag[log_errors] = on
php_admin_value[open_basedir] = /var/www/${domain}/:/tmp/
php_admin_value[session.save_path] = /var/www/${domain}/sessions/
php_admin_value[sys_temp_dir] = /var/www/${domain}/tmp/

; Security settings
php_admin_flag[allow_url_fopen] = off
php_admin_flag[allow_url_include] = off
php_admin_flag[display_errors] = off
php_admin_flag[expose_php] = off
php_admin_value[max_execution_time] = 30
php_admin_value[max_input_time] = 30
php_admin_value[session.cookie_httponly] = 1
php_admin_value[session.cookie_samesite] = "Strict"
php_admin_value[session.cookie_secure] = 1

security.limit_extensions = .php
EOF

    # Create session and temp directories
    mkdir -p "/var/www/${domain}/"{sessions,tmp}
    chown -R "${site_user}:${site_user}" "/var/www/${domain}/"{sessions,tmp}
    chmod 750 "/var/www/${domain}/"{sessions,tmp}
}

setup_contact_nginx() {
    local domain=$1
    
    # Add contact form location block to nginx configuration
    cat >> "/etc/nginx/sites-available/${domain}" <<'EOF'

    # Contact form handling
    location /contact {
        # Security headers
        add_header X-Frame-Options "DENY";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Content-Type-Options "nosniff";
        add_header Referrer-Policy "strict-origin-when-cross-origin";
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';";

        # Rate limiting
        limit_req zone=contact burst=5 nodelay;
        limit_req_status 429;

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php-fpm/${domain}-contact.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            include fastcgi_params;
            
            # Additional FastCGI parameters
            fastcgi_param PATH_INFO $fastcgi_path_info;
            fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
            fastcgi_param HTTP_PROXY "";
            
            # Timeouts
            fastcgi_connect_timeout 30s;
            fastcgi_send_timeout 30s;
            fastcgi_read_timeout 30s;
            
            # Security
            fastcgi_param PHP_VALUE "open_basedir=/var/www/${domain}/:/tmp/";
        }
        
        # Deny access to sensitive files
        location ~ /\. {
            deny all;
        }
        location ~ /config/ {
            deny all;
        }
        location ~ /logs/ {
            deny all;
        }
    }
EOF
}

setup_contact_rate_limiting() {
    local domain=$1
    
    # Add rate limiting configuration to nginx
    cat > "/etc/nginx/conf.d/contact-rate-limiting.conf" <<EOF
# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=contact:10m rate=1r/s;
limit_req_status 429;

# Custom error page for rate limiting
error_page 429 /rate-limit.html;
EOF

    # Create rate limit error page
    cat > "/var/www/${domain}/host/rate-limit.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rate Limit Exceeded</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 2rem auto;
            padding: 2rem;
            text-align: center;
        }
        .error {
            color: #dc3545;
            margin: 2rem 0;
        }
    </style>
</head>
<body>
    <h1>Rate Limit Exceeded</h1>
    <div class="error">
        Too many requests. Please wait a few minutes before trying again.
    </div>
</body>
</html>
EOF
}

setup_contact_monitoring() {
    local domain=$1
    local site_user=$2
    
    # Create monitoring script
    cat > "/var/www/${domain}/contact/monitor.php" <<'EOF'
<?php
function check_contact_form() {
    $status = [
        'timestamp' => date('Y-m-d H:i:s'),
        'form_accessible' => false,
        'php_pool_active' => false,
        'rate_limit_file' => false,
        'log_writable' => false,
        'errors' => []
    ];
    
    // Check form accessibility
    $form_url = 'http://localhost/contact/';
    $headers = get_headers($form_url);
    $status['form_accessible'] = $headers && strpos($headers[0], '200') !== false;
    
    // Check PHP-FPM pool
    $pool_socket = '/run/php-fpm/${domain}-contact.sock';
    $status['php_pool_active'] = file_exists($pool_socket);
    
    // Check rate limit file
    $rate_file = '../tmp/rate_limit.json';
    $status['rate_limit_file'] = is_readable($rate_file) && is_writable($rate_file);
    
    // Check log writability
    $log_file = '../logs/contact_form.log';
    $status['log_writable'] = is_writable($log_file);
    
    return $status;
}

header('Content-Type: application/json');
echo json_encode(check_contact_form(), JSON_PRETTY_PRINT);
EOF

    # Set up monitoring cron
    echo "*/5 * * * * php /var/www/${domain}/contact/monitor.php > /var/www/${domain}/logs/contact_status.json 2>/dev/null" | crontab -u "${site_user}" -
}

setup_contact_form() {
    local domain=$1
    local site_user=$2
    
    log_message "Setting up contact form for ${domain}"
    
    # Setup directory structure and copy files
    setup_contact_directories "${domain}" "${site_user}"
    
    # Setup PHP-FPM pool for contact form
    setup_contact_php_pool "${domain}" "${site_user}"
    
    # Configure nginx for contact form
    setup_contact_nginx "${domain}"
    
    # Setup rate limiting
    setup_contact_rate_limiting "${domain}"
    
    # Setup monitoring
    setup_contact_monitoring "${domain}" "${site_user}"
    
    # Restart services
    systemctl restart php*-fpm
    systemctl reload nginx
    
    log_message "Contact form setup completed for ${domain}"
}