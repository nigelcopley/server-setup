# scripts/php-setup.sh - PHP setup functions
#!/bin/bash

setup_php_site() {
    local domain=$1
    local site_user=$2
    local domain_entry=$3
    
    # Get PHP version from config
    local php_version=$(get_domain_config "${domain_entry}" "php_version")
    php_version=${php_version:-"8.2"}
    
    # Install PHP if not already installed
    if ! command -v php${php_version} &>/dev/null; then
        add-apt-repository -y ppa:ondrej/php
        apt-get update
        apt-get install -y php${php_version}-fpm php${php_version}-mysql php${php_version}-xml \
            php${php_version}-mbstring php${php_version}-curl php${php_version}-gd php${php_version}-zip
    fi
    
    # Setup PHP-FPM pool
    setup_php_pool "${domain}" "${site_user}" "${domain_entry}" "${php_version}"
}

setup_php_pool() {
    local domain=$1
    local site_user=$2
    local domain_entry=$3
    local php_version=$4
    
    local memory_limit=$(get_domain_config "${domain_entry}" "memory_limit")
    memory_limit=${memory_limit:-"${DEFAULT_MEMORY_LIMIT}"}
    
    envsubst < "${SCRIPT_DIR}/config/php/php-pool-template.conf" > \
        "/etc/php/${php_version}/fpm/pool.d/${domain}.conf"
    
    systemctl restart php${php_version}-fpm
}
