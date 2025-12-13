#!/bin/bash

# Générateur de configuration PostgreSQL

generate_database_config() {
    local project_dir=$1
    local backend_type=$2

    local db_dir="$project_dir/database"
    mkdir -p "$db_dir"

    print_info "  Génération de la configuration PostgreSQL..."

    generate_postgres_init_sql "$db_dir"
    generate_postgres_config "$db_dir"
    generate_postgres_env "$db_dir"

    print_success "  Configuration PostgreSQL générée"
}

generate_postgres_init_sql() {
    local db_dir=$1

    cat > "$db_dir/init.sql" << 'EOF'
CREATE USER appuser WITH PASSWORD 'changeme';
CREATE DATABASE appdb OWNER appuser;
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
EOF
}

generate_postgres_config() {
    local db_dir=$1

    cat > "$db_dir/postgres.conf" << 'EOF'
shared_buffers = 256MB
max_connections = 50
EOF
}

generate_postgres_env() {
    local db_dir=$1

    cat > "$db_dir/.env.example" << 'EOF'
POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=changeme
POSTGRES_PORT=5432
EOF
}
