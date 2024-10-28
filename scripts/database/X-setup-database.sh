#!/bin/bash

setup_database() {
    local domain=$1
    local site_user=$2
    local db_type=$3
    
    local db_name="${domain//./_}_db"
    local db_user="${domain//./_}_user"
    local db_pass=$(openssl rand -base64 32)
    
    case ${db_type} in
        "mysql")
            setup_mysql_database "${db_name}" "${db_user}" "${db_pass}"
            ;;
        "postgres")
            setup_postgres_database "${db_name}" "${db_user}" "${db_pass}"
            ;;
    esac
    
    store_database_credentials "${domain}" "${db_type}" "${db_name}" "${db_user}" "${db_pass}"
}

setup_mysql_database() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    if ! command -v mysql &>/dev/null; then
        apt-get install -y mysql-server
    fi
    
    mysql -e "CREATE DATABASE IF NOT EXISTS ${db_name};"
    mysql -e "CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';"
    mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
}

setup_postgres_database() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    if ! command -v psql &>/dev/null; then
        apt-get install -y postgresql postgresql-contrib
    fi
    
    sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_pass}';"
    sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};"
}

store_database_credentials() {
    local domain=$1
    local db_type=$2
    local db_name=$3
    local db_user=$4
    local db_pass=$5
    
    cat > "/var/www/${domain}/config/database.conf" <<EOF
DB_TYPE=${db_type}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASS=${db_pass}
EOF
    
    chmod 600 "/var/www/${domain}/config/database.conf"
    chown root:root "/var/www/${domain}/config/database.conf"
}