# scripts/web/php.sh
#!/bin/bash

setup_php() {
    local version=${1:-"8.2"}
    log_message "INFO" "Setting up PHP $version..."

    # Add repository
    add-apt-repository -y ppa:ondrej/php
    apt-get update

    # Install PHP and extensions
    apt-get install -y \
        php${version}-fpm \
        php${version}-cli \
        php${version}-common \
        php${version}-mysql \
        php${version}-pgsql \
        php${version}-curl \
        php${version}-gd \
        php${version}-mbstring \
        php${version}-xml \
        php${version}-zip \
        php${version}-bcmath \
        php${version}-intl \
        php${version}-soap \
        php${version}-readline

    # Configure PHP
    configure_php "$version"
    configure_php_fpm "$version"

    # Enable and start service
    systemctl enable php${version}-fpm
    systemctl restart php${version}-fpm
}

configure_php() {
    local version=$1
    local php_ini="/etc/php/${version}/fpm/php.ini"

    # Backup original config
    backup_file "$php_ini"

    # Update configuration
    sed -i "s/memory_limit = .*/memory_limit = 256M/" "$php_ini"
    sed -i "s/max_execution_time = .*/max_execution_time = 60/" "$php_ini"
    sed -i "s/max_input_time = .*/max_input_time = 60/" "$php_ini"
    sed -i "s/post_max_size = .*/post_max_size = 32M/" "$php_ini"
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 32M/" "$php_ini"
    sed -i "s/;date.timezone.*/date.timezone = UTC/" "$php_ini"
    
    # Security settings
    sed -i "s/expose_php = .*/expose_php = Off/" "$php_ini"
    sed -i "s/allow_url_fopen = .*/allow_url_fopen = Off/" "$php_ini"
    sed -i "s/;session.cookie_secure.*/session.cookie_secure = 1/" "$php_ini"
    sed -i "s/;session.cookie_httponly.*/session.cookie_httponly = 1/" "$php_ini"
    sed -i "s/;session.use_strict_mode.*/session.use_strict_mode = 1/" "$php_ini"
}

configure_php_fpm() {
    local version=$1
    local pool_dir="/etc/php/${version}/fpm/pool.d"
    
    # Remove default pool
    rm -f "${pool_dir}/www.conf"

    # Create base pool configuration
    cat > "${pool_dir}/base.conf" <<EOF
[global]
pid = /run/php/php${version}-fpm.pid
error_log = /var/log/php${version}-fpm.log
log_level = notice
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s
EOF
}

setup_php_site() {
    local domain=$1
    local site_user=$2
    local version=${3:-"8.2"}
    
    # Create PHP-FPM pool configuration
    create_php_pool "$domain" "$site_user" "$version"
}

create_php_pool() {
    local domain=$1
    local site_user=$2
    local version=$3
    local pool_conf="/etc/php/${version}/fpm/pool.d/${domain}.conf"

    cat > "$pool_conf" <<EOF
[${domain}]
user = ${site_user}
group = ${site_user}

listen = /run/php/php${version}-fpm-${domain}.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500

php_admin_value[error_log] = /var/www/${domain}/logs/php_errors.log
php_admin_flag[log_errors] = on

php_admin_value[memory_limit] = 256M
php_admin_value[upload_max_filesize] = 32M
php_admin_value[post_max_size] = 32M
php_admin_value[max_execution_time] = 60

php_admin_value[open_basedir] = /var/www/${domain}/:/tmp/
php_admin_value[session.save_path] = /var/www/${domain}/sessions/

security.limit_extensions = .php
EOF

    # Restart PHP-FPM
    systemctl restart php${version}-fpm
}