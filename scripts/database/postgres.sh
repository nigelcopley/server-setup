# scripts/database/postgres.sh
#!/bin/bash

setup_postgres() {
    log_message "INFO" "Setting up PostgreSQL server..."

    # Install PostgreSQL
    apt-get install -y postgresql postgresql-contrib

    # Configure PostgreSQL
    configure_postgres

    # Enable and start service
    systemctl enable postgresql
    systemctl restart postgresql

    log_message "INFO" "PostgreSQL setup completed"
}

configure_postgres() {
    local pg_version=$(ls /etc/postgresql/)
    local pg_conf="/etc/postgresql/${pg_version}/main/postgresql.conf"
    local pg_hba="/etc/postgresql/${pg_version}/main/pg_hba.conf"

    # Backup original configs
    backup_file "$pg_conf"
    backup_file "$pg_hba"

    # Update postgresql.conf
    cat > "$pg_conf" <<EOF
# Basic Settings
listen_addresses = 'localhost'
max_connections = 100
shared_buffers = 128MB
dynamic_shared_memory_type = posix
max_wal_size = 1GB
min_wal_size = 80MB

# Write ahead log
wal_level = replica
fsync = on
synchronous_commit = on
wal_sync_method = fsync
full_page_writes = on
wal_compression = on

# Memory
work_mem = 4MB
maintenance_work_mem = 64MB
effective_cache_size = 4GB

# Query tuning
random_page_cost = 4.0
effective_io_concurrency = 2
default_statistics_target = 100

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 0
log_min_duration_statement = 2000

# Locale and Formatting
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'C'
lc_monetary = 'C'
lc_numeric = 'C'
lc_time = 'C'
default_text_search_config = 'pg_catalog.english'
EOF

    # Update pg_hba.conf
    cat > "$pg_hba" <<EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all            postgres                                peer
local   all            all                                     md5
host    all            all             127.0.0.1/32            md5
host    all            all             ::1/128                 md5
EOF

    # Set proper permissions
    chown postgres:postgres "$pg_conf" "$pg_hba"
    chmod 640 "$pg_conf" "$pg_hba"
}

create_postgres_database() {
    local db_name=$1
    local db_user=$2
    local db_password=$3

    log_message "INFO" "Creating PostgreSQL database: ${db_name}"

    # Create user and database
    sudo -u postgres psql <<EOF
CREATE USER ${db_user} WITH PASSWORD '${db_password}';
CREATE DATABASE ${db_name} OWNER ${db_user}
    ENCODING 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8';
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
EOF

    # Store credentials
    cat >> "${CREDENTIALS_FILE}" <<EOF
PostgreSQL Database: ${db_name}
Username: ${db_user}
Password: ${db_password}
----------------------------------------
EOF
}

backup_postgres_database() {
    local db_name=$1
    local backup_dir=$2
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="${backup_dir}/postgres-${db_name}-${timestamp}.sql.gz"

    mkdir -p "$backup_dir"

    sudo -u postgres pg_dump "$db_name" | gzip > "$backup_file"

    return $?
}