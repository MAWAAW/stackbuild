#!/bin/bash

# Script de déploiement sur Render

deploy_to_render() {
    print_info "Déploiement du backend sur Render..."
    
    # Vérifier si on est dans un projet
    if [ ! -f "docker-compose.yml" ]; then
        print_error "Fichier docker-compose.yml introuvable"
        print_info "Assurez-vous d'être dans le répertoire du projet"
        return 1
    fi
    
    local project_name=$(basename $(pwd))
    
    # Vérifier si le code est sur GitHub
    if ! git remote get-url origin &> /dev/null; then
        print_error "Aucun dépôt Git distant configuré"
        print_info "Le déploiement sur Render nécessite que le code soit sur GitHub"
        show_git_setup_instructions
        return 1
    fi
    
    local repo_url=$(git remote get-url origin)
    print_info "Dépôt détecté: $repo_url"
    
    # Créer render.yaml automatiquement
    if [ ! -f "render.yaml" ]; then
        create_render_blueprint "$project_name"
    else
        print_info "render.yaml existe déjà"
    fi
    
    # Vérifier si le token Render est configuré pour l'API
    if [ -n "$RENDER_API_KEY" ]; then
        print_info "RENDER_API_KEY détecté, tentative de déploiement automatique via API..."
        
        if deploy_render_auto "$project_name" "$repo_url"; then
            print_success "Déploiement automatique réussi !"
            return 0
        else
            print_warning "Le déploiement automatique via API a échoué"
            print_info "Basculement vers la méthode Blueprint..."
        fi
    fi
    
    # Méthode Blueprint (recommandée et toujours fonctionnelle)
    print_info ""
    print_info "╔════════════════════════════════════════════════════════════╗"
    print_info "║  Déploiement via Render Blueprint (100% automatique)      ║"
    print_info "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    print_success "✅ Fichier render.yaml créé et pushé sur GitHub"
    echo ""
    
    print_info "🚀 Étapes finales (2 minutes) :"
    echo ""
    echo "  1. Ouvrez ce lien dans votre navigateur :"
    echo "     👉 https://dashboard.render.com/blueprints"
    echo ""
    echo "  2. Cliquez sur 'New Blueprint Instance'"
    echo ""
    echo "  3. Sélectionnez votre repository :"
    echo "     📁 $(basename $(dirname $repo_url))/$(basename $repo_url .git)"
    echo ""
    echo "  4. Cliquez 'Apply'"
    echo ""
    echo "  Render va automatiquement créer :"
    echo "     ✓ Base de données PostgreSQL"
    echo "     ✓ Service web backend"
    echo "     ✓ Variables d'environnement"
    echo "     ✓ Lien entre tous les services"
    echo ""
    
    print_info "⏱️  Le premier déploiement prend ~5-10 minutes"
    echo ""
    
    # Proposer d'ouvrir le navigateur automatiquement
    if command -v xdg-open &> /dev/null; then
        read -p "Voulez-vous ouvrir le dashboard Render maintenant? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            xdg-open "https://dashboard.render.com/blueprints" &
            print_success "Navigateur ouvert"
        fi
    elif command -v open &> /dev/null; then
        read -p "Voulez-vous ouvrir le dashboard Render maintenant? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            open "https://dashboard.render.com/blueprints" &
            print_success "Navigateur ouvert"
        fi
    fi
    
    echo ""
    print_info "Une fois déployé, votre backend sera accessible sur :"
    echo "  https://${project_name}-backend.onrender.com"
    echo ""
    
    # Sauvegarder les infos pour référence
    cat > ".render-info" << EOF
PROJECT_NAME=$project_name
EXPECTED_URL=https://${project_name}-backend.onrender.com
BLUEPRINT_URL=https://dashboard.render.com/blueprints
GITHUB_REPO=$repo_url
DEPLOYMENT_METHOD=blueprint
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
    
    print_info "📝 Informations sauvegardées dans .render-info"
    
    return 0
}

