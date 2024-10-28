# scripts/database/mysql.sh
#!/bin/bash

setup_mysql() {
    log_message "INFO" "Setting up MySQL server..."

    # Generate root password if not set
    if [[ -z "${DB_MYSQL_ROOT_PASSWORD}" ]]; then
        DB_MYSQL_ROOT_PASSWORD=$(generate_password 32)
        log_message "INFO" "Generated MySQL root password"
        echo "MySQL Root Password: ${DB_MYSQL_ROOT_PASSWORD}" >> "${CREDENTIALS_FILE}"
    fi

    # Install MySQL
    export DEBIAN_FRONTEND=noninteractive
    debconf-set-selections <<< "mysql-server mysql-server/root_password password ${DB_MYSQL_ROOT_PASSWORD}"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${DB_MYSQL_ROOT_PASSWORD}"
    
    apt-get install -y mysql-server mysql-client

    # Initial secure configuration
    secure_mysql_installation

    # Configure MySQL
    configure_mysql

    # Enable and start service
    systemctl enable mysql
    systemctl restart mysql

    log_message "INFO" "MySQL setup completed"
}

secure_mysql_installation() {
    log_message "INFO" "Securing MySQL installation..."

    mysql --user=root --password="${DB_MYSQL_ROOT_PASSWORD}" <<-EOSQL
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        FLUSH PRIVILEGES;
EOSQL
}

configure_mysql() {
    local mysql_conf="/etc/mysql/conf.d/custom.cnf"
    
    cat > "$mysql_conf" <<EOF
[mysqld]
# Basic Settings
bind-address            = 127.0.0.1
port                    = 3306
max_connections         = 100
connect_timeout         = 5
wait_timeout           = 600
max_allowed_packet     = 64M
thread_cache_size      = 128
sort_buffer_size       = 4M
bulk_insert_buffer_size = 16M
tmp_table_size         = 32M
max_heap_table_size    = 32M

# MyISAM
myisam_recover_options = BACKUP
key_buffer_size        = 128M
open-files-limit       = 65535
table_open_cache       = 4000
table_definition_cache = 4000
myisam_sort_buffer_size = 512M

# InnoDB
default_storage_engine  = InnoDB
innodb_buffer_pool_size = 1G
innodb_log_buffer_size = 8M
innodb_file_per_table  = 1
innodb_open_files      = 400
innodb_io_capacity     = 400
innodb_flush_method    = O_DIRECT

# Logging
log_error              = /var/log/mysql/error.log
slow_query_log         = 1
slow_query_log_file    = /var/log/mysql/mysql-slow.log
long_query_time        = 2

# Character Set
character-set-server   = utf8mb4
collation-server       = utf8mb4_unicode_ci
EOF

    # Ensure proper permissions
    chown mysql:mysql "$mysql_conf"
    chmod 644 "$mysql_conf"
}

create_mysql_database() {
    local db_name=$1
    local db_user=$2
    local db_password=$3
    local host=${4:-localhost}

    log_message "INFO" "Creating MySQL database: ${db_name}"

    mysql --user=root --password="${DB_MYSQL_ROOT_PASSWORD}" <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${db_name}\`
            DEFAULT CHARACTER SET utf8mb4
            DEFAULT COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${db_user}'@'${host}'
            IDENTIFIED BY '${db_password}';
        GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'${host}';
        FLUSH PRIVILEGES;
EOSQL

    # Store credentials
    cat >> "${CREDENTIALS_FILE}" <<EOF
MySQL Database: ${db_name}
Username: ${db_user}
Password: ${db_password}
Host: ${host}
----------------------------------------
EOF
}

backup_mysql_database() {
    local db_name=$1
    local backup_dir=$2
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="${backup_dir}/mysql-${db_name}-${timestamp}.sql.gz"

    mkdir -p "$backup_dir"

    mysqldump --user=root --password="${DB_MYSQL_ROOT_PASSWORD}" \
        --single-transaction \
        --routines \
        --triggers \
        --databases "$db_name" | gzip > "$backup_file"

    return $?
}