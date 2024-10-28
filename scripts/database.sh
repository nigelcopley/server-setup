# scripts/database.sh - Database management functions
#!/bin/bash

setup_database() {
    local domain=$1
    local site_user=$2
    local db_type=$3
    
    local db_name="${domain//./_}_db"
    local db_user="${domain//./_}_user"
    local db_pass=$(openssl rand -base64 16)
    
    case ${db_type} in
        "mysql")
            setup_mysql_database "${db_name}" "${db_user}" "${db_pass}"
            ;;
        "postgres")
            setup_postgres_database "${db_name}" "${db_user}" "${db_pass}"
            ;;
    esac
    
    # Store credentials
    echo "${domain} DB - User: ${db_user}, Password: ${db_pass}" >> "${CREDENTIALS_FILE}"
}