deploy_render_auto() {
    local project_name=$1
    local repo_url=$2
    
    print_info "Création du service backend sur Render..."
    
    # Extraire owner et repo du repo_url
    local github_repo=$(echo "$repo_url" | sed -E 's#.*github\.com[:/]([^/]+/[^/]+)(\.git)?$#\1#' | sed 's/\.git$//')
    
    print_info "Repository GitHub : $github_repo"
    
    # Créer d'abord la base de données PostgreSQL
    print_info "Création de la base de données PostgreSQL..."
    
    local db_response=$(curl -s -X POST \
        "https://api.render.com/v1/postgres" \
        -H "Authorization: Bearer $RENDER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
          \"name\": \"${project_name}-db\",
          \"plan\": \"free\",
          \"region\": \"frankfurt\",
          \"databaseName\": \"appdb\",
          \"databaseUser\": \"appuser\",
          \"enableHighAvailability\": false
        }")
    
    echo "$db_response" | jq '.' 2>/dev/null || echo "$db_response"
    
    if echo "$db_response" | jq -e '.id' &> /dev/null; then
        local db_id=$(echo "$db_response" | jq -r '.id')
        print_success "Base de données créée (ID: $db_id)"
        
        # Récupérer l'URL de connexion interne
        print_info "Récupération des informations de connexion..."
        sleep 5
        
        local db_info=$(curl -s -X GET \
            "https://api.render.com/v1/postgres/$db_id" \
            -H "Authorization: Bearer $RENDER_API_KEY")
        
        local db_connection_string=$(echo "$db_info" | jq -r '.connectionInfo.internalConnectionString // empty')
        
        if [ -z "$db_connection_string" ]; then
            print_warning "Impossible de récupérer l'URL de connexion automatiquement"
            print_info "La base sera liée manuellement via le dashboard Render"
            db_connection_string="postgresql://appuser:changeme@${project_name}-db:5432/appdb"
        fi
        
        print_info "Attente de la disponibilité de la base de données (30s)..."
        sleep 30
    else
        # Si échec, vérifier si c'est un problème d'API ou de quota
        if echo "$db_response" | grep -qi "not found"; then
            print_error "Endpoint API introuvable - L'API Render a peut-être changé"
            print_warning "Déploiement manuel requis"
            show_render_manual_deployment
            return 1
        elif echo "$db_response" | grep -qi "limit"; then
            print_error "Limite de bases de données gratuites atteinte"
            print_info "Supprimez une base existante ou passez à un plan payant"
            return 1
        else
            print_error "Échec de la création de la base de données"
            echo "$db_response"
            print_info "Continuons avec le service web (vous lierez la DB manuellement)"
            db_connection_string=""
        fi
    fi
    
    # Créer le service Web
    print_info "Création du service web backend..."
    
    # Construire les variables d'environnement
    local env_vars='[
        {
          "key": "JWT_SECRET",
          "generateValue": true
        },
        {
          "key": "CORS_ORIGINS",
          "value": "*"
        }'
    
    if [ -n "$db_connection_string" ]; then
        env_vars="$env_vars"',
        {
          "key": "DATABASE_URL",
          "value": "'"$db_connection_string"'"
        }'
    fi
    
    env_vars="$env_vars"']'
    
    local service_response=$(curl -s -X POST \
        "https://api.render.com/v1/services" \
        -H "Authorization: Bearer $RENDER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": \"web_service\",
          \"name\": \"${project_name}-backend\",
          \"repo\": \"https://github.com/${github_repo}\",
          \"autoDeploy\": \"yes\",
          \"branch\": \"main\",
          \"rootDir\": \"backend\",
          \"dockerfilePath\": \"backend/Dockerfile\",
          \"region\": \"frankfurt\",
          \"plan\": \"free\",
          \"envVars\": $env_vars,
          \"healthCheckPath\": \"/api/health\"
        }")
    
    echo "$service_response" | jq '.' 2>/dev/null || echo "$service_response"
    
    if echo "$service_response" | jq -e '.service.id' &> /dev/null; then
        local service_id=$(echo "$service_response" | jq -r '.service.id')
        local service_url=$(echo "$service_response" | jq -r '.service.serviceDetails.url // empty')
        
        if [ -z "$service_url" ]; then
            service_url="https://${project_name}-backend.onrender.com"
        fi
        
        print_success "Backend déployé avec succès!"
        print_info "Service ID: $service_id"
        print_info "URL: $service_url"
        
        # Sauvegarder les infos
        cat > ".render-info" << EOF
SERVICE_ID=$service_id
SERVICE_URL=$service_url
DATABASE_ID=${db_id:-none}
GITHUB_REPO=$github_repo
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
        
        print_success "Informations sauvegardées dans .render-info"
        
        print_info ""
        print_info "Le déploiement est en cours sur Render (~5-10 min pour le premier build)"
        print_info "Suivez l'avancement sur: https://dashboard.render.com"
        
        if [ -z "$db_connection_string" ]; then
            print_warning ""
            print_warning "N'oubliez pas de lier la base de données manuellement:"
            echo "  1. Allez sur https://dashboard.render.com"
            echo "  2. Sélectionnez votre service: ${project_name}-backend"
            echo "  3. Environment → Add Environment Variable"
            echo "  4. DATABASE_URL = (copiez depuis votre DB PostgreSQL)"
        fi
        
        return 0
    else
        print_error "Échec de la création du service"
        
        # Afficher le message d'erreur
        if echo "$service_response" | jq -e '.message' &> /dev/null; then
            local error_msg=$(echo "$service_response" | jq -r '.message')
            print_error "Erreur: $error_msg"
        fi
        
        echo "$service_response"
        
        print_info ""
        print_warning "Le déploiement automatique a échoué"
        show_render_manual_deployment
        
        return 1
    fi
}

