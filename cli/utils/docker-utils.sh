#!/bin/bash

# Utilitaires Docker pour génération docker-compose et configs cloud

generate_docker_compose() {
    local project_dir=$1
    local backend=$2
    local frontend=$3
    local db=$4
    local project_name=$(basename "$project_dir")
    
    print_info "  Génération des fichiers Docker..."
    
    # Docker Compose Dev
    cat > "$project_dir/docker-compose.yml" << 'EOFDEV'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: app-db-dev
    restart: unless-stopped
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: changeme
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: app-backend-dev
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=jdbc:postgresql://db:5432/appdb
      - DATABASE_USERNAME=appuser
      - DATABASE_PASSWORD=changeme
      - JWT_SECRET=dev-secret-key
      - CORS_ORIGINS=http://localhost:4200
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: app-frontend-dev
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

networks:
  app-network:
    driver: bridge
EOFDEV

    # Docker Compose Production
    cat > "$project_dir/docker-compose.prod.yml" << 'EOFPROD'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: ${PROJECT_NAME:-app}-postgres
    restart: always
    environment:
      POSTGRES_DB: ${DB_NAME:-appdb}
      POSTGRES_USER: ${DB_USER:-appuser}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-changeme}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-appuser}"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME:-app}-backend
    restart: always
    ports:
      - "${BACKEND_PORT:-8080}:8080"
    environment:
      - DATABASE_URL=jdbc:postgresql://postgres:5432/${DB_NAME:-appdb}
      - DATABASE_USERNAME=${DB_USER:-appuser}
      - DATABASE_PASSWORD=${DB_PASSWORD:-changeme}
      - JWT_SECRET=${JWT_SECRET:-change-me-in-production}
      - CORS_ORIGINS=${FRONTEND_URL:-http://localhost}
      - SPRING_PROFILES_ACTIVE=prod
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME:-app}-frontend
    restart: always
    ports:
      - "${FRONTEND_PORT:-80}:80"
    depends_on:
      - backend
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
EOFPROD

    # .env.example
    cat > "$project_dir/.env.example" << EOFENV
PROJECT_NAME=$project_name
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=changeme-in-production
JWT_SECRET=generate-a-secure-random-key-here
BACKEND_PORT=8080
FRONTEND_PORT=80
FRONTEND_URL=http://localhost
BACKEND_URL=http://backend:8080
EOFENV

    # Script de déploiement universel
    cat > "$project_dir/deploy-anywhere.sh" << 'EOFDEPLOY'
#!/bin/bash
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }

show_help() {
    cat << 'HELP'
Usage: ./deploy-anywhere.sh [PLATFORM]

Plateformes:
  local       Docker Compose local
  railway     Railway.app
  fly         Fly.io  
  render      Render.com

Exemple: ./deploy-anywhere.sh local
HELP
}

[ $# -eq 0 ] && { show_help; exit 0; }

case $1 in
    local)
        print_info "Déploiement local..."
        [ ! -f .env ] && cp .env.example .env
        docker-compose -f docker-compose.prod.yml up --build -d
        print_success "Application démarrée!"
        echo "Frontend: http://localhost"
        echo "Backend: http://localhost:8080"
        ;;
    railway)
        command -v railway &>/dev/null || { echo "Railway CLI requis: npm install -g @railway/cli"; exit 1; }
        railway up
        ;;
    fly)
        command -v fly &>/dev/null || { echo "Fly CLI requis: curl -L https://fly.io/install.sh | sh"; exit 1; }
        fly deploy
        ;;
    render)
        echo "Allez sur: https://dashboard.render.com/blueprints"
        echo "Sélectionnez votre repo et cliquez Apply"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
EOFDEPLOY

    chmod +x "$project_dir/deploy-anywhere.sh"
    
    # Créer le dossier deployment
    mkdir -p "$project_dir/deployment"
    
    # Railway config
    cat > "$project_dir/deployment/railway.toml" << EOFR
[build]
builder = "dockerfile"
dockerfilePath = "backend/Dockerfile"

[deploy]
healthcheckPath = "/api/health"
restartPolicyType = "on_failure"
EOFR

    # Render config
    cat > "$project_dir/render.yaml" << EOFREND
services:
  - type: web
    name: $project_name-backend
    runtime: docker
    region: frankfurt
    plan: free
    branch: main
    dockerfilePath: ./backend/Dockerfile
    dockerContext: ./backend
    healthCheckPath: /api/health
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: $project_name-db
          property: connectionString
      - key: JWT_SECRET
        generateValue: true
      - key: CORS_ORIGINS
        value: "*"
      - key: SPRING_PROFILES_ACTIVE
        value: prod

databases:
  - name: $project_name-db
    databaseName: appdb
    user: appuser
    plan: free
    region: frankfurt
EOFREND

    print_success "  Fichiers Docker et déploiement générés"
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
            echo "      POSTGRES_DB: appdb"
            echo "      POSTGRES_USER: appuser"
            echo "      POSTGRES_PASSWORD: changeme"
            ;;
        mysql)
            echo "      MYSQL_DATABASE: appdb"
            echo "      MYSQL_USER: appuser"
            echo "      MYSQL_PASSWORD: changeme"
            echo "      MYSQL_ROOT_PASSWORD: rootpassword"
            ;;
        mongodb)
            echo "      MONGO_INITDB_DATABASE: appdb"
            echo "      MONGO_INITDB_ROOT_USERNAME: appuser"
            echo "      MONGO_INITDB_ROOT_PASSWORD: changeme"
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