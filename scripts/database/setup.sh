# scripts/database/setup.sh
#!/bin/bash

setup_database() {
    local domain=$1
    local site_user=$2
    local db_type=$3
    
    local db_name="${domain//./_}_db"
    local db_user="${domain//./_}_user"
    local db_pass=$(generate_password 32)
    
    log_message "INFO" "Setting up ${db_type} database for ${domain}"
    
    case ${db_type} in
        "mysql")
            setup_mysql
            create_mysql_database "$db_name" "$db_user" "$db_pass"
            ;;
        "postgres")
            setup_postgres
            create_postgres_database "$db_name" "$db_user" "$db_pass"
            ;;
        *)
            log_message "ERROR" "Unknown database type: ${db_type}"
            return 1
            ;;
    esac
    
    # Store database configuration
    create_secure_directory "/var/www/${domain}/config/database" root root 750
    
    cat > "/var/www/${domain}/config/database/db.conf" <<EOF
DB_TYPE=${db_type}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASS=${db_pass}
DB_HOST=localhost
EOF

    chmod 600 "/var/www/${domain}/config/database/db.conf"
    chown "${site_user}:${site_user}" "/var/www/${domain}/config/database/db.conf"
    
    log_message "INFO" "Database setup completed for ${domain}"
}