create_render_blueprint() {
    local project_name=$1
    
    print_info "Création du fichier render.yaml..."
    
    cat > "render.yaml" << EOF
services:
  - type: web
    name: ${project_name}-backend
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
          name: ${project_name}-db
          property: connectionString
      - key: JWT_SECRET
        generateValue: true
      - key: CORS_ORIGINS
        value: "*"
      - key: SPRING_PROFILES_ACTIVE
        value: prod

databases:
  - name: ${project_name}-db
    databaseName: appdb
    user: appuser
    plan: free
    region: frankfurt
EOF
    
    if [ -f "render.yaml" ]; then
        print_success "Fichier render.yaml créé"
        
        # Commit et push automatiquement
        if git rev-parse --git-dir > /dev/null 2>&1; then
            git add render.yaml
            if git commit -m "Add Render Blueprint configuration" 2>/dev/null; then
                print_success "render.yaml commité"
                
                if git push 2>/dev/null; then
                    print_success "render.yaml pushé sur GitHub"
                else
                    print_warning "Échec du push - faites : git push"
                fi
            else
                print_info "render.yaml déjà commité"
            fi
        fi
    else
        print_error "Échec de la création de render.yaml"
        return 1
    fi
}

show_render_manual_deployment() {
    cat << 'EOF'

📋 Déploiement manuel sur Render:

1. Allez sur https://dashboard.render.com

2. Créez une base de données PostgreSQL:
   - Cliquez sur "New +" → "PostgreSQL"
   - Name: votre-projet-db
   - Database: appdb
   - User: appuser
   - Region: Frankfurt
   - Plan: Free
   - Cliquez "Create Database"

3. Créez le service web backend:
   - Cliquez sur "New +" → "Web Service"
   - Connectez votre dépôt GitHub
   - Name: votre-projet-backend
   - Region: Frankfurt
   - Branch: main
   - Root Directory: backend
   - Environment: Docker
   - Dockerfile Path: backend/Dockerfile
   - Plan: Free

4. Configurez les variables d'environnement:
   - DATABASE_URL: (copier depuis la page de la DB PostgreSQL)
   - JWT_SECRET: (générer une valeur aléatoire 256 bits)
   - CORS_ORIGINS: * (ou l'URL Netlify plus tard)

5. Cliquez "Create Web Service"

6. Attendez le déploiement (~5-10 minutes pour le premier)

7. Une fois déployé, notez l'URL du backend (ex: https://votre-app.onrender.com)

8. Configurez CORS_ORIGINS avec l'URL Netlify après déploiement du frontend

EOF
}

detect_backend_type() {
    if [ -f "backend/pom.xml" ]; then
        echo "spring"
    elif [ -f "backend/package.json" ]; then
        echo "node"
    elif [ -f "backend/requirements.txt" ]; then
        echo "fastapi"
    else
        echo "unknown"
    fi
}

create_render_service() {
    local backend_type=$1
    local project_name=$(basename $(pwd))
    
    print_info "  Création du service Render pour $backend_type..."
    
    # Préparer le blueprint Render
    cat > "render.yaml" << EOF
services:
  - type: web
    name: ${project_name}-backend
    env: docker
    region: frankfurt
    plan: free
    branch: main
    dockerfilePath: ./backend/Dockerfile
    envVars:
      - key: DATABASE_URL
        sync: false
      - key: JWT_SECRET
        generateValue: true
      - key: CORS_ORIGINS
        value: https://${project_name}-frontend.netlify.app
    healthCheckPath: /api/health

databases:
  - name: ${project_name}-db
    databaseName: appdb
    user: appuser
    plan: free
    region: frankfurt
EOF
    
    print_success "  Fichier render.yaml créé"
    
    # Proposer de créer le service via l'API
    create_via_api "$project_name"
}

create_via_api() {
    local project_name=$1
    
    print_info "  Création du service via l'API Render..."
    
    # Vérifier si un repo Git est configuré
    if ! git remote get-url origin &>/dev/null; then
        print_warning "Aucun dépôt Git distant configuré"
        print_info "Veuillez d'abord pousser votre code sur GitHub/GitLab"
        show_git_setup_instructions
        return
    fi
    
    local repo_url=$(git remote get-url origin)
    
    # Créer le service Web
    local response=$(curl -s -X POST \
        "https://api.render.com/v1/services" \
        -H "Authorization: Bearer $RENDER_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "type": "web_service",
          "name": "'"$project_name"'-backend",
          "ownerId": "'"$RENDER_OWNER_ID"'",
          "repo": "'"$repo_url"'",
          "autoDeploy": true,
          "branch": "main",
          "dockerfilePath": "./backend/Dockerfile",
          "envVars": [
            {
              "key": "JWT_SECRET",
              "generateValue": true
            }
          ],
          "region": "frankfurt",
          "plan": "free"
        }')
    
    if echo "$response" | grep -q '"id"'; then
        local service_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        local service_url=$(echo "$response" | grep -o '"serviceUrl":"[^"]*"' | cut -d'"' -f4)
        
        print_success "  Service créé avec succès!"
        print_info "  Service ID: $service_id"
        print_info "  URL: $service_url"
        
        # Sauvegarder les infos
        cat > ".render-info" << EOF
SERVICE_ID=$service_id
SERVICE_URL=$service_url
DEPLOY_HOOK=https://api.render.com/deploy/$service_id?key=...
EOF
        
        print_info "  Informations sauvegardées dans .render-info"
    else
        print_error "  Échec de la création du service"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        show_render_manual_steps
    fi
}

show_render_manual_steps() {
    cat << 'EOF'

📋 Étapes de déploiement manuel sur Render:

1. Allez sur https://dashboard.render.com
2. Cliquez sur "New +" > "Web Service"
3. Connectez votre dépôt Git (GitHub/GitLab)
4. Configurez le service:
   - Name: votre-projet-backend
   - Region: Frankfurt (EU)
   - Branch: main
   - Root Directory: ./backend
   - Environment: Docker
   - Dockerfile Path: ./backend/Dockerfile
   - Plan: Free

5. Ajoutez les variables d'environnement:
   - JWT_SECRET (générer une valeur aléatoire)
   - DATABASE_URL (sera fournie par Render si vous créez une DB)
   - CORS_ORIGINS (URL de votre frontend Netlify)

6. Créez aussi une base de données PostgreSQL:
   - New + > PostgreSQL
   - Name: votre-projet-db
   - Plan: Free
   - Region: Frankfurt

7. Liez la base au service web en ajoutant DATABASE_URL

8. Copiez le Deploy Hook pour GitHub Actions:
   - Settings > Deploy Hook
   - Ajoutez-le comme secret RENDER_DEPLOY_HOOK_BACKEND

EOF
}

show_git_setup_instructions() {
    cat << 'EOF'

📦 Configuration Git requise:

1. Créez un dépôt sur GitHub:
   gh repo create votre-projet --public --source=. --remote=origin

2. Ou manuellement:
   - Allez sur github.com et créez un nouveau repo
   - Ajoutez le remote:
     git remote add origin https://github.com/votre-username/votre-projet.git

3. Poussez votre code:
   git add .
   git commit -m "Initial commit"
   git push -u origin main

4. Relancez le déploiement:
   ./deploy.sh deploy --backend-only

EOF
}

# Fonction pour obtenir les logs de déploiement
get_render_deploy_logs() {
    local service_id=$1
    
    if [ -z "$RENDER_API_KEY" ]; then
        print_error "RENDER_API_KEY non configuré"
        return
    fi
    
    curl -s "https://api.render.com/v1/services/$service_id/deploys?limit=1" \
        -H "Authorization: Bearer $RENDER_API_KEY" | jq '.'
}

# Fonction pour vérifier le statut du service
check_render_service_status() {
    if [ ! -f ".render-info" ]; then
        print_warning "Fichier .render-info introuvable"
        return
    fi
    
    source .render-info
    
    if [ -z "$SERVICE_ID" ]; then
        print_error "SERVICE_ID non trouvé dans .render-info"
        return
    fi
    
    print_info "Vérification du statut du service..."
    
    local response=$(curl -s "https://api.render.com/v1/services/$SERVICE_ID" \
        -H "Authorization: Bearer $RENDER_API_KEY")
    
    local status=$(echo "$response" | jq -r '.service.state')
    local url=$(echo "$response" | jq -r '.service.serviceDetails.url')
    
    print_info "Status: $status"
    print_info "URL: $url"
    
    if [ "$status" = "live" ]; then
        print_success "✓ Service actif et accessible"
        print_info "Testez votre API: curl $url/api/health"
    else
        print_warning "Service en cours de déploiement..."
    fi
}