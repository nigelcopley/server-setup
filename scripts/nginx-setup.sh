# scripts/nginx-setup.sh - NGINX setup functions
#!/bin/bash

setup_nginx_site() {
    local domain=$1
    local site_user=$2
    local domain_type=$3
    
    # Create NGINX configuration
    generate_nginx_config "${domain}" "${site_user}" "${domain_type}"
    
    # Enable site
    ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/"
}

generate_nginx_config() {
    local domain=$1
    local site_user=$2
    local domain_type=$3
    
    case ${domain_type} in
        "php")
            generate_php_nginx_config "${domain}" "${site_user}"
            ;;
        "python")
            generate_python_nginx_config "${domain}" "${site_user}"
            ;;
        "html")
            generate_html_nginx_config "${domain}" "${site_user}"
            ;;
    esac
}