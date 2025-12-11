#!/bin/bash

# Utilitaires Docker pour génération docker-compose

generate_docker_compose() {
    local project_dir=$1
    local backend=$2
    local frontend=$3
    local db=$4
    
    print_info "  Génération de docker-compose.yml..."
    
    cat > "$project_dir/docker-compose.yml" << EOF
version: '3.8'

services:
  # Base de données
  db:
    image: $(get_db_image $db)
    container_name: ${project_name}-db
    restart: unless-stopped
    environment:
      $(get_db_env_vars $db)
    ports:
      - "$(get_db_port $db):$(get_db_port $db)"
    volumes:
      - db-data:/var/lib/$(get_db_volume_path $db)
    networks:
      - app-network
    healthcheck:
      test: $(get_db_healthcheck $db)
      interval: 10s
      timeout: 5s
      retries: 5

  # Backend API
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: ${project_name}-backend
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=$(get_db_url $db)
      - DATABASE_USERNAME=appuser
      - DATABASE_PASSWORD=changeme
      - JWT_SECRET=your-secret-key-change-in-production
      - CORS_ORIGINS=http://localhost:4200
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network
    volumes:
      - ./backend:/app
      - /app/target  # Exclure le dossier target pour Maven

  # Frontend
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: ${project_name}-frontend
    restart: unless-stopped
    ports:
      - "4200:80"
    environment:
      - API_URL=http://backend:8080/api
    depends_on:
      - backend
    networks:
      - app-network

volumes:
  db-data:
    driver: local

networks:
  app-network:
    driver: bridge
EOF

    # Générer aussi un docker-compose.dev.yml pour le développement
    cat > "$project_dir/docker-compose.dev.yml" << EOF
version: '3.8'

services:
  db:
    image: $(get_db_image $db)
    container_name: ${project_name}-db-dev
    environment:
      $(get_db_env_vars $db)
    ports:
      - "$(get_db_port $db):$(get_db_port $db)"
    volumes:
      - db-data-dev:/var/lib/$(get_db_volume_path $db)
    networks:
      - app-network

  backend:
    build:
      context: ./backend
      target: build  # Utiliser le stage de build pour le dev
    container_name: ${project_name}-backend-dev
    ports:
      - "8080:8080"
      - "5005:5005"  # Port de debug Java
    environment:
      - DATABASE_URL=$(get_db_url $db)
      - DATABASE_USERNAME=appuser
      - DATABASE_PASSWORD=changeme
      - JWT_SECRET=dev-secret-key
      - CORS_ORIGINS=http://localhost:4200
      - JAVA_TOOL_OPTIONS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
    volumes:
      - ./backend:/app
      - maven-cache:/root/.m2
    depends_on:
      - db
    networks:
      - app-network
    command: mvn spring-boot:run

  frontend:
    image: node:20-alpine
    container_name: ${project_name}-frontend-dev
    working_dir: /app
    ports:
      - "4200:4200"
    environment:
      - API_URL=http://localhost:8080/api
    volumes:
      - ./frontend:/app
      - /app/node_modules
    networks:
      - app-network
    command: sh -c "npm install && npm start -- --host 0.0.0.0"

volumes:
  db-data-dev:
  maven-cache:

networks:
  app-network:
    driver: bridge
EOF

    print_success "  docker-compose.yml généré"
}

get_db_image() {
    case $1 in
        postgres)
            echo "postgres:15-alpine"
            ;;
        mysql)
            echo "mysql:8"
            ;;
        mongodb)
            echo "mongo:6"
            ;;
    esac
}

get_db_port() {
    case $1 in
        postgres)
            echo "5432"
            ;;
        mysql)
            echo "3306"
            ;;
        mongodb)
            echo "27017"
            ;;
    esac
}

get_db_volume_path() {
    case $1 in
        postgres)
            echo "postgresql/data"
            ;;
        mysql)
            echo "mysql"
            ;;
        mongodb)
            echo "mongodb"
            ;;
    esac
}

get_db_env_vars() {
    case $1 in
        postgres)
            cat << 'EOF'
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: changeme
EOF
            ;;
        mysql)
            cat << 'EOF'
      MYSQL_DATABASE: appdb
      MYSQL_USER: appuser
      MYSQL_PASSWORD: changeme
      MYSQL_ROOT_PASSWORD: rootpassword
EOF
            ;;
        mongodb)
            cat << 'EOF'
      MONGO_INITDB_DATABASE: appdb
      MONGO_INITDB_ROOT_USERNAME: appuser
      MONGO_INITDB_ROOT_PASSWORD: changeme
EOF
            ;;
    esac
}

get_db_url() {
    case $1 in
        postgres)
            echo "jdbc:postgresql://db:5432/appdb"
            ;;
        mysql)
            echo "jdbc:mysql://db:3306/appdb"
            ;;
        mongodb)
            echo "mongodb://appuser:changeme@db:27017/appdb"
            ;;
    esac
}

get_db_healthcheck() {
    case $1 in
        postgres)
            echo '["CMD-SHELL", "pg_isready -U appuser -d appdb"]'
            ;;
        mysql)
            echo '["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "appuser", "-pchangeme"]'
            ;;
        mongodb)
            echo '["CMD", "mongo", "--eval", "db.adminCommand(\"ping\")"]'
            ;;
    esac
}

generate_github_actions() {
    local project_dir=$1
    local backend=$2
    local frontend=$3
    
    mkdir -p "$project_dir/.github/workflows"
    
    # Workflow Backend
    cat > "$project_dir/.github/workflows/backend-deploy.yml" << 'EOF'
name: Deploy Backend to Render

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Trigger Render Deploy
        run: |
          curl -X POST ${{ secrets.RENDER_DEPLOY_HOOK_BACKEND }}
        
      - name: Notify Deployment
        run: |
          echo "Backend deployed to Render successfully!"
EOF

    # Workflow Frontend
    cat > "$project_dir/.github/workflows/frontend-deploy.yml" << 'EOF'
name: Deploy Frontend to Netlify

on:
  push:
    branches: [main]
    paths:
      - 'frontend/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json
      
      - name: Install dependencies
        working-directory: ./frontend
        run: npm ci
      
      - name: Build
        working-directory: ./frontend
        run: npm run build
        env:
          VITE_API_URL: ${{ secrets.API_URL }}
      
      - name: Deploy to Netlify
        uses: netlify/actions/cli@master
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
        with:
          args: deploy --prod --dir=frontend/dist/*/browser
          
      - name: Notify Deployment
        run: |
          echo "Frontend deployed to Netlify successfully!"
EOF

    # Workflow CI
    cat > "$project_dir/.github/workflows/ci.yml" << 'EOF'
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [develop]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven
      
      - name: Run tests
        working-directory: ./backend
        run: mvn test
      
      - name: Build
        working-directory: ./backend
        run: mvn clean package -DskipTests

  frontend-tests:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json
      
      - name: Install dependencies
        working-directory: ./frontend
        run: npm ci
      
      - name: Lint
        working-directory: ./frontend
        run: npm run lint || true
      
      - name: Build
        working-directory: ./frontend
        run: npm run build
EOF

    print_success "  Workflows GitHub Actions générés"
}